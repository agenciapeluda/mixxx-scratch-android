#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QTimer>
#include <QQmlEngine>
#include <QStringList>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>

class QNetworkAccessManager;

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

    /// The batch analysis: tracks done and in all of it (0 when idle),
    /// whether it waits for the decks to stop, and the tracks that could
    /// not be analyzed
    Q_PROPERTY(int analysisDone READ analysisDone NOTIFY analysisChanged)
    Q_PROPERTY(int analysisTotal READ analysisTotal NOTIFY analysisChanged)
    Q_PROPERTY(bool analysisHeld READ analysisHeld NOTIFY analysisChanged)
    Q_PROPERTY(int analysisFailed READ analysisFailed NOTIFY analysisChanged)
    /// A library scan runs, and how many new tracks it added so far
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanChanged)
    Q_PROPERTY(int scannedTracks READ scannedTracks NOTIFY scanChanged)
    // Cutlab 1.32.0: where a track's genre comes from: 0 automatic (the tag
    // if it is a genre, else the folder), 1 the tag, 2 the folder
    Q_PROPERTY(int genreSource READ genreSource WRITE setGenreSource NOTIFY genreSourceChanged)
    // Cutlab 1.32.0: what the suggestions come from: 0 open format, 1 the
    // same genre, 2 the same folder
    Q_PROPERTY(int suggestFrom READ suggestFrom WRITE setSuggestFrom NOTIFY suggestFromChanged)
    // Cutlab 1.32.0: "Modo show" (org.mixxx.ShowMode): Do Not Disturb,
    // audio focus, screen on, no background work of the app, no internet
    Q_PROPERTY(bool showMode READ showMode WRITE setShowMode NOTIFY showModeChanged)
    // Cutlab 1.32.4: the lyrics of the whole library, fetched in the
    // background one per second while nothing plays and the show mode is
    // off; `lyricsBatchState`: "off", "running", "playing", "show",
    // "wifi" (waiting for Wi-Fi), "done"
    Q_PROPERTY(bool lyricsBatch READ lyricsBatch WRITE setLyricsBatch NOTIFY lyricsBatchChanged)
    Q_PROPERTY(bool lyricsWifiOnly READ lyricsWifiOnly WRITE setLyricsWifiOnly NOTIFY lyricsBatchChanged)
    Q_PROPERTY(QString lyricsBatchState READ lyricsBatchState NOTIFY lyricsBatchChanged)
    Q_PROPERTY(int lyricsBatchDone READ lyricsBatchDone NOTIFY lyricsBatchChanged)
    Q_PROPERTY(int lyricsBatchTotal READ lyricsBatchTotal NOTIFY lyricsBatchChanged)
    Q_PROPERTY(int lyricsBatchFound READ lyricsBatchFound NOTIFY lyricsBatchChanged)

  public:
    explicit QmlCutlab(QObject* pParent = nullptr);

    bool lyricsBatch() const;
    void setLyricsBatch(bool on);
    bool lyricsWifiOnly() const;
    void setLyricsWifiOnly(bool on);
    QString lyricsBatchState() const {
        return m_lyricsState;
    }
    int lyricsBatchDone() const {
        return m_lyricsDone;
    }
    int lyricsBatchTotal() const {
        return m_lyricsTotal;
    }
    int lyricsBatchFound() const {
        return m_lyricsFound;
    }

    int analysisDone() const;
    int analysisTotal() const;
    bool analysisHeld() const;
    int analysisFailed() const;
    bool scanning() const;
    int scannedTracks() const;
    /// While a deck plays the analysis waits (the screen and the audio
    /// keep the CPU); it goes on once they stop
    Q_INVOKABLE void setAnalysisHeld(bool held);
    /// Measures each frame of `window` (a QQuickWindow): the time the GUI
    /// thread is blocked syncing, the time to record the frame, the time
    /// to present it, and how late the GUI thread answers; frameStats() once
    /// a second, also written to the log
    Q_INVOKABLE void watchFrames(QObject* window, bool on);
    /// The screen on show ("Onda", "Dial", "Biblioteca", "Pads"...): the
    /// frame times are kept per screen (frameStats().screens)
    Q_INVOKABLE void setScreen(const QString& name);
    /// "Capturar" with passthrough on: the last `seconds` of what the
    /// turntable of `group` played are written as a WAV in Music/Cutlab/
    /// Capturas (in a worker thread). With `bpm` > 0 the track gets a
    /// locked beat grid at that tempo from its first frame, so its loop of
    /// `beats` beats stays in time. captureFinished() with the file, or
    /// with the error.
    Q_INVOKABLE void captureInput(const QString& group, double seconds, double bpm, int beats);
    /// Opens the share sheet with the log of this run, the one before and
    /// the crash reports
    Q_INVOKABLE bool shareLog() const;
    /// Cutlab 1.32.2: true when a crash report newer than the last one
    /// seen is there (the app closed by itself last time)
    Q_INVOKABLE bool hasNewCrash() const;
    Q_INVOKABLE void markCrashSeen() const;
    /// Cutlab 1.32.2: the headphones connected now ("" none), to notice
    /// them plugged in or out while the app runs
    Q_INVOKABLE QString headphoneOutputs() const;
    /// Cutlab 1.32.2: saves and opens the app again (the outputs are read
    /// when it starts)
    Q_INVOKABLE void restartApp() const;
    /// Cutlab 1.32.3: deletes the file of the track at `url` from the phone
    /// and takes it out of the library and its lists. "" when done, else
    /// why not (loaded on a deck, no access, the file can't be deleted).
    Q_INVOKABLE QString deleteTrackFile(const QUrl& url) const;

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
    /// Cutlab 1.32.0: the folders right inside `path` that hold tracks of
    /// the library (also deeper down), A-Z: {name, path, count}
    Q_INVOKABLE QVariantList subFolders(const QString& path) const;
    /// The genres of the library, most tracks first:
    /// {name, count, filter, subgenres: [{name, count, filter}]}; the
    /// tracks without a genre last, with an empty name. `filter` is the
    /// search that lists the tracks.
    Q_INVOKABLE QVariantList genres() const;
    int genreSource() const;
    void setGenreSource(int source);
    int suggestFrom() const;
    void setSuggestFrom(int from);
    bool showMode() const;
    void setShowMode(bool on);
    /// What the show mode can't do on its own: {dnd, battery} granted
    Q_INVOKABLE QVariantMap showModeAccess() const;
    Q_INVOKABLE void openDndAccess() const;
    Q_INVOKABLE void requestBatteryExemption() const;
    Q_INVOKABLE void openInternetPanel() const;
    Q_INVOKABLE void openBluetoothSettings() const;

    /// Cutlab 1.32.0: the lyrics of the track on `group`, answered with
    /// lyricsReady(): an .lrc next to the file, the ones saved before, else
    /// LRCLIB (lrclib.net) when there is internet and the show mode is off
    Q_INVOKABLE void fetchLyrics(const QString& group);
    /// Tracks that suit the one loaded on `group`, best first:
    /// {url, title, artist, bpm, key, why}
    Q_INVOKABLE QVariantList suggestions(const QString& group, int limit) const;
    /// Names of the playlists and crates holding the track at `url`
    Q_INVOKABLE QStringList listsContaining(const QUrl& url) const;
    /// Folders of the phone with music files: {name, path, count}
    Q_INVOKABLE QVariantList candidateFolders() const;
    /// candidateFolders() in a worker thread (walking the storage takes
    /// seconds): candidateFoldersFound() with the list
    Q_INVOKABLE void findCandidateFolders();
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
    /// Cutlab 1.32.4: puts the tracks of `folder` (also its subfolders) in
    /// the Auto DJ queue, from the slowest BPM to the fastest, the tracks
    /// without a BPM last and the same artist never twice in a row. Skips
    /// what is queued or loaded. `replace` empties the queue first; without
    /// it, the tracks go after the queue, the ones from the BPM of its last
    /// track up first. Returns how many were added.
    Q_INVOKABLE int fillQueueFromFolder(const QString& folder, bool replace) const;

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
    void genreSourceChanged();
    void showModeChanged();
    /// lines: [{time (s, -1 without times), text}]; source: "file",
    /// "saved", "lrclib", or "" when there are none (status says why:
    /// "none", "offline", "error")
    void lyricsReady(const QString& group,
            const QString& location,
            const QVariantList& lines,
            bool synced,
            const QString& source,
            const QString& status);
    void suggestFromChanged();
    void lyricsBatchChanged();
    /// A library scan is over: the folders and the tracks may have changed
    void libraryScanned();
    void analysisChanged();
    void scanChanged();
    /// While a scan runs, every 2 s if it added tracks: the lists can show them
    void libraryGrew();
    void candidateFoldersFound(const QVariantList& folders);
    void captureFinished(const QString& group,
            const QString& path,
            double bpm,
            int beats,
            double seconds,
            const QString& error);
    void frameStats(const QVariantMap& stats);

  private:
    QNetworkAccessManager* m_pNetwork = nullptr;
    struct LyricsJob {
        QString location;
        QString artist;
        QString title;
        double duration;
    };
    QList<LyricsJob> m_lyricsJobs;
    QTimer m_lyricsTick;
    bool m_lyricsBusy = false;
    QString m_lyricsState = QStringLiteral("off");
    int m_lyricsDone = 0;
    int m_lyricsTotal = 0;
    int m_lyricsFound = 0;
    void startLyricsBatch();
    void lyricsTick();
    void setLyricsState(const QString& state);
    QTimer m_scanTick;
    QElapsedTimer m_sinceGrow;
    /// The batch is over: marks the tracks it could not analyze
    void markFailedAnalysis() const;
    /// Shows the tracks of the chosen folders and hides the rest
    void applyFolderVisibility(const QStringList& paths) const;
};

} // namespace qml
} // namespace mixxx
