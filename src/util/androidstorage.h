#pragma once

#include <QString>

#include "preferences/usersettings.h"

namespace mixxx {
namespace android {

// [AI-generated text, Claude (Anthropic) — start]
/// Where Cutlab keeps files on Android (Cutlab 1.32.0).
///
/// Up to 1.31 the app wrote /storage/emulated/0/Mixxx: on every start a copy
/// of its whole interface (qml/, with the PNG images of Mixxx: a Qt logo,
/// a Traktor S4...), the crash reports (logs/) and the user mappings
/// (controllers/). Being shared storage, it stayed after uninstalling, the
/// gallery and the share sheets of other apps (WhatsApp) showed its images,
/// and the name said Mixxx, not Cutlab.
///
/// Now nothing of the app is left in shared storage:
/// - the copy of the interface goes to the private folder of the app
///   (privateQmlDirectory());
/// - logs and user mappings go to the folder of the app in external storage
///   (Android/data/<package>/files): other apps can't read it, the gallery
///   doesn't index it, Android deletes it with the app, and it can still be
///   reached from a computer over USB;
/// - only the backups of the library stay outside, in Music/Cutlab/backup,
///   on purpose: they are there to restore after reinstalling.
/// [AI-generated text, Claude (Anthropic) — end]

/// The folder of the app in external storage,
/// /storage/emulated/0/Android/data/<package>/files (the private folder of
/// the app if Android gives none)
QString appDirectory();

/// appDirectory()/logs: crash reports and the previous log
QString logsDirectory();

/// appDirectory()/controllers/ (with the trailing slash)
QString userMappingsDirectory();

/// The private copy of the QML interface (<files of the app>/qml)
QString privateQmlDirectory();

/// The folders of 1.31 and before, still read for what was not moved
QString legacyPublicDirectory();          // /storage/emulated/0/Mixxx
QString legacyUserMappingsDirectory();    // /storage/emulated/0/Mixxx/controllers/
QString legacyMusicMappingsDirectory();   // <Music>/Mixxx/controllers/

/// Once per start, with all files access: deletes the old copy of the
/// interface (Mixxx/qml), moves logs and user mappings from Mixxx to
/// appDirectory() (and the mappings chosen for a controller in the settings
/// with them) and deletes Mixxx if nothing else is left.
void migrateLegacyPublicDirectory(UserSettingsPointer pConfig);

} // namespace android
} // namespace mixxx
