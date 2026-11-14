#include "util/androidbackup.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSqlError>
#include <QSqlQuery>
#include <QMutex>
#include <QMutexLocker>
#include <QUuid>
#include <QtDebug>
#include <algorithm>

namespace mixxx {
namespace android {

namespace {

const QString kDatabaseFileName = QStringLiteral("mixxxdb.sqlite");
const QString kPendingDirName = QStringLiteral("restore_pending");
const QString kPreviousDirName = QStringLiteral("restore_previous");
/// Written last when staging, so an interrupted copy is never applied
const QString kCompleteMarker = QStringLiteral(".complete");
const QString kInfoFileName = QStringLiteral("backup-info.txt");
const QString kConfigFileName = QStringLiteral("mixxx.cfg");
/// Secrets that must not be written to the shared storage
const QString kStreamingGroup = QStringLiteral("[Streaming]");
const QString kSubsonicPasswordKey = QStringLiteral("SubsonicPassword");
/// The snapshot that Android's Auto Backup saves (see
/// packaging/android/res/xml/data_extraction_rules.xml)
const QString kCloudDirName = QStringLiteral("cloud-backup");
/// When the last automatic backup was made, in the cloud folder
const QString kLastAutoStamp = QStringLiteral(".last-auto");
const QString kAutoSuffix = QStringLiteral("_auto");
constexpr int kKeptAutoBackups = 3;
/// Settings files bigger than this are not settings (a stray export...)
constexpr qint64 kMaxFileSize = 8 * 1024 * 1024;

/// One backup at a time: the manual button, the automatic one in a worker
/// thread and the one at closing could otherwise write the same folder
QMutex s_backupMutex;

/// Entries of the settings folder that are backed up. The settings folder is
/// also where the stems of tracks in read-only folders and the stem models
/// are (hundreds of MB), so only the settings files and a few small
/// folders go in.
bool isIncluded(const QFileInfo& entry) {
    const QString name = entry.fileName();
    if (name.startsWith(kDatabaseFileName) || // copied separately
            name.startsWith(QStringLiteral("mixxx.log")) ||
            name == kPendingDirName || name == kPreviousDirName || name == kCloudDirName) {
        return false;
    }
    if (entry.isDir()) {
        return name == QStringLiteral("controllers") || name == QStringLiteral("effects") ||
                name == QStringLiteral("keyboard");
    }
    return entry.isFile() && entry.size() <= kMaxFileSize;
}

QString timestampName() {
    return QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd_HH-mm-ss"));
}

bool copyRecursively(const QString& source, const QString& target) {
    const QFileInfo sourceInfo(source);
    if (!sourceInfo.isDir()) {
        QFile::remove(target);
        return QFile::copy(source, target);
    }
    if (!QDir().mkpath(target)) {
        return false;
    }
    const QStringList entries =
            QDir(source).entryList(QDir::AllEntries | QDir::Hidden | QDir::NoDotAndDotDot);
    for (const auto& entry : entries) {
        if (!copyRecursively(source + QChar('/') + entry, target + QChar('/') + entry)) {
            return false;
        }
    }
    return true;
}

bool isSubsonicPasswordLine(const QString& line) {
    return line.startsWith(kSubsonicPasswordKey + QChar(' '));
}

/// The configuration without the Subsonic password, which would be readable
/// by every app with storage access in the backup folder
bool copyConfigWithoutSecrets(const QString& source, const QString& target) {
    QFile in(source);
    if (!in.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return false;
    }
    QStringList lines = QString::fromUtf8(in.readAll()).split(QChar('\n'));
    lines.erase(std::remove_if(lines.begin(), lines.end(), isSubsonicPasswordLine), lines.end());
    QFile out(target);
    return out.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text) &&
            out.write(lines.join(QChar('\n')).toUtf8()) >= 0;
}

/// Puts the Subsonic password of the replaced configuration (backups don't
/// contain it) into the restored one
void keepSubsonicPassword(const QString& previousConfig, const QString& restoredConfig) {
    QFile previous(previousConfig);
    if (!previous.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return;
    }
    QString passwordLine;
    QString group;
    for (const auto& line : QString::fromUtf8(previous.readAll()).split(QChar('\n'))) {
        if (line.startsWith(QChar('['))) {
            group = line.trimmed();
        } else if (group == kStreamingGroup && isSubsonicPasswordLine(line)) {
            passwordLine = line;
        }
    }
    if (passwordLine.isEmpty()) {
        return;
    }
    QFile restored(restoredConfig);
    if (!restored.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return;
    }
    QStringList lines = QString::fromUtf8(restored.readAll()).split(QChar('\n'));
    restored.close();
    const auto groupLine = std::find_if(lines.begin(), lines.end(), [](const QString& line) {
        return line.trimmed() == kStreamingGroup;
    });
    if (groupLine == lines.end()) {
        lines << QString() << kStreamingGroup << passwordLine;
    } else {
        lines.insert(groupLine + 1, passwordLine);
    }
    if (!restored.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text) ||
            restored.write(lines.join(QChar('\n')).toUtf8()) < 0) {
        qWarning() << "Restore: cannot keep the Subsonic password in" << restoredConfig;
    }
}

bool removePath(const QString& path) {
    const QFileInfo info(path);
    if (!info.exists() && !info.isSymLink()) {
        return true;
    }
    return info.isDir() ? QDir(path).removeRecursively() : QFile::remove(path);
}

/// Copies the settings files into `backupDir` (which already has the
/// database) and writes the info file
bool copySettings(const QString& settingsPath, const QString& backupDir, QString* pError) {
    const QFileInfoList entries = QDir(settingsPath).entryInfoList(
            QDir::AllEntries | QDir::Hidden | QDir::NoDotAndDotDot);
    for (const auto& entry : entries) {
        if (!isIncluded(entry)) {
            continue;
        }
        const QString name = entry.fileName();
        const QString source = entry.absoluteFilePath();
        const QString target = backupDir + QChar('/') + name;
        const bool copied = name == kConfigFileName
                ? copyConfigWithoutSecrets(source, target)
                : copyRecursively(source, target);
        if (!copied) {
            *pError = QCoreApplication::translate("AndroidBackup", "Cannot copy %1").arg(name);
            return false;
        }
    }
    QFile info(backupDir + QChar('/') + kInfoFileName);
    if (info.open(QIODevice::WriteOnly | QIODevice::Text)) {
        info.write(QStringLiteral("Cutlab %1 backup, created %2\n")
                        .arg(QCoreApplication::applicationVersion(),
                                QDateTime::currentDateTime().toString(Qt::ISODate))
                        .toUtf8());
    }
    return true;
}

bool vacuumInto(QSqlDatabase& database, const QString& targetFile, QString* pError) {
    QFile::remove(targetFile);
    QSqlQuery query(database);
    query.prepare(QStringLiteral("VACUUM INTO :path"));
    query.bindValue(QStringLiteral(":path"), targetFile);
    if (!query.exec()) {
        *pError = QCoreApplication::translate("AndroidBackup", "Cannot copy the library database: %1")
                          .arg(query.lastError().text());
        return false;
    }
    return true;
}

/// Writes a complete backup into `finalDir`: first into a temporary folder
/// next to it, renamed when complete, so a backup cut halfway (Android
/// killing the app) never replaces a good one
bool writeBackup(const QString& settingsPath,
        QSqlDatabase& database,
        const QString& finalDir,
        QString* pError) {
    const QString tempDir = finalDir + QStringLiteral(".tmp");
    removePath(tempDir);
    if (!QDir().mkpath(tempDir)) {
        *pError = QCoreApplication::translate("AndroidBackup", "Cannot create %1").arg(finalDir);
        return false;
    }
    if (!vacuumInto(database, tempDir + QChar('/') + kDatabaseFileName, pError) ||
            !copySettings(settingsPath, tempDir, pError)) {
        removePath(tempDir);
        return false;
    }
    removePath(finalDir);
    if (!QDir().rename(tempDir, finalDir)) {
        *pError = QCoreApplication::translate("AndroidBackup", "Cannot create %1").arg(finalDir);
        removePath(tempDir);
        return false;
    }
    return true;
}

/// Deletes the automatic backups in `root` but the newest `keep`
void pruneAutoBackups(const QString& root, int keep) {
    QStringList autos = QDir(root).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    autos.erase(std::remove_if(autos.begin(),
                        autos.end(),
                        [](const QString& name) { return !name.endsWith(kAutoSuffix); }),
            autos.end());
    std::sort(autos.begin(), autos.end(), std::greater<>());
    for (int i = keep; i < autos.size(); ++i) {
        removePath(root + QChar('/') + autos[i]);
    }
}

QString cloudRoot(const QString& settingsPath) {
    return QDir(settingsPath).filePath(kCloudDirName);
}

/// The settings folder, saved by applyPendingRestore()'s caller for
/// listBackups(), which has no settings path
QString s_settingsPath;

QDateTime lastChange(const QString& settingsPath) {
    QDateTime newest;
    // The library only: the settings are saved each time the app goes to
    // the background, they alone are no reason for a new backup
    for (const auto& name : {kDatabaseFileName, kDatabaseFileName + QStringLiteral("-wal")}) {
        const QFileInfo info(QDir(settingsPath).filePath(name));
        if (info.exists() && (!newest.isValid() || info.lastModified() > newest)) {
            newest = info.lastModified();
        }
    }
    return newest;
}

} // namespace

QString backupRootDirectory() {
    return QStringLiteral("/storage/emulated/0/Music/Cutlab/backup");
}

QString legacyBackupRootDirectory() {
    return QStringLiteral("/storage/emulated/0/Mixxx/backup");
}

QString createBackup(const QString& settingsPath, QSqlDatabase database, QString* pError) {
    QMutexLocker lock(&s_backupMutex);
    const QString backupDir = backupRootDirectory() + QChar('/') + timestampName();
    if (!QDir().mkpath(backupRootDirectory())) {
        *pError = QCoreApplication::translate("AndroidBackup", "Cannot create %1").arg(backupDir);
        return {};
    }
    if (!writeBackup(settingsPath, database, backupDir, pError)) {
        return {};
    }
    qInfo() << "Created backup" << backupDir;
    return backupDir;
}

bool createAutoBackup(const QString& settingsPath,
        const QString& connectionName,
        bool sharedStorage) {
    QMutexLocker lock(&s_backupMutex);
    const QString cloneName = QStringLiteral("cutlab-backup-") +
            QUuid::createUuid().toString(QUuid::WithoutBraces);
    bool written = false;
    {
        QSqlDatabase database = QSqlDatabase::cloneDatabase(connectionName, cloneName);
        if (!database.open()) {
            qWarning() << "Automatic backup: cannot open the database" << database.lastError();
        } else {
            const QString name = timestampName() + kAutoSuffix;
            QString error;
            if (sharedStorage && QDir().mkpath(backupRootDirectory())) {
                const QString dir = backupRootDirectory() + QChar('/') + name;
                if (writeBackup(settingsPath, database, dir, &error)) {
                    pruneAutoBackups(backupRootDirectory(), kKeptAutoBackups);
                    written = true;
                } else {
                    qWarning() << "Automatic backup:" << error;
                }
            }
            // The snapshot for Android's backup: only the newest one
            const QString cloud = cloudRoot(settingsPath);
            if (QDir().mkpath(cloud) &&
                    writeBackup(settingsPath, database, cloud + QChar('/') + name, &error)) {
                pruneAutoBackups(cloud, 1);
                written = true;
            } else {
                qWarning() << "Automatic backup (Android backup):" << error;
            }
            database.close();
        }
    }
    QSqlDatabase::removeDatabase(cloneName);
    if (written) {
        QFile stamp(QDir(cloudRoot(settingsPath)).filePath(kLastAutoStamp));
        if (stamp.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            stamp.write(QByteArray::number(QDateTime::currentMSecsSinceEpoch()));
        }
        qInfo() << "Automatic backup of the library done";
    }
    return written;
}

bool changedSinceAutoBackup(const QString& settingsPath) {
    QFile stamp(QDir(cloudRoot(settingsPath)).filePath(kLastAutoStamp));
    if (!stamp.open(QIODevice::ReadOnly)) {
        return true;
    }
    const qint64 last = stamp.readAll().trimmed().toLongLong();
    const QDateTime changed = lastChange(settingsPath);
    return changed.isValid() && changed.toMSecsSinceEpoch() > last;
}

namespace {
/// The folders that may hold backups, in the order they are looked in
QStringList backupRoots() {
    QStringList roots{backupRootDirectory(), legacyBackupRootDirectory()};
    if (!s_settingsPath.isEmpty()) {
        roots.append(cloudRoot(s_settingsPath));
    }
    return roots;
}
} // namespace

QStringList listBackups() {
    QStringList names;
    for (const auto& rootPath : backupRoots()) {
        const QDir root(rootPath);
        const QStringList dirs = root.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const auto& dir : dirs) {
            // Only folders that contain a database are usable backups (not
            // one being written, ".tmp")
            if (!dir.endsWith(QStringLiteral(".tmp")) && !names.contains(dir) &&
                    QFileInfo::exists(root.filePath(dir + QChar('/') + kDatabaseFileName))) {
                names.append(dir);
            }
        }
    }
    // The names are timestamps, so they sort chronologically
    std::sort(names.begin(), names.end(), std::greater<>());
    return names;
}

QString backupPath(const QString& backupName) {
    if (backupName.isEmpty() || backupName.contains(QChar('/')) ||
            backupName.startsWith(QChar('.'))) {
        return {};
    }
    for (const auto& root : backupRoots()) {
        const QString dir = root + QChar('/') + backupName;
        if (QFileInfo::exists(dir + QChar('/') + kDatabaseFileName)) {
            return dir;
        }
    }
    return {};
}

bool stageRestore(const QString& settingsPath, const QString& backupName, QString* pError) {
    QMutexLocker lock(&s_backupMutex);
    const QString backupDir = backupPath(backupName);
    if (backupDir.isEmpty()) {
        *pError = QCoreApplication::translate("AndroidBackup", "Backup %1 not found").arg(backupName);
        return false;
    }
    const QString pendingDir = settingsPath + QChar('/') + kPendingDirName;
    removePath(pendingDir);
    if (!copyRecursively(backupDir, pendingDir)) {
        *pError = QCoreApplication::translate("AndroidBackup", "Cannot copy backup %1").arg(backupName);
        removePath(pendingDir);
        return false;
    }
    QFile::remove(pendingDir + QChar('/') + kInfoFileName);
    QFile marker(pendingDir + QChar('/') + kCompleteMarker);
    if (!marker.open(QIODevice::WriteOnly)) {
        *pError = QCoreApplication::translate("AndroidBackup", "Cannot copy backup %1").arg(backupName);
        removePath(pendingDir);
        return false;
    }
    qInfo() << "Staged backup" << backupName << "for restoring at the next start";
    return true;
}

void applyPendingRestore(const QString& settingsPath) {
    s_settingsPath = settingsPath;
    const QDir settingsDir(settingsPath);
    const QString pendingDir = settingsDir.filePath(kPendingDirName);
    if (!QFileInfo::exists(pendingDir)) {
        return;
    }
    if (!QFileInfo::exists(pendingDir + QChar('/') + kCompleteMarker)) {
        qWarning() << "Discarding incomplete backup restore in" << pendingDir;
        removePath(pendingDir);
        return;
    }
    QFile::remove(pendingDir + QChar('/') + kCompleteMarker);

    const QString previousDir = settingsDir.filePath(kPreviousDirName);
    removePath(previousDir);
    if (!QDir().mkpath(previousDir)) {
        qWarning() << "Restore: cannot create" << previousDir << ", nothing was restored";
        removePath(pendingDir);
        return;
    }

    // A journal or write-ahead log left over from the replaced database must
    // not be applied to the restored one
    QStringList names = QDir(pendingDir).entryList(QDir::AllEntries | QDir::Hidden | QDir::NoDotAndDotDot);
    names.append(kDatabaseFileName + QStringLiteral("-journal"));
    names.append(kDatabaseFileName + QStringLiteral("-wal"));
    names.append(kDatabaseFileName + QStringLiteral("-shm"));

    // First move the current files away. If one can't be moved, put back
    // the ones already moved and keep the current state: nothing is deleted.
    QStringList movedAway;
    for (const auto& name : std::as_const(names)) {
        const QString target = settingsDir.filePath(name);
        if (!QFileInfo::exists(target)) {
            continue;
        }
        if (!QDir().rename(target, previousDir + QChar('/') + name)) {
            qWarning() << "Restore: cannot move away" << target << ", nothing was restored";
            for (const auto& moved : std::as_const(movedAway)) {
                QDir().rename(previousDir + QChar('/') + moved, settingsDir.filePath(moved));
            }
            removePath(pendingDir);
            return;
        }
        movedAway.append(name);
    }

    // Then move the restored files in. On failure, go back to the previous
    // files.
    QStringList movedIn;
    for (const auto& name : std::as_const(names)) {
        const QString source = pendingDir + QChar('/') + name;
        if (!QFileInfo::exists(source)) {
            continue;
        }
        if (!QDir().rename(source, settingsDir.filePath(name))) {
            qWarning() << "Restore: cannot move" << source << ", going back to the previous files";
            for (const auto& moved : std::as_const(movedIn)) {
                removePath(settingsDir.filePath(moved));
            }
            for (const auto& moved : std::as_const(movedAway)) {
                QDir().rename(previousDir + QChar('/') + moved, settingsDir.filePath(moved));
            }
            removePath(pendingDir);
            return;
        }
        movedIn.append(name);
    }
    keepSubsonicPassword(previousDir + QChar('/') + kConfigFileName,
            settingsDir.filePath(kConfigFileName));
    removePath(pendingDir);
    qInfo() << "Restored a backup, the previous files are in" << previousDir;
}

} // namespace android
} // namespace mixxx
