#include "library/androidscanorder.h"

#include <QDateTime>
#include <QFileInfo>
#include <QList>
#include <QSqlError>
#include <QSqlQuery>
#include <QtDebug>
#include <algorithm>
#include <memory>

#include "library/scanner/libraryscanner.h"
#include "util/datetime.h"
#include "util/db/dbconnectionpooled.h"
#include "util/db/sqltransaction.h"

namespace {

struct ScannedTrack {
    QVariant id;
    QDateTime dateAdded;
    QDateTime fileDate;
};

/// Orders the tracks added at or after scanStart
void orderTracksByFileDate(QSqlDatabase database, const QDateTime& scanStart) {
    QSqlQuery select(database);
    if (!select.exec(QStringLiteral(
                "SELECT library.id, library.datetime_added, track_locations.location "
                "FROM library "
                "INNER JOIN track_locations ON library.location = track_locations.id "
                "ORDER BY library.id"))) {
        qWarning() << "Scan order:" << select.lastError();
        return;
    }
    QList<ScannedTrack> tracks;
    QList<QDateTime> datesAdded;
    while (select.next()) {
        const QDateTime dateAdded = mixxx::convertVariantToDateTime(select.value(1));
        if (!dateAdded.isValid() || dateAdded < scanStart) {
            continue;
        }
        tracks.append({select.value(0),
                dateAdded,
                QFileInfo(select.value(2).toString()).lastModified().toUTC()});
        datesAdded.append(dateAdded);
    }
    if (tracks.size() < 2) {
        return;
    }

    // Oldest file first, files without a date at the end. Ties keep the
    // order of the scan.
    std::stable_sort(tracks.begin(), tracks.end(), [](const auto& a, const auto& b) {
        if (a.fileDate.isValid() != b.fileDate.isValid()) {
            return a.fileDate.isValid();
        }
        return a.fileDate.isValid() && a.fileDate < b.fileDate;
    });
    std::sort(datesAdded.begin(), datesAdded.end());
    // Tracks added within the same millisecond would get the same value and
    // their order would be undefined again
    for (qsizetype i = 1; i < datesAdded.size(); ++i) {
        if (datesAdded[i] <= datesAdded[i - 1]) {
            datesAdded[i] = datesAdded[i - 1].addMSecs(1);
        }
    }

    SqlTransaction transaction(database);
    QSqlQuery update(database);
    update.prepare(QStringLiteral("UPDATE library SET datetime_added=:date WHERE id=:id"));
    for (qsizetype i = 0; i < tracks.size(); ++i) {
        if (tracks[i].dateAdded == datesAdded[i]) {
            continue;
        }
        update.bindValue(QStringLiteral(":date"), datesAdded[i]);
        update.bindValue(QStringLiteral(":id"), tracks[i].id);
        if (!update.exec()) {
            qWarning() << "Scan order:" << update.lastError();
            return;
        }
    }
    if (transaction.commit()) {
        qInfo() << "Ordered the" << tracks.size()
                << "tracks added by the library scan by file date";
    }
}

} // namespace

namespace mixxx {
namespace android {

int hideNonMusic(QSqlDatabase database) {
    QSqlQuery query(database);
    // Hidden tracks (mixxx_deleted) stay in the database with their cues and
    // can be shown again from the hidden tracks view
    if (!query.exec(QStringLiteral(
                "UPDATE library SET mixxx_deleted = 1 "
                "WHERE mixxx_deleted = 0 AND ("
                "(duration > 0 AND duration < 45) OR location IN ("
                "SELECT id FROM track_locations WHERE "
                "lower(location) LIKE '%/whatsapp/%' OR "
                "lower(location) LIKE '%/telegram/%' OR "
                "lower(location) LIKE '%/recordings/%' OR "
                "lower(location) LIKE '%/voice recorder/%' OR "
                "lower(location) LIKE '%/call/%' OR "
                "lower(location) LIKE '%/samsung/%' OR "
                "lower(location) LIKE '%/dcim/%' OR "
                "lower(location) LIKE '%/movies/%' OR "
                "lower(location) LIKE '%/videoeditor%' OR "
                "lower(filename) LIKE 'videoeditor%' OR "
                "lower(filename) LIKE '%.mp4' OR "
                "lower(filename) LIKE '%.3gp' OR "
                "lower(filename) LIKE 'ptt-%' OR "
                "lower(filename) LIKE 'aud-%')"
                ")"))) {
        qWarning() << "Hiding non music files:" << query.lastError();
        return 0;
    }
    const int hidden = query.numRowsAffected();
    if (hidden > 0) {
        qInfo() << "Hid" << hidden << "voice notes, recordings and short files from the library";
    }
    return hidden;
}

void connectScanOrder(
        LibraryScanner* pScanner,
        const mixxx::DbConnectionPoolPtr& pDbConnectionPool) {
    // Both signals are emitted from the scanner thread, which holds a
    // connection of the pool. Only the scanner thread uses the shared start
    // time.
    auto pScanStart = std::make_shared<QDateTime>();
    QObject::connect(
            pScanner,
            &LibraryScanner::scanStarted,
            pScanner,
            [pScanStart]() {
                *pScanStart = QDateTime::currentDateTimeUtc();
            },
            Qt::DirectConnection);
    QObject::connect(
            pScanner,
            &LibraryScanner::scanFinished,
            pScanner,
            [pScanStart, pDbConnectionPool]() {
                if (pScanStart->isValid()) {
                    orderTracksByFileDate(
                            mixxx::DbConnectionPooled(pDbConnectionPool), *pScanStart);
                    hideNonMusic(mixxx::DbConnectionPooled(pDbConnectionPool));
                    *pScanStart = QDateTime();
                }
            },
            Qt::DirectConnection);
}

} // namespace android
} // namespace mixxx
