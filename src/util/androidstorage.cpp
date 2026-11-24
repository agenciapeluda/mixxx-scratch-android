#include "util/androidstorage.h"

#include <QCoreApplication>
#include <QDir>
#include <QDebug>
#include <QDirIterator>
#include <QJniObject>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

#include "util/androidpermissions.h"

// [AI-generated text, Claude (Anthropic) — start]
// Cutlab 1.32.0: see androidstorage.h
// [AI-generated text, Claude (Anthropic) — end]

namespace mixxx {
namespace android {

namespace {

const QString kInternalStorage = QStringLiteral("/storage/emulated/0");
const QString kMappingsGroup = QStringLiteral("[ControllerPreset]");

/// Moves the files of from (recursively) into to. A file that is already
/// in to is kept there and the old one left in place.
int moveFiles(const QString& from, const QString& to) {
    if (!QFileInfo(from).isDir()) {
        return 0;
    }
    int moved = 0;
    const QDir source(from);
    QDirIterator it(from, QDir::Files | QDir::Hidden, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString path = it.next();
        const QString target = QDir(to).filePath(source.relativeFilePath(path));
        if (QFileInfo::exists(target)) {
            continue;
        }
        QDir().mkpath(QFileInfo(target).absolutePath());
        if (QFile::rename(path, target) ||
                (QFile::copy(path, target) && QFile::remove(path))) {
            ++moved;
        } else {
            qWarning() << "Cutlab storage: could not move" << path << "to" << target;
        }
    }
    return moved;
}

/// Removes the empty folders under path, and path when it ends up empty
void removeEmptyDirectories(const QString& path) {
    QDir dir(path);
    if (!dir.exists()) {
        return;
    }
    const QStringList subdirs = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden);
    for (const QString& subdir : subdirs) {
        removeEmptyDirectories(dir.filePath(subdir));
    }
    if (dir.entryList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden).isEmpty()) {
        dir.rmdir(QStringLiteral("."));
        QDir().rmdir(path);
    }
}

} // namespace

QString appDirectory() {
    static const QString directory = [] {
        QJniObject context = QNativeInterface::QAndroidApplication::context();
        if (context.isValid()) {
            QJniObject dir = context.callObjectMethod("getExternalFilesDir",
                    "(Ljava/lang/String;)Ljava/io/File;",
                    nullptr);
            if (dir.isValid()) {
                const QString path = dir.callObjectMethod("getAbsolutePath",
                                                "()Ljava/lang/String;")
                                             .toString();
                if (!path.isEmpty()) {
                    return path;
                }
            }
        }
        return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    }();
    return directory;
}

QString logsDirectory() {
    return appDirectory() + QStringLiteral("/logs");
}

QString userMappingsDirectory() {
    return appDirectory() + QStringLiteral("/controllers/");
}

QString privateQmlDirectory() {
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) +
            QStringLiteral("/qml");
}

QString legacyPublicDirectory() {
    return kInternalStorage + QStringLiteral("/Mixxx");
}

QString legacyUserMappingsDirectory() {
    return legacyPublicDirectory() + QStringLiteral("/controllers/");
}

QString legacyMusicMappingsDirectory() {
    return QStandardPaths::writableLocation(QStandardPaths::MusicLocation) +
            QStringLiteral("/Mixxx/controllers/");
}

void migrateLegacyPublicDirectory(UserSettingsPointer pConfig) {
    QDir().mkpath(logsDirectory());
    QDir().mkpath(userMappingsDirectory());
    if (!hasFullExternalStorageAccess()) {
        return;
    }

    const QString legacy = legacyPublicDirectory();
    if (!QFileInfo(legacy).isDir() && !QFileInfo(legacyMusicMappingsDirectory()).isDir()) {
        return;
    }

    // The copy of the interface of 1.31 and before, with the images
    if (QDir(legacy + QStringLiteral("/qml")).removeRecursively()) {
        qInfo() << "Cutlab storage: removed the old copy of the interface in" << legacy;
    }

    const int logs = moveFiles(legacy + QStringLiteral("/logs"), logsDirectory());
    const int mappings = moveFiles(legacyUserMappingsDirectory(), userMappingsDirectory()) +
            moveFiles(legacyMusicMappingsDirectory(), userMappingsDirectory());
    if (logs > 0 || mappings > 0) {
        qInfo() << "Cutlab storage: moved" << logs << "logs and" << mappings
                << "mappings to" << appDirectory();
    }

    // A mapping chosen for a controller points to its file: follow the move
    if (pConfig && mappings > 0) {
        for (const ConfigKey& key : pConfig->getKeysWithGroup(kMappingsGroup)) {
            const QString path = pConfig->getValueString(key);
            for (const QString& oldDir : {legacyUserMappingsDirectory(), legacyMusicMappingsDirectory()}) {
                if (path.startsWith(oldDir)) {
                    const QString newPath = userMappingsDirectory() + path.mid(oldDir.size());
                    if (QFileInfo::exists(newPath)) {
                        pConfig->setValue(key, newPath);
                    }
                    break;
                }
            }
        }
    }

    // Mixxx/backup (manual backups up to 1.29) stays where it is, it is
    // still read from there: the folder goes away only when it is empty
    removeEmptyDirectories(legacy + QStringLiteral("/logs"));
    removeEmptyDirectories(legacyUserMappingsDirectory());
    removeEmptyDirectories(legacyMusicMappingsDirectory());
    QDir(legacy).remove(QStringLiteral(".nomedia"));
    removeEmptyDirectories(legacy);
}

} // namespace android
} // namespace mixxx
