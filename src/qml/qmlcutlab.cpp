#include "qml/qmlcutlab.h"

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QHash>
#include <QSet>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QtDebug>
#include <algorithm>
#include <cmath>
#include <vector>

#include "control/controlobject.h"
#include "library/library.h"
#include "library/scanner/libraryscanner.h"
#include "library/trackcollectionmanager.h"
#include "util/fileinfo.h"
#include "util/sandbox.h"
#include "mixer/playerinfo.h"
#include "moc_qmlcutlab.cpp"
#include "qml/qmllibraryproxy.h"
#include "track/beats.h"
#include "track/keyutils.h"
#include "track/track.h"
#include "util/db/dbconnectionpooled.h"
#include "waveform/waveform.h"

#ifdef Q_OS_ANDROID
#include "library/androidscanorder.h"
#endif

namespace mixxx {
namespace qml {

namespace {

const QString kCutlabGroup = QStringLiteral("[Cutlab]");

QSqlDatabase database() {
    Library* pLibrary = QmlLibraryProxy::get();
    if (!pLibrary) {
        return QSqlDatabase();
    }
    return mixxx::DbConnectionPooled(pLibrary->dbConnectionPool());
}

QVariantMap section(const QString& type, double start, double end) {
    return QVariantMap{
            {QStringLiteral("type"), type},
            {QStringLiteral("start"), start},
            {QStringLiteral("end"), end},
    };
}

/// Camelot number (1-12) and letter of a key, 0 when unknown
int camelotNumber(int keyId, bool* pMajor) {
    const auto key = static_cast<mixxx::track::io::key::ChromaticKey>(keyId);
    if (keyId <= static_cast<int>(mixxx::track::io::key::INVALID) ||
            keyId > static_cast<int>(mixxx::track::io::key::B_MINOR)) {
        return 0;
    }
    const int openKey = KeyUtils::keyToOpenKeyNumber(key);
    if (openKey <= 0) {
        return 0;
    }
    *pMajor = KeyUtils::keyIsMajor(key);
    return ((openKey + 6) % 12) + 1;
}

QString camelotText(int keyId) {
    bool major = false;
    const int number = camelotNumber(keyId, &major);
    if (number == 0) {
        return QString();
    }
    return QString::number(number) + (major ? QChar('B') : QChar('A'));
}

/// 3 same key, 2 relative or a step on the wheel, 0 clashing or unknown
int keyMatch(int keyA, int keyB) {
    bool majorA = false;
    bool majorB = false;
    const int a = camelotNumber(keyA, &majorA);
    const int b = camelotNumber(keyB, &majorB);
    if (a == 0 || b == 0) {
        return 1;
    }
    if (a == b) {
        return majorA == majorB ? 3 : 2;
    }
    const int step = std::min((a - b + 12) % 12, (b - a + 12) % 12);
    if (step == 1 && majorA == majorB) {
        return 2;
    }
    return 0;
}

QString parentFolder(const QString& path) {
    return QFileInfo(path).absolutePath();
}

const QStringList kAudioSuffixes = {
        QStringLiteral("mp3"),
        QStringLiteral("flac"),
        QStringLiteral("wav"),
        QStringLiteral("aif"),
        QStringLiteral("aiff"),
        QStringLiteral("m4a"),
        QStringLiteral("aac"),
        QStringLiteral("ogg"),
        QStringLiteral("opus"),
        QStringLiteral("alac"),
};

const QStringList kNonMusicFolders = {
        QStringLiteral("android"),
        QStringLiteral("whatsapp"),
        QStringLiteral("dcim"),
        QStringLiteral("movies"),
        QStringLiteral("pictures"),
        QStringLiteral("ringtones"),
        QStringLiteral("notifications"),
        QStringLiteral("alarms"),
        QStringLiteral("recordings"),
        QStringLiteral("voice recorder"),
        QStringLiteral("call"),
        QStringLiteral("telegram"),
        QStringLiteral("samsung"),
        QStringLiteral("miui"),
        QStringLiteral(".thumbnails"),
};

} // namespace

QmlCutlab::QmlCutlab(QObject* pParent)
        : QObject(pParent) {
}

QmlCutlab* QmlCutlab::create(QQmlEngine* pQmlEngine, QJSEngine*) {
    return new QmlCutlab(pQmlEngine);
}

void QmlCutlab::createControls() {
    static const bool created = []() {
        for (int deck = 1; deck <= 4; ++deck) {
            // Never deleted: they live as long as the engine
            new ControlObject(ConfigKey(kCutlabGroup, QStringLiteral("fx_deck%1").arg(deck)));
            new ControlObject(ConfigKey(kCutlabGroup, QStringLiteral("fx_open%1").arg(deck)));
        }
        new ControlObject(ConfigKey(kCutlabGroup, QStringLiteral("browse_suggestions")));
        return true;
    }();
    Q_UNUSED(created);
}

QVariantList QmlCutlab::sections(const QString& group) const {
    QVariantList result;
    const TrackPointer pTrack = PlayerInfo::instance().getTrackInfo(group);
    if (!pTrack) {
        return result;
    }
    const ConstWaveformPointer pSummary = pTrack->getWaveformSummary();
    const double bpm = pTrack->getBpm();
    const double duration = pTrack->getDuration();
    if (!pSummary || pSummary->getDataSize() < 64 || bpm <= 0 || duration <= 1) {
        return result;
    }

    // Where the first bar starts, from the beat grid
    double firstBeatSeconds = 0;
    const mixxx::BeatsPointer pBeats = pTrack->getBeats();
    const auto sampleRate = pTrack->getSampleRate();
    if (pBeats && sampleRate.isValid()) {
        const auto firstBeat = pBeats->firstBeat();
        if (firstBeat.isValid()) {
            firstBeatSeconds = firstBeat.value() / sampleRate.value();
        }
    }
    const double barSeconds = 4 * 60.0 / bpm;
    const int bars = static_cast<int>((duration - firstBeatSeconds) / barSeconds);
    if (bars < 8) {
        return result;
    }

    // Energy of each bar: the mean of the summary over it, the low band
    // counts double (kick and bass make a drop)
    const int samples = pSummary->getDataSize() / 2;
    std::vector<double> energy(bars, 0.0);
    for (int bar = 0; bar < bars; ++bar) {
        const double start = (firstBeatSeconds + bar * barSeconds) / duration;
        const double end = (firstBeatSeconds + (bar + 1) * barSeconds) / duration;
        const int from = std::clamp(static_cast<int>(start * samples), 0, samples - 1);
        const int to = std::clamp(static_cast<int>(end * samples), from + 1, samples);
        double sum = 0;
        for (int i = from; i < to; ++i) {
            const int index = i * 2;
            sum += pSummary->getAll(index) + pSummary->getAll(index + 1) +
                    2.0 * (pSummary->getLow(index) + pSummary->getLow(index + 1));
        }
        energy[bar] = sum / (to - from);
    }
    std::vector<double> sorted = energy;
    std::nth_element(sorted.begin(), sorted.begin() + sorted.size() / 2, sorted.end());
    const double median = sorted[sorted.size() / 2];
    if (median <= 0) {
        return result;
    }

    auto barToPosition = [&](int bar) {
        return std::clamp((firstBeatSeconds + bar * barSeconds) / duration, 0.0, 1.0);
    };

    // Intro: the bars before the energy first gets close to the median
    int introEnd = 0;
    while (introEnd < bars / 3 && energy[introEnd] < 0.72 * median) {
        ++introEnd;
    }
    if (introEnd >= 2) {
        result.append(section(QStringLiteral("intro"), 0.0, barToPosition(introEnd)));
    }

    // Breaks and pauses: runs of at least 2 quiet bars after the intro.
    // A drop: the first full bar after a break.
    int bar = std::max(introEnd, 1);
    while (bar < bars) {
        if (energy[bar] >= 0.62 * median) {
            ++bar;
            continue;
        }
        int end = bar;
        double lowest = energy[bar];
        while (end < bars && energy[end] < 0.62 * median) {
            lowest = std::min(lowest, energy[end]);
            ++end;
        }
        if (end - bar >= 2) {
            const bool pause = lowest < 0.22 * median;
            result.append(section(pause ? QStringLiteral("pause") : QStringLiteral("break"),
                    barToPosition(bar),
                    barToPosition(end)));
            if (end < bars && energy[end] >= 0.95 * median) {
                result.append(section(QStringLiteral("drop"),
                        barToPosition(end),
                        barToPosition(std::min(bars, end + 1))));
            }
        } else if (end - bar == 1 && lowest < 0.22 * median) {
            // A one bar silence before the beat comes back
            result.append(section(QStringLiteral("pause"), barToPosition(bar), barToPosition(end)));
            if (end < bars && energy[end] >= 0.95 * median) {
                result.append(section(QStringLiteral("drop"),
                        barToPosition(end),
                        barToPosition(std::min(bars, end + 1))));
            }
        }
        bar = end;
    }

    // Outro: the quiet tail
    int outroStart = bars;
    while (outroStart > bars * 2 / 3 && energy[outroStart - 1] < 0.72 * median) {
        --outroStart;
    }
    if (bars - outroStart >= 2) {
        result.append(section(QStringLiteral("outro"), barToPosition(outroStart), 1.0));
    }
    return result;
}

QVariantList QmlCutlab::musicFolders() const {
    QVariantList result;
    QSqlDatabase db = database();
    if (!db.isOpen()) {
        return result;
    }
    QStringList roots;
    {
        QSqlQuery query(db);
        if (query.exec(QStringLiteral("SELECT directory FROM directories"))) {
            while (query.next()) {
                roots.append(QDir::cleanPath(query.value(0).toString()));
            }
        }
    }
    QSqlQuery query(db);
    if (!query.exec(QStringLiteral(
                "SELECT track_locations.directory, COUNT(*) FROM library "
                "INNER JOIN track_locations ON library.location = track_locations.id "
                "WHERE library.mixxx_deleted = 0 AND track_locations.fs_deleted = 0 "
                "GROUP BY track_locations.directory"))) {
        qWarning() << "Cutlab folders:" << query.lastError();
        return result;
    }
    // Each directory counts for the first subfolder of its music folder
    QMap<QString, int> counts;
    QHash<QString, QString> rootOf;
    while (query.next()) {
        const QString directory = QDir::cleanPath(query.value(0).toString());
        const int count = query.value(1).toInt();
        QString key = directory;
        for (const auto& root : std::as_const(roots)) {
            if (directory == root) {
                key = root;
                rootOf.insert(key, root);
                break;
            }
            if (directory.startsWith(root + QChar('/'))) {
                const QString rest = directory.mid(root.size() + 1);
                key = root + QChar('/') + rest.section(QChar('/'), 0, 0);
                rootOf.insert(key, root);
                break;
            }
        }
        counts[key] += count;
    }
    for (auto it = counts.cbegin(); it != counts.cend(); ++it) {
        result.append(QVariantMap{
                {QStringLiteral("name"), QFileInfo(it.key()).fileName()},
                {QStringLiteral("path"), it.key()},
                {QStringLiteral("count"), it.value()},
                {QStringLiteral("root"), rootOf.value(it.key())},
        });
    }
    // Folders named like "1 - Hip Hop" keep their order
    std::sort(result.begin(), result.end(), [](const QVariant& a, const QVariant& b) {
        return QString::localeAwareCompare(a.toMap().value(QStringLiteral("name")).toString(),
                       b.toMap().value(QStringLiteral("name")).toString()) < 0;
    });
    return result;
}

QVariantList QmlCutlab::genres() const {
    QVariantList result;
    QSqlDatabase db = database();
    if (!db.isOpen()) {
        return result;
    }
    QSqlQuery query(db);
    if (!query.exec(QStringLiteral(
                "SELECT genre, COUNT(*) AS n FROM library "
                "WHERE mixxx_deleted = 0 AND genre IS NOT NULL AND genre != '' "
                "GROUP BY genre ORDER BY n DESC LIMIT 40"))) {
        qWarning() << "Cutlab genres:" << query.lastError();
        return result;
    }
    while (query.next()) {
        result.append(QVariantMap{
                {QStringLiteral("name"), query.value(0).toString()},
                {QStringLiteral("count"), query.value(1).toInt()},
        });
    }
    return result;
}

QVariantList QmlCutlab::suggestions(const QString& group, int limit) const {
    QVariantList result;
    const TrackPointer pTrack = PlayerInfo::instance().getTrackInfo(group);
    QSqlDatabase db = database();
    if (!pTrack || !db.isOpen()) {
        return result;
    }
    const double bpm = pTrack->getBpm();
    const int key = static_cast<int>(pTrack->getKey());
    const QString genre = pTrack->getGenre().trimmed().toLower();
    const QString folder = parentFolder(pTrack->getLocation());
    const QString artist = pTrack->getArtist().trimmed().toLower();
    const QVariant trackId = pTrack->getId().toVariant();

    // What came after this track in earlier sets
    QSet<int> playedAfter;
    {
        QSqlQuery query(db);
        query.prepare(QStringLiteral(
                "SELECT next.track_id FROM PlaylistTracks AS cur "
                "INNER JOIN PlaylistTracks AS next ON next.playlist_id = cur.playlist_id "
                "AND next.position = cur.position + 1 "
                "INNER JOIN Playlists ON Playlists.id = cur.playlist_id "
                "WHERE Playlists.hidden = 2 AND cur.track_id = :id"));
        query.bindValue(QStringLiteral(":id"), trackId);
        if (query.exec()) {
            while (query.next()) {
                playedAfter.insert(query.value(0).toInt());
            }
        }
    }
    // What is loaded or was played in the last 6 hours stays out
    QSet<QString> loaded;
    const auto loadedTracks = PlayerInfo::instance().getLoadedTracks();
    for (const auto& pLoaded : loadedTracks) {
        if (pLoaded) {
            loaded.insert(pLoaded->getLocation());
        }
    }

    QSqlQuery query(db);
    if (!query.exec(QStringLiteral(
                "SELECT library.id, library.artist, library.title, library.bpm, "
                "library.key_id, library.genre, track_locations.location, "
                "library.last_played_at "
                "FROM library INNER JOIN track_locations "
                "ON library.location = track_locations.id "
                "WHERE library.mixxx_deleted = 0 AND track_locations.fs_deleted = 0"))) {
        qWarning() << "Cutlab suggestions:" << query.lastError();
        return result;
    }
    const QDateTime recent = QDateTime::currentDateTimeUtc().addSecs(-6 * 3600);
    struct Candidate {
        double score;
        QVariantMap item;
    };
    std::vector<Candidate> candidates;
    while (query.next()) {
        if (query.value(0) == trackId) {
            continue;
        }
        const QString location = query.value(6).toString();
        if (loaded.contains(location)) {
            continue;
        }
        const QDateTime lastPlayed = query.value(7).toDateTime();
        if (lastPlayed.isValid() && lastPlayed.toUTC() > recent) {
            continue;
        }
        const QString candidateArtist = query.value(1).toString();
        if (!artist.isEmpty() && candidateArtist.trimmed().toLower() == artist) {
            // No artist twice in a row
            continue;
        }
        const double candidateBpm = query.value(3).toDouble();
        double score = 0;
        QStringList why;

        // Tempo within 6%, also at half or double speed
        if (bpm > 0 && candidateBpm > 0) {
            double best = 1.0;
            for (const double factor : {1.0, 0.5, 2.0}) {
                best = std::min(best, std::abs(candidateBpm * factor / bpm - 1.0));
            }
            if (best > 0.06) {
                continue;
            }
            score += 40 * (1.0 - best / 0.06);
            if (best < 0.01) {
                why.append(tr("mismo tempo"));
            }
        }
        const int candidateKey = query.value(4).toInt();
        const int match = keyMatch(key, candidateKey);
        if (match == 3) {
            score += 30;
            why.append(tr("misma tonalidad"));
        } else if (match == 2) {
            score += 22;
            why.append(tr("tonalidad compatible"));
        } else if (match == 0) {
            score -= 15;
        }
        const QString candidateGenre = query.value(5).toString().trimmed().toLower();
        if (!genre.isEmpty() && candidateGenre == genre) {
            score += 25;
            why.append(query.value(5).toString());
        }
        if (parentFolder(location) == folder) {
            score += 18;
            why.append(tr("misma carpeta"));
        }
        if (playedAfter.contains(query.value(0).toInt())) {
            score += 30;
            why.prepend(tr("ya lo pasaste después"));
        }
        candidates.push_back({score,
                QVariantMap{
                        {QStringLiteral("url"), QUrl::fromLocalFile(location)},
                        {QStringLiteral("title"), query.value(2).toString()},
                        {QStringLiteral("artist"), candidateArtist},
                        {QStringLiteral("bpm"), candidateBpm},
                        {QStringLiteral("key"), camelotText(candidateKey)},
                        {QStringLiteral("why"), why.mid(0, 2).join(QStringLiteral(" · "))},
                }});
    }
    std::sort(candidates.begin(), candidates.end(), [](const auto& a, const auto& b) {
        return a.score > b.score;
    });
    for (const auto& candidate : candidates) {
        if (result.size() >= limit) {
            break;
        }
        result.append(candidate.item);
    }
    return result;
}

QStringList QmlCutlab::listsContaining(const QUrl& url) const {
    QStringList result;
    QSqlDatabase db = database();
    if (!db.isOpen() || !url.isLocalFile()) {
        return result;
    }
    const QString location = url.toLocalFile();
    QSqlQuery query(db);
    query.prepare(QStringLiteral(
            "SELECT Playlists.name FROM Playlists "
            "INNER JOIN PlaylistTracks ON PlaylistTracks.playlist_id = Playlists.id "
            "INNER JOIN library ON library.id = PlaylistTracks.track_id "
            "INNER JOIN track_locations ON library.location = track_locations.id "
            "WHERE Playlists.hidden = 0 AND track_locations.location = :location "
            "UNION SELECT crates.name FROM crates "
            "INNER JOIN crate_tracks ON crate_tracks.crate_id = crates.id "
            "INNER JOIN library ON library.id = crate_tracks.track_id "
            "INNER JOIN track_locations ON library.location = track_locations.id "
            "WHERE track_locations.location = :location2"));
    query.bindValue(QStringLiteral(":location"), location);
    query.bindValue(QStringLiteral(":location2"), location);
    if (query.exec()) {
        while (query.next()) {
            result.append(query.value(0).toString());
        }
    } else {
        qWarning() << "Cutlab lists:" << query.lastError();
    }
    return result;
}

QVariantList QmlCutlab::candidateFolders() const {
    QVariantList result;
    const QString storage = QStringLiteral("/storage/emulated/0");
    QDir storageDir(storage);
    if (!storageDir.exists()) {
        return result;
    }
    // Count the music files under each folder of the storage, and under each
    // subfolder of Music, so "Music/DJ" can be picked on its own
    auto countAudio = [](const QString& path) {
        int count = 0;
        int visited = 0;
        QDirIterator it(path, QDir::Files | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
        while (it.hasNext() && visited < 20000) {
            const QString file = it.next();
            ++visited;
            const QString lower = file.toLower();
            bool skip = false;
            for (const auto& name : kNonMusicFolders) {
                if (lower.contains(QChar('/') + name + QChar('/'))) {
                    skip = true;
                    break;
                }
            }
            if (!skip && kAudioSuffixes.contains(QFileInfo(file).suffix().toLower())) {
                ++count;
            }
        }
        return count;
    };
    auto addFolder = [&](const QString& path, const QString& name) {
        const int count = countAudio(path);
        if (count > 0) {
            result.append(QVariantMap{
                    {QStringLiteral("name"), name},
                    {QStringLiteral("path"), path},
                    {QStringLiteral("count"), count},
            });
        }
    };
    const auto topLevel = storageDir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const auto& info : topLevel) {
        const QString lower = info.fileName().toLower();
        if (kNonMusicFolders.contains(lower)) {
            continue;
        }
        if (lower == QStringLiteral("music")) {
            const auto subfolders = QDir(info.absoluteFilePath())
                                            .entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot,
                                                    QDir::Name);
            for (const auto& sub : subfolders) {
                if (!kNonMusicFolders.contains(sub.fileName().toLower())) {
                    addFolder(sub.absoluteFilePath(), info.fileName() + QStringLiteral(" / ") + sub.fileName());
                }
            }
            continue;
        }
        addFolder(info.absoluteFilePath(), info.fileName());
    }
    std::sort(result.begin(), result.end(), [](const QVariant& a, const QVariant& b) {
        return a.toMap().value(QStringLiteral("count")).toInt() >
                b.toMap().value(QStringLiteral("count")).toInt();
    });
    return result;
}

QStringList QmlCutlab::folders() const {
    QStringList result;
    QSqlDatabase db = database();
    if (!db.isOpen()) {
        return result;
    }
    QSqlQuery query(db);
    if (query.exec(QStringLiteral("SELECT directory FROM directories"))) {
        while (query.next()) {
            result.append(query.value(0).toString());
        }
    }
    return result;
}

bool QmlCutlab::useFolders(const QStringList& paths) const {
    Library* pLibrary = QmlLibraryProxy::get();
    if (!pLibrary || paths.isEmpty()) {
        return false;
    }
    TrackCollectionManager* pManager = pLibrary->trackCollectionManager();
    const QStringList old = folders();
    for (const auto& path : old) {
        if (!paths.contains(path)) {
            pManager->removeDirectory(mixxx::FileInfo(path));
        }
    }
    for (const auto& path : paths) {
        if (!old.contains(path)) {
            QDir directory(path);
            Sandbox::createSecurityTokenForDir(directory);
            pManager->addDirectory(mixxx::FileInfo(path));
        }
    }
    QSqlDatabase db = database();
    if (db.isOpen()) {
        QStringList inside;
        for (int i = 0; i < paths.size(); ++i) {
            inside.append(QStringLiteral("track_locations.location LIKE :p%1").arg(i));
        }
        const QString insideClause = inside.join(QStringLiteral(" OR "));
        for (const bool show : {false, true}) {
            QSqlQuery query(db);
            query.prepare(QStringLiteral(
                    "UPDATE library SET mixxx_deleted = %1 WHERE location IN ("
                    "SELECT track_locations.id FROM track_locations WHERE %2(%3))")
                                  .arg(show ? QStringLiteral("0") : QStringLiteral("1"),
                                          show ? QString() : QStringLiteral("NOT "),
                                          insideClause));
            for (int i = 0; i < paths.size(); ++i) {
                query.bindValue(QStringLiteral(":p%1").arg(i),
                        QDir::cleanPath(paths[i]) + QStringLiteral("/%"));
            }
            if (!query.exec()) {
                qWarning() << "Cutlab folders:" << query.lastError();
            }
        }
#ifdef Q_OS_ANDROID
        mixxx::android::hideNonMusic(db);
#endif
    }
    pManager->scanner()->scan();
    return true;
}

int QmlCutlab::hideNonMusic() const {
#ifdef Q_OS_ANDROID
    QSqlDatabase db = database();
    if (!db.isOpen()) {
        return 0;
    }
    return mixxx::android::hideNonMusic(db);
#else
    return 0;
#endif
}

} // namespace qml
} // namespace mixxx
