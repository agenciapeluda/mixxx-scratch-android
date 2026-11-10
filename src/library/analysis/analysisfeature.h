#pragma once

#include <QList>
#include <QObject>
#include <QUrl>
#include <QVariant>

#include "analyzer/trackanalysisscheduler.h"
#include "library/libraryfeature.h"
#include "library/treeitemmodel.h"
#include "preferences/usersettings.h"
#include "util/parented_ptr.h"

class DlgAnalysis;

class AnalysisFeature : public LibraryFeature {
    Q_OBJECT
  public:
    AnalysisFeature(Library* pLibrary,
                    UserSettingsPointer pConfig);
    ~AnalysisFeature() override;

    QVariant title() override {
        return m_title;
    }

    bool dropAccept(const QList<QUrl>& urls, QObject* pSource) override;
    bool dragMoveAccept(const QList<QUrl>& urls) override;
    void bindLibraryWidget(WLibrary* libraryWidget,
                    KeyboardEventFilter* keyboard) override;

    TreeItemModel* sidebarModel() const override;
    void refreshLibraryModels();

  signals:
    void analysisActive(bool bActive);
    /// Cutlab: tracks done and in all of the batch (0, 0 when it is over)
    void batchProgress(int done, int total);
    void trackProgress(TrackId trackId, AnalyzerProgress progress);

  public slots:
    void activate() override;
    void analyzeTracks(const QList<AnalyzerScheduledTrack>& tracks);

    void suspendAnalysis();
    void resumeAnalysis();
    void stopAnalysis();
    /// Cutlab: held while a deck plays, so the analysis never takes the
    /// CPU the screen and the audio need; it goes on when they stop
    void setHeldForPlay(bool held);

  public:
    bool isHeldForPlay() const {
        return m_heldForPlay;
    }
    bool isBatchActive() const {
        return static_cast<bool>(m_pTrackAnalysisScheduler);
    }

  private slots:
    void onTrackAnalysisSchedulerProgress(AnalyzerProgress currentTrackProgress, int currentTrackNumber, int totalTracksCount);
    void onTrackAnalysisSchedulerFinished();

  private:
    // Sets the title of this feature to the default name, given by
    // m_sAnalysisTitleName
    void resetTitle();

    // Sets the title of this feature to the default name followed by (x / y)
    // where x is the current track being analyzed and y is the total number of
    // tracks in the job
    void setTitleProgress(int currentTrackNumber, int totalTracksCount);

    const QString m_baseTitle;

    TrackAnalysisScheduler::Pointer m_pTrackAnalysisScheduler;

    parented_ptr<TreeItemModel> m_pSidebarModel;
    DlgAnalysis* m_pAnalysisView;

    // The title is dynamic and reflects the current progress
    QString m_title;
    bool m_heldForPlay{false};
};
