#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QStringList>
#include <QUrl>
#include <QVariantList>

namespace mixxx {
namespace qml {

/// The library and track helpers of the Cutlab layout, exposed as the
/// `Mixxx.Cutlab` singleton:
/// - the structure of the loaded track (intro, breaks, pauses, drops)
///   from its waveform summary and beat grid
/// - the music folders and genres of the library, to browse them like crates
/// - the tracks that suit the one playing on a deck
/// - the playlists and crates a track is in
/// - the folders of the phone that hold music, for the first start
class QmlCutlab : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(Cutlab)
    QML_SINGLETON

  public:
    explicit QmlCutlab(QObject* pParent = nullptr);

    static QmlCutlab* create(QQmlEngine* pQmlEngine, QJSEngine* pJsEngine);

    /// The control objects the controller mappings use to fire the one shot
    /// effects of the Cutlab layout ([Cutlab] fx_deck1..4). Created at start,
    /// before the mappings.
    static void createControls();

    /// Sections of the track loaded on `group`, as a list of
    /// {type: "intro"|"break"|"pause"|"drop"|"outro", start, end} where start
    /// and end are positions from 0 to 1 snapped to the bars of the beat grid
    Q_INVOKABLE QVariantList sections(const QString& group) const;

    /// The folders of the library, one per subfolder of the music folders:
    /// {name, path, count, root}
    Q_INVOKABLE QVariantList musicFolders() const;
    /// The genres of the library with their track count: {name, count}
    Q_INVOKABLE QVariantList genres() const;
    /// Tracks that suit the one loaded on `group`, best first:
    /// {url, title, artist, bpm, key, why}
    Q_INVOKABLE QVariantList suggestions(const QString& group, int limit) const;
    /// Names of the playlists and crates holding the track at `url`
    Q_INVOKABLE QStringList listsContaining(const QUrl& url) const;
    /// Folders of the phone with music files: {name, path, count}
    Q_INVOKABLE QVariantList candidateFolders() const;
    /// The music folders of the library are exactly `paths`: the old ones are
    /// replaced, the tracks outside are hidden, the ones inside shown again
    /// (except voice notes and recordings), then the library is scanned
    Q_INVOKABLE bool useFolders(const QStringList& paths) const;
    /// The music folders of the library
    Q_INVOKABLE QStringList folders() const;
    /// Hides the voice notes, recordings and very short files of the library
    Q_INVOKABLE int hideNonMusic() const;
};

} // namespace qml
} // namespace mixxx
