#include "qml/qmlcutlab.h"

#include <QDateTime>
#include <QElapsedTimer>
#include <QPointer>
#include <QSGRendererInterface>
#include <QQuickWindow>
#include <QScreen>
#include <QTimer>
#include <atomic>
#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QHash>
#include <QSet>
#include <QSqlDatabase>
#include <QSqlError>
#include <QCoreApplication>
#include <QGuiApplication>
#include <QKeyEvent>
#include <QSqlQuery>
#include <QStorageInfo>
#include <QtDebug>
#include <algorithm>
#include <cmath>
#include <vector>

#include "control/controlobject.h"
#include "library/dao/playlistdao.h"
#include "library/dao/trackdao.h"
#include "library/library.h"
#include "library/trackcollection.h"
#include "library/trackset/crate/crate.h"
#include "library/trackset/setlogfeature.h"
#include "library/scanner/libraryscanner.h"
#include "library/trackcollectionmanager.h"
#include "util/cmdlineargs.h"
#include "util/fileinfo.h"
#include "util/sandbox.h"
#include "mixer/playerinfo.h"
#include "moc_qmlcutlab.cpp"
#include "qml/qmllibraryproxy.h"
#include "analyzer/analyzerscheduledtrack.h"
#include "track/beats.h"
#include "track/keyutils.h"
#include "track/track.h"
#include "util/db/dbconnectionpooled.h"
#include "waveform/waveform.h"

#ifdef Q_OS_ANDROID
#include "library/androidscanorder.h"
#include "library/analysis/analysisfeature.h"
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

TrackCollection* internalCollection() {
    Library* pLibrary = QmlLibraryProxy::get();
    if (!pLibrary || !pLibrary->trackCollectionManager()) {
        return nullptr;
    }
    return pLibrary->trackCollectionManager()->internalCollection();
}

TrackId trackIdOf(TrackCollection* pCollection, const QUrl& url) {
    if (!pCollection || !url.isLocalFile()) {
        return TrackId();
    }
    QSqlQuery query(pCollection->database());
    query.prepare(QStringLiteral(
            "SELECT library.id FROM library INNER JOIN track_locations "
            "ON library.location = track_locations.id "
            "WHERE track_locations.location = :location"));
    query.bindValue(QStringLiteral(":location"), url.toLocalFile());
    if (!query.exec() || !query.next()) {
        return TrackId();
    }
    return TrackId(query.value(0));
}

/// How far two tempos are, also at half and double speed (0.02 = 2%)
double tempoGap(double bpmA, double bpmB) {
    double best = 1.0;
    for (const double factor : {1.0, 0.5, 2.0}) {
        best = std::min(best, std::abs(bpmB * factor / bpmA - 1.0));
    }
    return best;
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

namespace {
const QString kMissingAnalysis = QStringLiteral(
        "FROM library INNER JOIN track_locations ON library.location = track_locations.id "
        "WHERE library.mixxx_deleted = 0 AND track_locations.fs_deleted = 0 AND "
        "(library.bpm IS NULL OR library.bpm <= 0 OR library.key IS NULL OR library.key = '') AND "
        "library.id NOT IN (SELECT track_id FROM cutlab_analysis_failed)");
} // namespace

namespace {
// The folders chosen in this session: applied again once their scan is over,
// when their tracks are in the library
QStringList s_chosenFolders;
// The batch analysis, as the analysis feature reports it
int s_analysisDone = 0;
int s_analysisTotal = 0;
// The tracks queued for analysis in this session (once each)
QSet<int> s_queuedForAnalysis;

// Tracks the analysis could not read (a damaged file, an odd format): kept,
// so they are not queued again and again, and counted apart
const QString kFailedTable = QStringLiteral("cutlab_analysis_failed");
void ensureFailedTable(QSqlDatabase& db) {
    QSqlQuery query(db);
    query.exec(QStringLiteral("CREATE TABLE IF NOT EXISTS ") + kFailedTable +
            QStringLiteral(" (track_id INTEGER PRIMARY KEY)"));
}
} // namespace

QmlCutlab::QmlCutlab(QObject* pParent)
        : QObject(pParent) {
    Library* pLibrary = QmlLibraryProxy::get();
    if (pLibrary && pLibrary->trackCollectionManager()) {
        // Emitted from the scanner thread: queued to this one
        connect(pLibrary->trackCollectionManager(),
                &TrackCollectionManager::libraryScanFinished,
                this,
                [this]() {
                    if (!s_chosenFolders.isEmpty()) {
                        applyFolderVisibility(s_chosenFolders);
                        s_chosenFolders.clear();
                    }
                    // BPM, key and waveform of the new tracks, without
                    // playing them first
                    analyzeMissing();
                    emit libraryScanned();
                },
                Qt::QueuedConnection);
    }
    if (pLibrary && pLibrary->analysisFeature()) {
        connect(pLibrary->analysisFeature(),
                &AnalysisFeature::batchProgress,
                this,
                [this](int done, int total) {
                    const bool over = total <= 0 && s_analysisTotal > 0;
                    s_analysisDone = done;
                    s_analysisTotal = total;
                    if (over) {
                        markFailedAnalysis();
                    }
                    emit analysisChanged();
                });
    }
}

void QmlCutlab::markFailedAnalysis() const {
    // The batch is over: the queued tracks still with no BPM or key could
    // not be analyzed
    QSqlDatabase db = database();
    if (!db.isOpen() || s_queuedForAnalysis.isEmpty()) {
        return;
    }
    ensureFailedTable(db);
    QSqlQuery query(db);
    if (!query.exec(QStringLiteral("SELECT library.id ") + kMissingAnalysis)) {
        return;
    }
    QList<int> failed;
    while (query.next()) {
        const int id = query.value(0).toInt();
        if (s_queuedForAnalysis.contains(id)) {
            failed.append(id);
        }
    }
    for (const int id : std::as_const(failed)) {
        QSqlQuery insert(db);
        insert.prepare(QStringLiteral("INSERT OR IGNORE INTO ") + kFailedTable +
                QStringLiteral(" (track_id) VALUES (?)"));
        insert.addBindValue(id);
        insert.exec();
    }
    if (!failed.isEmpty()) {
        qInfo() << "Cutlab:" << failed.size() << "tracks could not be analyzed";
    }
}

int QmlCutlab::analysisDone() const {
    return s_analysisDone;
}

int QmlCutlab::analysisTotal() const {
    return s_analysisTotal;
}

bool QmlCutlab::analysisHeld() const {
    Library* pLibrary = QmlLibraryProxy::get();
    return pLibrary && pLibrary->analysisFeature() &&
            pLibrary->analysisFeature()->isHeldForPlay();
}

int QmlCutlab::analysisFailed() const {
    QSqlDatabase db = database();
    if (!db.isOpen()) {
        return 0;
    }
    ensureFailedTable(db);
    QSqlQuery query(db);
    if (!query.exec(QStringLiteral(
                "SELECT COUNT(*) FROM library WHERE mixxx_deleted = 0 AND "
                "(bpm IS NULL OR bpm <= 0 OR key IS NULL OR key = '') AND id IN "
                "(SELECT track_id FROM ") +
                kFailedTable + QStringLiteral(")")) ||
            !query.next()) {
        return 0;
    }
    return query.value(0).toInt();
}

void QmlCutlab::setAnalysisHeld(bool held) {
    Library* pLibrary = QmlLibraryProxy::get();
    if (!pLibrary || !pLibrary->analysisFeature() ||
            pLibrary->analysisFeature()->isHeldForPlay() == held) {
        return;
    }
    pLibrary->analysisFeature()->setHeldForPlay(held);
    emit analysisChanged();
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
        // Counts up on each press of a controller's browse knob
        new ControlObject(ConfigKey(kCutlabGroup, QStringLiteral("browse_press")));
        // Counts up on each press: next / previous effect of the FX pad of
        // the deck, and the FX lever of the DDJ-REV1 (1 on, 0 off)
        for (int deck = 1; deck <= 2; ++deck) {
            new ControlObject(ConfigKey(kCutlabGroup, QStringLiteral("fx_next%1").arg(deck)));
            new ControlObject(ConfigKey(kCutlabGroup, QStringLiteral("fx_prev%1").arg(deck)));
            new ControlObject(ConfigKey(kCutlabGroup, QStringLiteral("fx_select%1").arg(deck)));
            new ControlObject(ConfigKey(kCutlabGroup, QStringLiteral("fx_on%1").arg(deck)));
            // How much of the effect, 0 to 1, while a controller plays it
            // (the FILTER knob of the Mixtour with FX on); -1 not set
            new ControlObject(ConfigKey(kCutlabGroup, QStringLiteral("fx_amount%1").arg(deck)),
                    true,
                    false,
                    false,
                    -1.0);
            // Counts up on each press: letsktch! on or off on the deck
            new ControlObject(ConfigKey(kCutlabGroup, QStringLiteral("letsktch%1").arg(deck)));
        }
        new ControlObject(ConfigKey(kCutlabGroup, QStringLiteral("scratch_bank")));
        // 1 while the settings or a dialog cover the screen: the browse knob
        // moves in them instead of opening the library
        new ControlObject(ConfigKey(kCutlabGroup, QStringLiteral("modal_open")));
        // Count up on each press: the picked track of the library to the end
        // of the Auto DJ queue, and the menu of the picked track (queue,
        // playlists and crates)
        new ControlObject(ConfigKey(kCutlabGroup, QStringLiteral("queue_add")));
        new ControlObject(ConfigKey(kCutlabGroup, QStringLiteral("track_menu")));
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
                "GROUP BY genre ORDER BY n DESC LIMIT 200"))) {
        qWarning() << "Cutlab genres:" << query.lastError();
        return result;
    }
    while (query.next()) {
        result.append(QVariantMap{
                {QStringLiteral("name"), query.value(0).toString()},
                {QStringLiteral("count"), query.value(1).toInt()},
        });
    }
    // The tracks without a genre, last, with an empty name: none of the
    // genres above counts them
    if (query.exec(QStringLiteral(
                "SELECT COUNT(*) FROM library "
                "WHERE mixxx_deleted = 0 AND (genre IS NULL OR genre = '')")) &&
            query.next() && query.value(0).toInt() > 0) {
        result.append(QVariantMap{
                {QStringLiteral("name"), QString()},
                {QStringLiteral("count"), query.value(0).toInt()},
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
    // MicroSD cards and USB drives, each one as a whole, at the end
    for (const auto& volume : storageVolumes()) {
        const auto map = volume.toMap();
        const QString path = map.value(QStringLiteral("path")).toString();
        const int count = countAudio(path);
        if (count > 0) {
            result.append(QVariantMap{
                    {QStringLiteral("name"), map.value(QStringLiteral("name"))},
                    {QStringLiteral("path"), path},
                    {QStringLiteral("count"), count},
            });
        }
    }
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

void QmlCutlab::sendKey(int key, int modifiers) const {
    QObject* pTarget = QGuiApplication::focusObject();
    if (!pTarget) {
        pTarget = QGuiApplication::focusWindow();
    }
    if (!pTarget) {
        return;
    }
    const auto mods = static_cast<Qt::KeyboardModifiers>(modifiers);
    QKeyEvent press(QEvent::KeyPress, key, mods);
    QCoreApplication::sendEvent(pTarget, &press);
    // The press may have moved the focus: the release goes to the new one
    QObject* pRelease = QGuiApplication::focusObject() ? QGuiApplication::focusObject() : pTarget;
    QKeyEvent release(QEvent::KeyRelease, key, mods);
    QCoreApplication::sendEvent(pRelease, &release);
}

QVariantList QmlCutlab::storageVolumes() const {
    QVariantList result;
    // Android mounts each microSD card and USB drive as /storage/XXXX-XXXX
    const QDir storage(QStringLiteral("/storage"));
    const auto entries = storage.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const auto& entry : entries) {
        const QString name = entry.fileName();
        if (name == QStringLiteral("emulated") || name == QStringLiteral("self") ||
                !entry.isReadable() || QDir(entry.absoluteFilePath()).isEmpty()) {
            continue;
        }
        const QStorageInfo info(entry.absoluteFilePath());
        QString label = info.displayName();
        if (label.isEmpty() || label == entry.absoluteFilePath() || label == name) {
            label = tr("MicroSD o pendrive");
        }
        result.append(QVariantMap{
                {QStringLiteral("name"), label},
                {QStringLiteral("path"), entry.absoluteFilePath()},
                {QStringLiteral("id"), name},
        });
    }
    return result;
}

bool QmlCutlab::addFolder(const QString& path) const {
    Library* pLibrary = QmlLibraryProxy::get();
    if (!pLibrary || path.isEmpty() || !QDir(path).exists()) {
        return false;
    }
    TrackCollectionManager* pManager = pLibrary->trackCollectionManager();
    const QString clean = QDir::cleanPath(path);
    for (const auto& folder : folders()) {
        const QString existing = QDir::cleanPath(folder);
        if (clean == existing || clean.startsWith(existing + QChar('/'))) {
            // Already in the library: only look for new files
            pManager->scanner()->scan();
            return true;
        }
    }
    QDir directory(clean);
    Sandbox::createSecurityTokenForDir(directory);
    pManager->addDirectory(mixxx::FileInfo(clean));
    pManager->scanner()->scan();
    return true;
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
    applyFolderVisibility(paths);
    s_chosenFolders = paths;
    pManager->scanner()->scan();
    return true;
}

void QmlCutlab::applyFolderVisibility(const QStringList& paths) const {
    QSqlDatabase db = database();
    if (!db.isOpen() || paths.isEmpty()) {
        return;
    }
    QStringList inside;
    for (int i = 0; i < paths.size(); ++i) {
        inside.append(QStringLiteral("track_locations.location LIKE :p%1").arg(i));
    }
    const QString insideClause = inside.join(QStringLiteral(" OR "));
    auto bindPaths = [&paths](QSqlQuery& query) {
        for (int i = 0; i < paths.size(); ++i) {
            query.bindValue(QStringLiteral(":p%1").arg(i),
                    QDir::cleanPath(paths[i]) + QStringLiteral("/%"));
        }
    };
    // Nothing of the chosen folders in the library yet (not scanned, or
    // stored under another path): hide nothing, so the library never ends
    // up empty
    {
        QSqlQuery count(db);
        count.prepare(QStringLiteral(
                "SELECT COUNT(*) FROM track_locations WHERE %1")
                              .arg(insideClause));
        bindPaths(count);
        if (!count.exec() || !count.next() || count.value(0).toInt() == 0) {
            return;
        }
    }
    for (const bool show : {false, true}) {
        QSqlQuery query(db);
        query.prepare(QStringLiteral(
                "UPDATE library SET mixxx_deleted = %1 WHERE location IN ("
                "SELECT track_locations.id FROM track_locations WHERE %2(%3))")
                              .arg(show ? QStringLiteral("0") : QStringLiteral("1"),
                                      show ? QString() : QStringLiteral("NOT "),
                                      insideClause));
        bindPaths(query);
        if (!query.exec()) {
            qWarning() << "Cutlab folders:" << query.lastError();
        }
    }
#ifdef Q_OS_ANDROID
    mixxx::android::hideNonMusic(db);
#endif
}



int QmlCutlab::missingAnalysis() const {
    QSqlDatabase db = database();
    if (db.isOpen()) {
        ensureFailedTable(db);
    }
    QSqlQuery query(db);
    if (!db.isOpen() || !query.exec(QStringLiteral("SELECT COUNT(*) ") + kMissingAnalysis) ||
            !query.next()) {
        return 0;
    }
    return query.value(0).toInt();
}

int QmlCutlab::analyzeMissing() const {
    Library* pLibrary = QmlLibraryProxy::get();
    QSqlDatabase db = database();
    if (!pLibrary || !db.isOpen()) {
        return 0;
    }
    ensureFailedTable(db);
    QSqlQuery query(db);
    // Newest first: the tracks just added are the ones looked for
    if (!query.exec(QStringLiteral("SELECT library.id ") + kMissingAnalysis +
                QStringLiteral(" ORDER BY library.datetime_added DESC"))) {
        qWarning() << "Cutlab analysis:" << query.lastError();
        return 0;
    }
    // Each track is queued once per session: a scan or the timer again
    // don't pile the same tracks up
    QList<AnalyzerScheduledTrack> tracks;
    while (query.next()) {
        const int id = query.value(0).toInt();
        if (s_queuedForAnalysis.contains(id)) {
            continue;
        }
        s_queuedForAnalysis.insert(id);
        tracks.append(AnalyzerScheduledTrack(TrackId(query.value(0))));
    }
    if (!tracks.isEmpty()) {
        qInfo() << "Cutlab: analyzing" << tracks.size() << "tracks without BPM or key";
        emit pLibrary->analyzeTracks(tracks);
    }
    return static_cast<int>(tracks.size());
}

QString QmlCutlab::deckKey(const QString& group) const {
    const TrackPointer pTrack = PlayerInfo::instance().getTrackInfo(group);
    if (!pTrack) {
        return QString();
    }
    const auto key = pTrack->getKey();
    if (key == mixxx::track::io::key::INVALID) {
        return QString();
    }
    return KeyUtils::keyToString(key, KeyUtils::KeyNotation::Lancelot);
}

QString QmlCutlab::camelot(const QString& keyText) const {
    if (keyText.trimmed().isEmpty()) {
        return QString();
    }
    const auto key = KeyUtils::guessKeyFromText(keyText);
    if (key == mixxx::track::io::key::INVALID) {
        return QString();
    }
    return KeyUtils::keyToString(key, KeyUtils::KeyNotation::Lancelot);
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

double QmlCutlab::firstBeat(const QString& group) const {
    const TrackPointer pTrack = PlayerInfo::instance().getTrackInfo(group);
    if (!pTrack) {
        return -1;
    }
    const mixxx::BeatsPointer pBeats = pTrack->getBeats();
    const auto sampleRate = pTrack->getSampleRate();
    if (!pBeats || !sampleRate.isValid()) {
        return -1;
    }
    const auto first = pBeats->firstBeat();
    if (!first.isValid()) {
        return -1;
    }
    return first.value() / sampleRate.value();
}

int QmlCutlab::queueCount() const {
    TrackCollection* pCollection = internalCollection();
    if (!pCollection) {
        return 0;
    }
    return static_cast<int>(pCollection->getPlaylistDAO().getAutoDJTrackIds().size());
}

bool QmlCutlab::addToQueue(const QUrl& url, bool top) const {
    TrackCollection* pCollection = internalCollection();
    const TrackId trackId = trackIdOf(pCollection, url);
    if (!trackId.isValid()) {
        return false;
    }
    pCollection->getPlaylistDAO().addTracksToAutoDJQueue(QList<TrackId>{trackId},
            top ? PlaylistDAO::AutoDJSendLoc::TOP : PlaylistDAO::AutoDJSendLoc::BOTTOM);
    return true;
}

int QmlCutlab::fillQueue(const QString& group, int count) const {
    TrackCollection* pCollection = internalCollection();
    QSqlDatabase db = database();
    if (!pCollection || !db.isOpen() || count <= 0) {
        return 0;
    }
    struct Row {
        int id;
        QString artist;
        double bpm;
        int key;
        QString genre;
        QString location;
        QDateTime lastPlayed;
    };
    std::vector<Row> rows;
    QHash<int, int> rowOfId;
    {
        QSqlQuery query(db);
        if (!query.exec(QStringLiteral(
                    "SELECT library.id, library.artist, library.bpm, library.key_id, "
                    "library.genre, track_locations.location, library.last_played_at "
                    "FROM library INNER JOIN track_locations "
                    "ON library.location = track_locations.id "
                    "WHERE library.mixxx_deleted = 0 AND track_locations.fs_deleted = 0"))) {
            qWarning() << "Cutlab fill queue:" << query.lastError();
            return 0;
        }
        while (query.next()) {
            rowOfId.insert(query.value(0).toInt(), static_cast<int>(rows.size()));
            rows.push_back(Row{query.value(0).toInt(),
                    query.value(1).toString().trimmed(),
                    query.value(2).toDouble(),
                    query.value(3).toInt(),
                    query.value(4).toString().trimmed().toLower(),
                    query.value(5).toString(),
                    query.value(6).toDateTime()});
        }
    }

    // What is loaded, queued or already picked never comes twice, and
    // neither does its artist
    QSet<int> usedIds;
    QSet<QString> usedArtists;
    QSet<QString> loaded;
    const auto loadedTracks = PlayerInfo::instance().getLoadedTracks();
    for (const auto& pLoaded : loadedTracks) {
        if (!pLoaded) {
            continue;
        }
        loaded.insert(pLoaded->getLocation());
        if (pLoaded->getId().isValid()) {
            usedIds.insert(pLoaded->getId().toVariant().toInt());
        }
        const QString artist = pLoaded->getArtist().trimmed().toLower();
        if (!artist.isEmpty()) {
            usedArtists.insert(artist);
        }
    }
    PlaylistDAO& playlists = pCollection->getPlaylistDAO();
    const QList<TrackId> queued = playlists.getAutoDJTrackIds();
    for (const TrackId& trackId : queued) {
        const int id = trackId.toVariant().toInt();
        usedIds.insert(id);
        const auto it = rowOfId.constFind(id);
        if (it != rowOfId.constEnd() && !rows[it.value()].artist.isEmpty()) {
            usedArtists.insert(rows[it.value()].artist.toLower());
        }
    }

    // Chain from the last track of the queue, else from the deck
    double bpm = 0;
    int key = 0;
    QString genre;
    bool haveReference = false;
    if (!queued.isEmpty()) {
        const auto it = rowOfId.constFind(queued.last().toVariant().toInt());
        if (it != rowOfId.constEnd()) {
            const Row& last = rows[it.value()];
            bpm = last.bpm;
            key = last.key;
            genre = last.genre;
            haveReference = true;
        }
    }
    if (!haveReference) {
        const TrackPointer pTrack = PlayerInfo::instance().getTrackInfo(group);
        if (!pTrack) {
            return 0;
        }
        bpm = pTrack->getBpm();
        key = static_cast<int>(pTrack->getKey());
        genre = pTrack->getGenre().trimmed().toLower();
    }
    // The whole queue stays close to where it starts
    const double startBpm = bpm;
    const QDateTime recent = QDateTime::currentDateTimeUtc().addSecs(-6 * 3600);

    QList<TrackId> picked;
    for (int step = 0; step < count; ++step) {
        int best = -1;
        double bestScore = -1e9;
        for (int i = 0; i < static_cast<int>(rows.size()); ++i) {
            const Row& row = rows[i];
            if (usedIds.contains(row.id) || loaded.contains(row.location)) {
                continue;
            }
            if (row.lastPlayed.isValid() && row.lastPlayed.toUTC() > recent) {
                continue;
            }
            if (!row.artist.isEmpty() && usedArtists.contains(row.artist.toLower())) {
                continue;
            }
            double score = 0;
            if (bpm > 0) {
                if (row.bpm <= 0) {
                    // Not analyzed yet: its tempo is unknown
                    continue;
                }
                const double gap = tempoGap(bpm, row.bpm);
                if (gap > 0.08 || (startBpm > 0 && tempoGap(startBpm, row.bpm) > 0.08)) {
                    continue;
                }
                score += 40 * (1.0 - gap / 0.08);
            }
            const int match = keyMatch(key, row.key);
            if (match == 0) {
                continue;
            }
            score += match == 3 ? 30 : (match == 2 ? 22 : 0);
            if (!genre.isEmpty() && row.genre == genre) {
                score += 15;
            }
            if (score > bestScore) {
                bestScore = score;
                best = i;
            }
        }
        if (best < 0) {
            break;
        }
        const Row& row = rows[best];
        picked.append(TrackId(QVariant(row.id)));
        usedIds.insert(row.id);
        if (!row.artist.isEmpty()) {
            usedArtists.insert(row.artist.toLower());
        }
        bpm = row.bpm;
        key = row.key;
        if (!row.genre.isEmpty()) {
            genre = row.genre;
        }
    }
    if (!picked.isEmpty()) {
        playlists.addTracksToAutoDJQueue(picked, PlaylistDAO::AutoDJSendLoc::BOTTOM);
    }
    return static_cast<int>(picked.size());
}

QVariantList QmlCutlab::lists() const {
    QVariantList result;
    QSqlDatabase db = database();
    if (!db.isOpen()) {
        return result;
    }
    QSqlQuery query(db);
    if (query.exec(QStringLiteral(
                "SELECT id, name FROM Playlists WHERE hidden = 0 "
                "ORDER BY date_modified DESC, id DESC"))) {
        while (query.next()) {
            result.append(QVariantMap{
                    {QStringLiteral("kind"), QStringLiteral("playlist")},
                    {QStringLiteral("id"), query.value(0).toInt()},
                    {QStringLiteral("name"), query.value(1).toString()},
            });
        }
    } else {
        qWarning() << "Cutlab playlists:" << query.lastError();
    }
    if (query.exec(QStringLiteral("SELECT id, name FROM crates ORDER BY name COLLATE NOCASE"))) {
        while (query.next()) {
            result.append(QVariantMap{
                    {QStringLiteral("kind"), QStringLiteral("crate")},
                    {QStringLiteral("id"), query.value(0).toInt()},
                    {QStringLiteral("name"), query.value(1).toString()},
            });
        }
    } else {
        qWarning() << "Cutlab crates:" << query.lastError();
    }
    return result;
}

int QmlCutlab::createList(const QString& kind, const QString& name) const {
    TrackCollection* pCollection = internalCollection();
    if (!pCollection) {
        return -1;
    }
    QString base = name.trimmed();
    if (kind == QStringLiteral("crate")) {
        if (base.isEmpty()) {
            base = tr("Caja nueva");
        }
        QSqlDatabase db = database();
        QString unique = base;
        for (int number = 2; db.isOpen() && number < 1000; ++number) {
            QSqlQuery query(db);
            query.prepare(QStringLiteral("SELECT 1 FROM crates WHERE name = :name"));
            query.bindValue(QStringLiteral(":name"), unique);
            if (!query.exec() || !query.next()) {
                break;
            }
            unique = base + QChar(' ') + QString::number(number);
        }
        Crate crate;
        crate.setName(unique);
        CrateId crateId;
        if (!pCollection->insertCrate(crate, &crateId) || !crateId.isValid()) {
            return -1;
        }
        return crateId.toVariant().toInt();
    }
    if (base.isEmpty()) {
        base = tr("Lista nueva");
    }
    QString unique = base;
    return pCollection->getPlaylistDAO().createUniquePlaylist(&unique);
}

bool QmlCutlab::addToList(const QString& kind, int id, const QUrl& url) const {
    TrackCollection* pCollection = internalCollection();
    const TrackId trackId = trackIdOf(pCollection, url);
    if (!trackId.isValid() || id < 0) {
        return false;
    }
    if (kind == QStringLiteral("crate")) {
        return pCollection->addCrateTracks(CrateId(QVariant(id)), QList<TrackId>{trackId});
    }
    PlaylistDAO& playlists = pCollection->getPlaylistDAO();
    if (playlists.isTrackInPlaylist(trackId, id)) {
        return true;
    }
    return playlists.appendTrackToPlaylist(trackId, id);
}

bool QmlCutlab::markPlayed(const QString& group) const {
    const TrackPointer pTrack = PlayerInfo::instance().getTrackInfo(group);
    Library* pLibrary = QmlLibraryProxy::get();
    if (!pTrack || !pLibrary) {
        return false;
    }
    SetlogFeature* pHistory = pLibrary->historyFeature();
    if (pHistory) {
        // Also counts the play
        pHistory->addPlayedTrack(pTrack);
    } else {
        pTrack->updatePlayCounter();
    }
    return true;
}


namespace {
// The frames of the watched window. The render thread writes, the GUI
// thread reads once a second.
struct FrameWatch {
    QPointer<QQuickWindow> window;
    QObject* context{nullptr}; // owns the connections and the timers
    QElapsedTimer clock;
    std::atomic<qint64> syncStart{0};
    std::atomic<qint64> syncEnd{0};
    std::atomic<qint64> renderEnd{0};
    std::atomic<qint64> lastSwap{0};
    std::atomic<qint64> syncSum{0};
    std::atomic<qint64> syncMax{0};
    std::atomic<qint64> renderSum{0};
    std::atomic<qint64> renderMax{0};
    std::atomic<qint64> presentSum{0};
    std::atomic<qint64> presentMax{0};
    std::atomic<qint64> gapMax{0};
    std::atomic<int> frames{0};
    std::atomic<int> late{0};
    // GUI thread: how late a 4 ms timer fires
    qint64 lastProbe{0};
    qint64 guiStallMax{0};
};
FrameWatch* s_frameWatch = nullptr;

void raiseMax(std::atomic<qint64>& max, qint64 value) {
    qint64 current = max.load(std::memory_order_relaxed);
    while (value > current &&
            !max.compare_exchange_weak(current, value, std::memory_order_relaxed)) {
    }
}
} // namespace

void QmlCutlab::watchFrames(QObject* windowObject, bool on) {
    if (s_frameWatch) {
        // Disconnects all; the few bytes of the watch stay, a frame of the
        // render thread may still be writing to them
        delete s_frameWatch->context;
        s_frameWatch = nullptr;
    }
    auto* const pWindow = qobject_cast<QQuickWindow*>(windowObject);
    if (!on || !pWindow) {
        return;
    }
    auto* const pWatch = new FrameWatch;
    s_frameWatch = pWatch;
    pWatch->window = pWindow;
    pWatch->context = new QObject(this);
    pWatch->clock.start();
    // Render thread (direct): sync, record, present
    connect(pWindow,
            &QQuickWindow::beforeSynchronizing,
            pWatch->context,
            [pWatch]() { pWatch->syncStart = pWatch->clock.nsecsElapsed(); },
            Qt::DirectConnection);
    connect(pWindow,
            &QQuickWindow::afterSynchronizing,
            pWatch->context,
            [pWatch]() {
                const qint64 now = pWatch->clock.nsecsElapsed();
                pWatch->syncEnd = now;
                const qint64 sync = now - pWatch->syncStart;
                pWatch->syncSum += sync;
                raiseMax(pWatch->syncMax, sync);
            },
            Qt::DirectConnection);
    connect(pWindow,
            &QQuickWindow::afterRendering,
            pWatch->context,
            [pWatch]() {
                const qint64 now = pWatch->clock.nsecsElapsed();
                pWatch->renderEnd = now;
                const qint64 render = now - pWatch->syncEnd;
                pWatch->renderSum += render;
                raiseMax(pWatch->renderMax, render);
            },
            Qt::DirectConnection);
    connect(pWindow,
            &QQuickWindow::frameSwapped,
            pWatch->context,
            [pWatch]() {
                const qint64 now = pWatch->clock.nsecsElapsed();
                const qint64 present = now - pWatch->renderEnd;
                pWatch->presentSum += present;
                raiseMax(pWatch->presentMax, present);
                const qint64 previous = pWatch->lastSwap.exchange(now);
                if (previous > 0) {
                    const qint64 gap = now - previous;
                    raiseMax(pWatch->gapMax, gap);
                    const qreal hz = pWatch->window && pWatch->window->screen()
                            ? pWatch->window->screen()->refreshRate()
                            : 60.0;
                    if (gap > static_cast<qint64>(1.5e9 / std::max<qreal>(30.0, hz))) {
                        pWatch->late++;
                    }
                }
                pWatch->frames++;
            },
            Qt::DirectConnection);
    // GUI thread: a 4 ms timer; when it fires late, the GUI thread was busy
    auto* const pProbe = new QTimer(pWatch->context);
    pProbe->setTimerType(Qt::PreciseTimer);
    pProbe->setInterval(4);
    connect(pProbe, &QTimer::timeout, pWatch->context, [pWatch]() {
        const qint64 now = pWatch->clock.nsecsElapsed();
        if (pWatch->lastProbe > 0) {
            pWatch->guiStallMax = std::max(pWatch->guiStallMax, now - pWatch->lastProbe);
        }
        pWatch->lastProbe = now;
    });
    pProbe->start();
    // Once a second: the numbers, to the screen and to the log
    auto* const pReport = new QTimer(pWatch->context);
    pReport->setInterval(1000);
    connect(pReport, &QTimer::timeout, this, [this, pWatch]() {
        const int frames = pWatch->frames.exchange(0);
        const int n = std::max(1, frames);
        const auto ms = [](qint64 ns) {
            return std::round(ns / 1e5) / 10.0;
        };
        QVariantMap stats;
        stats.insert(QStringLiteral("fps"), frames);
        stats.insert(QStringLiteral("hz"),
                pWatch->window && pWatch->window->screen()
                        ? pWatch->window->screen()->refreshRate()
                        : 0.0);
        stats.insert(QStringLiteral("late"), pWatch->late.exchange(0));
        stats.insert(QStringLiteral("worstMs"), ms(pWatch->gapMax.exchange(0)));
        stats.insert(QStringLiteral("syncMs"), ms(pWatch->syncSum.exchange(0) / n));
        stats.insert(QStringLiteral("syncMaxMs"), ms(pWatch->syncMax.exchange(0)));
        stats.insert(QStringLiteral("renderMs"), ms(pWatch->renderSum.exchange(0) / n));
        stats.insert(QStringLiteral("renderMaxMs"), ms(pWatch->renderMax.exchange(0)));
        stats.insert(QStringLiteral("presentMs"), ms(pWatch->presentSum.exchange(0) / n));
        stats.insert(QStringLiteral("presentMaxMs"), ms(pWatch->presentMax.exchange(0)));
        stats.insert(QStringLiteral("guiStallMs"), ms(pWatch->guiStallMax));
        pWatch->guiStallMax = 0;
        stats.insert(QStringLiteral("analyzing"), s_analysisTotal > 0);
        stats.insert(QStringLiteral("analysisHeld"), analysisHeld());
        const QSize size = pWatch->window ? pWatch->window->size() * pWatch->window->devicePixelRatio()
                                          : QSize();
        stats.insert(QStringLiteral("pixels"),
                QStringLiteral("%1x%2").arg(size.width()).arg(size.height()));
        qInfo().noquote() << "Cutlab frames:"
                          << QStringLiteral(
                                     "fps=%1 hz=%2 late=%3 worst=%4ms sync=%5/%6ms "
                                     "render=%7/%8ms present=%9/%10ms gui_stall=%11ms "
                                     "analyzing=%12 held=%13 pixels=%14")
                                     .arg(stats.value(QStringLiteral("fps")).toInt())
                                     .arg(stats.value(QStringLiteral("hz")).toDouble(), 0, 'f', 0)
                                     .arg(stats.value(QStringLiteral("late")).toInt())
                                     .arg(stats.value(QStringLiteral("worstMs")).toDouble())
                                     .arg(stats.value(QStringLiteral("syncMs")).toDouble())
                                     .arg(stats.value(QStringLiteral("syncMaxMs")).toDouble())
                                     .arg(stats.value(QStringLiteral("renderMs")).toDouble())
                                     .arg(stats.value(QStringLiteral("renderMaxMs")).toDouble())
                                     .arg(stats.value(QStringLiteral("presentMs")).toDouble())
                                     .arg(stats.value(QStringLiteral("presentMaxMs")).toDouble())
                                     .arg(stats.value(QStringLiteral("guiStallMs")).toDouble())
                                     .arg(stats.value(QStringLiteral("analyzing")).toBool() ? 1 : 0)
                                     .arg(stats.value(QStringLiteral("analysisHeld")).toBool() ? 1 : 0)
                                     .arg(stats.value(QStringLiteral("pixels")).toString());
        emit frameStats(stats);
    });
    pReport->start();
    qInfo() << "Cutlab: watching frames, graphics API"
            << static_cast<int>(pWindow->rendererInterface()
                               ? pWindow->rendererInterface()->graphicsApi()
                               : QSGRendererInterface::Unknown);
}

bool QmlCutlab::shareLog() const {
#ifdef Q_OS_ANDROID
    QStringList files;
    const QString settingsPath = CmdlineArgs::Instance().getSettingsPath();
    for (const QString& name : {QStringLiteral("mixxx.log"), QStringLiteral("mixxx.log.1")}) {
        const QString path = QDir(settingsPath).filePath(name);
        if (QFileInfo::exists(path)) {
            files.append(path);
        }
    }
    // The crash reports
    const QDir crashes(QStringLiteral("/storage/emulated/0/Mixxx/logs"));
    for (const QFileInfo& info : crashes.entryInfoList(QDir::Files, QDir::Time)) {
        if (files.size() >= 8) {
            break;
        }
        if (info.fileName() != QStringLiteral("mixxx-previous.log")) {
            files.append(info.absoluteFilePath());
        }
    }
    if (files.isEmpty()) {
        return false;
    }
    return QJniObject::callStaticMethod<jboolean>("org/mixxx/LogShare",
            "share",
            "(Landroid/content/Context;Ljava/lang/String;)Z",
            QNativeInterface::QAndroidApplication::context().object(),
            QJniObject::fromString(files.join(QLatin1Char('\n'))).object<jstring>());
#else
    return false;
#endif
}

} // namespace qml
} // namespace mixxx
