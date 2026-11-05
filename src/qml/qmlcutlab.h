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
    /// A key press and release on whatever has the focus: lets the browse
    /// knob of a controller move through menus and the settings
    Q_INVOKABLE void sendKey(int key, int modifiers = 0) const;
    /// MicroSD cards and USB drives plugged in: {name, path}
    Q_INVOKABLE QVariantList storageVolumes() const;
    /// Adds one folder to the library (keeping the others) and scans it
    Q_INVOKABLE bool addFolder(const QString& path) const;
    /// Hides the voice notes, recordings and very short files of the library
    Q_INVOKABLE int hideNonMusic() const;
    /// Queues every visible track without BPM or key for the analysis (BPM,
    /// key, waveform), returns how many
    Q_INVOKABLE int analyzeMissing() const;
    /// How many visible tracks still have no BPM or key
    Q_INVOKABLE int missingAnalysis() const;
    /// The key of the track loaded on `group` as text ("8A"), for the
    /// "compatible key" filter of the library
    Q_INVOKABLE QString deckKey(const QString& group) const;
    /// A key written in any notation ("Am", "8A", "1m") as Camelot ("8A"),
    /// empty when it isn't a key
    Q_INVOKABLE QString camelot(const QString& keyText) const;

    /// Where the first beat of the grid of the track on `group` is, in
    /// seconds, -1 without a grid: the beat lights count the bar from it
    Q_INVOKABLE double firstBeat(const QString& group) const;

    /// The Auto DJ queue
    /// How many tracks are waiting in the queue
    Q_INVOKABLE int queueCount() const;
    /// Adds the track at `url` to the end of the queue, or next with `top`
    Q_INVOKABLE bool addToQueue(const QUrl& url, bool top) const;
    /// Adds up to `count` tracks that chain from the end of the queue (or
    /// from the track on `group`): tempo within 8%, a key that mixes, no
    /// artist twice, nothing played in the last hours. Returns how many
    Q_INVOKABLE int fillQueue(const QString& group, int count) const;

    /// Playlists and crates
    /// All of them, the newest playlists first: {kind: "playlist"|"crate",
    /// id, name}
    Q_INVOKABLE QVariantList lists() const;
    /// A new playlist or crate (`kind`), named `name` or a number after it
    /// when the name is taken. Returns its id, -1 on failure
    Q_INVOKABLE int createList(const QString& kind, const QString& name) const;
    /// Adds the track at `url` to a playlist or crate
    Q_INVOKABLE bool addToList(const QString& kind, int id, const QUrl& url) const;

    /// The track on `group` played long enough (30 s): it goes to the
    /// history ("Recientes") and its play count goes up
    Q_INVOKABLE bool markPlayed(const QString& group) const;

  signals:
    /// A library scan is over: the folders and the tracks may have changed
    void libraryScanned();

  private:
    /// Shows the tracks of the chosen folders and hides the rest
    void applyFolderVisibility(const QStringList& paths) const;
};

} // namespace qml
} // namespace mixxx
