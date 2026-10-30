#include "qml/qmllibrarysource.h"

#include <qalgorithms.h>
#include <qlist.h>
#include <qqmlengine.h>

#include <QAbstractListModel>
#include <QVariant>
#include <QtDebug>
#include <memory>

#include "library/browse/browsefeature.h"
#include "library/library.h"
#include "library/dao/trackschema.h"
#include "library/librarytablemodel.h"
#include "library/playlisttablemodel.h"
#include "library/trackcollection.h"
#include "library/trackcollectionmanager.h"
#include "library/trackset/crate/cratefeature.h"
#include "library/trackset/crate/cratesummary.h"
#include "library/trackset/playlistfeature.h"
#include "library/treeitemmodel.h"
#include "moc_qmllibrarysource.cpp"
#include "qmllibraryproxy.h"
#include "track/track.h"

AllTrackLibraryFeature::AllTrackLibraryFeature(Library* pLibrary, UserSettingsPointer pConfig)
        : LibraryFeature(pLibrary, pConfig, QStringLiteral("tracks")),
          m_pSidebarModel(make_parented<TreeItemModel>(this)),
          m_pLibraryTableModel(pLibrary->trackTableModel()) {
    m_pSidebarModel->setRootItem(TreeItem::newRoot(this));
}

void AllTrackLibraryFeature::activate() {
    emit showTrackModel(m_pLibraryTableModel);
}

AutoDJQueueLibraryFeature::AutoDJQueueLibraryFeature(
        Library* pLibrary, UserSettingsPointer pConfig)
        : LibraryFeature(pLibrary, pConfig, QStringLiteral("autodj")),
          m_pQueueModel(make_parented<PlaylistTableModel>(this,
                  pLibrary->trackCollectionManager(),
                  "mixxx.db.model.autodj.qml",
                  /*keep hidden tracks*/ true)),
          m_pSidebarModel(make_parented<TreeItemModel>(this)) {
    m_pSidebarModel->setRootItem(TreeItem::newRoot(this));
}

void AutoDJQueueLibraryFeature::activate() {
    PlaylistDAO& playlistDAO =
            m_pLibrary->trackCollectionManager()->internalCollection()->getPlaylistDAO();
    int playlistId = playlistDAO.getPlaylistIdFromName(AUTODJ_TABLE);
    if (playlistId < 0) {
        playlistId = playlistDAO.createPlaylist(AUTODJ_TABLE, PlaylistDAO::PLHT_AUTO_DJ);
    }
    m_pQueueModel->selectPlaylist(playlistId);
    emit showTrackModel(m_pQueueModel);
}

namespace mixxx {
namespace qml {

QmlLibraryAbstractSource::QmlLibraryAbstractSource(
        QObject* parent, const QList<QmlLibraryTrackListColumn*>& columns)
        : QObject(parent),
          m_columns(columns) {
}

void QmlLibraryAbstractSource::slotShowTrackModel(QAbstractItemModel* pModel) {
    emit requestTrackModel(std::make_shared<QmlLibraryTrackListModel>(columns(), pModel));
}

QmlLibraryAllTrackSource::QmlLibraryAllTrackSource(
        QObject* parent, const QList<QmlLibraryTrackListColumn*>& columns)
        : QmlLibraryAbstractSource(parent, columns),
          m_pLibraryFeature(std::make_unique<AllTrackLibraryFeature>(
                  QmlLibraryProxy::get(), QmlConfigProxy::get())) {
    connect(m_pLibraryFeature.get(),
            &LibraryFeature::showTrackModel,
            this,
            &QmlLibraryAbstractSource::slotShowTrackModel);
}

QmlLibraryAutoDJSource::QmlLibraryAutoDJSource(
        QObject* parent, const QList<QmlLibraryTrackListColumn*>& columns)
        : QmlLibraryAbstractSource(parent, columns),
          m_pLibraryFeature(std::make_unique<AutoDJQueueLibraryFeature>(
                  QmlLibraryProxy::get(), QmlConfigProxy::get())) {
    connect(m_pLibraryFeature.get(),
            &LibraryFeature::showTrackModel,
            this,
            &QmlLibraryAbstractSource::slotShowTrackModel);
}

} // namespace qml
} // namespace mixxx
