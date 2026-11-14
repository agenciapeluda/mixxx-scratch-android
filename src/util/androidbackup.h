#pragma once

#include <QSqlDatabase>
#include <QString>
#include <QStringList>

namespace mixxx {
namespace android {

/// Backups of the library database and the settings on Android, where the
/// settings folder is private to the app and deleted with it.
///
/// A backup is a folder with a copy of the settings folder: the database
/// (BPM, key, cues, loops, letsktch! slots, playlists, crates, history),
/// mixxx.cfg, the other configuration files and the user controller
/// mappings. Waveforms, stems, the stem models and logs are left out.
///
/// Backups are named after the time they were made ("yyyy-MM-dd_HH-mm-ss",
/// with "_auto" for the automatic ones), so the names sort chronologically.
/// They are looked for in three places, in this order:
/// - backupRootDirectory(), Music/Cutlab/backup (from 1.30 on);
/// - legacyBackupRootDirectory(), Mixxx/backup (manual backups up to 1.29);
/// - the snapshot for the Android backup in the settings folder, which
///   Android's Auto Backup brings back when the app is installed again.

/// /storage/emulated/0/Music/Cutlab/backup, kept when the app is uninstalled
QString backupRootDirectory();

/// /storage/emulated/0/Mixxx/backup, where the backups of 1.29 and before are
QString legacyBackupRootDirectory();

/// Writes a new backup. The database is copied with "VACUUM INTO" through
/// the open connection `database`, which gives a consistent copy while
/// Mixxx is running. Returns the folder of the backup, or an empty string
/// and an error message in pError.
QString createBackup(const QString& settingsPath, QSqlDatabase database, QString* pError);

/// The automatic backup: a backup in backupRootDirectory() (only with
/// `sharedStorage`, "All files access" granted) and the snapshot for the
/// Android backup in the settings folder. Only the 3 newest automatic
/// backups are kept, manual ones are never deleted. The database is read
/// through a new connection cloned from `connectionName`, so this can run
/// in any thread. Returns false if nothing could be written.
bool createAutoBackup(const QString& settingsPath,
        const QString& connectionName,
        bool sharedStorage);

/// Whether the library database changed since the last automatic backup
bool changedSinceAutoBackup(const QString& settingsPath);

/// The names of the backup folders, newest first
QStringList listBackups();

/// The folder of the backup `backupName`, or an empty string
QString backupPath(const QString& backupName);

/// Prepares restoring the backup `backupName`. The files can't be replaced
/// while Mixxx uses them, so they are copied next to the settings folder
/// and applyPendingRestore() swaps them in on the next start.
bool stageRestore(const QString& settingsPath, const QString& backupName, QString* pError);

/// Called at startup, before anything reads the settings folder. Replaces
/// its files with a staged backup, if any. The replaced files are kept in
/// the "restore_previous" subfolder until the next restore.
void applyPendingRestore(const QString& settingsPath);

} // namespace android
} // namespace mixxx
