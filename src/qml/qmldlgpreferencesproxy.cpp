#include "qmldlgpreferencesproxy.h"

#include <QDialog>

#include "moc_qmldlgpreferencesproxy.cpp"
#include "util/assert.h"

namespace mixxx {
namespace qml {

QmlDlgPreferencesProxy::QmlDlgPreferencesProxy(
        std::shared_ptr<QDialog> pDlgPreferences,
        QObject* parent)
        : QObject(parent),
          m_pDlgPreferences(pDlgPreferences) {
}

#if defined(Q_OS_ANDROID)
namespace {
// Cutlab: the complete preferences in the look of the touch interface:
// neutral grays, the Cutlab indigo and rows big enough for a finger
const char* kCutlabPreferencesStyle = R"(
QDialog, QWidget { background-color: #1c1c1e; color: #ffffff; font-family: "Roboto"; font-size: 15px; }
QTreeWidget, QTreeView, QListView, QListWidget { background-color: #141415; border: none; outline: none; font-size: 16px; }
QTreeView::item, QListView::item { min-height: 44px; padding: 2px 8px; border-radius: 8px; }
QTreeView::item:selected, QListView::item:selected { background-color: #2b2766; color: #ffffff; }
QGroupBox { background-color: #2b2b2d; border: 1px solid #3a3a3d; border-radius: 12px; margin-top: 22px; padding: 14px 10px 10px 10px; }
QGroupBox::title { subcontrol-origin: margin; left: 12px; padding: 0 4px; color: #8b85ff; font-weight: 500; }
QLabel { background: transparent; color: #e5e5ea; }
QPushButton { background-color: #262628; color: #ffffff; border: 1px solid #4a4a4d; border-radius: 10px; min-height: 40px; padding: 0 16px; }
QPushButton:pressed { background-color: #47474a; }
QPushButton:default, QPushButton:checked { background-color: #635bff; border-color: #635bff; }
QPushButton:disabled { color: #6c6c72; border-color: #333336; }
QComboBox, QLineEdit, QSpinBox, QDoubleSpinBox { background-color: #262628; color: #ffffff; border: 1px solid #4a4a4d; border-radius: 10px; min-height: 40px; padding: 0 12px; selection-background-color: #635bff; }
QComboBox:focus, QLineEdit:focus, QSpinBox:focus, QDoubleSpinBox:focus { border-color: #635bff; }
QComboBox::drop-down { border: none; width: 30px; }
QComboBox QAbstractItemView { background-color: #2c2c2e; color: #ffffff; border: 1px solid #3e3e41; selection-background-color: #3a3a3d; outline: none; }
QComboBox QAbstractItemView::item { min-height: 44px; }
QSpinBox::up-button, QSpinBox::down-button, QDoubleSpinBox::up-button, QDoubleSpinBox::down-button { width: 28px; border: none; }
QCheckBox, QRadioButton { spacing: 10px; background: transparent; min-height: 36px; }
QCheckBox::indicator, QRadioButton::indicator { width: 24px; height: 24px; }
QCheckBox::indicator { border: 2px solid #6c6c72; border-radius: 6px; background: #1c1c1e; }
QCheckBox::indicator:checked { border-color: #635bff; background: #635bff; }
QRadioButton::indicator { border: 2px solid #6c6c72; border-radius: 12px; background: #1c1c1e; }
QRadioButton::indicator:checked { border: 7px solid #635bff; background: #ffffff; }
QSlider::groove:horizontal { height: 6px; background: #1e1e20; border-radius: 3px; }
QSlider::sub-page:horizontal { background: #635bff; border-radius: 3px; }
QSlider::handle:horizontal { background: #e5e5ea; width: 26px; height: 26px; margin: -10px 0; border-radius: 13px; }
QSlider::groove:vertical { width: 6px; background: #1e1e20; border-radius: 3px; }
QSlider::handle:vertical { background: #e5e5ea; width: 26px; height: 26px; margin: 0 -10px; border-radius: 13px; }
QTabWidget::pane { border: 1px solid #3a3a3d; border-radius: 12px; background: #2b2b2d; top: -1px; }
QTabBar::tab { background: transparent; color: #9d9da3; min-height: 40px; padding: 0 18px; border: none; border-bottom: 3px solid transparent; }
QTabBar::tab:selected { color: #8b85ff; border-bottom: 3px solid #635bff; }
QScrollArea, QScrollArea > QWidget > QWidget { background: #1c1c1e; border: none; }
QScrollBar:vertical { background: transparent; width: 8px; margin: 0; }
QScrollBar::handle:vertical { background: #4a4a4d; border-radius: 4px; min-height: 40px; }
QScrollBar:horizontal { background: transparent; height: 8px; margin: 0; }
QScrollBar::handle:horizontal { background: #4a4a4d; border-radius: 4px; min-width: 40px; }
QScrollBar::add-line, QScrollBar::sub-line { width: 0; height: 0; }
QTableView, QTableWidget { background-color: #141415; gridline-color: #2a2a2c; alternate-background-color: #1a1a1b; selection-background-color: #2b2766; }
QHeaderView::section { background-color: #262628; color: #9d9da3; border: none; padding: 8px; }
QToolTip { background-color: #2c2c2e; color: #ffffff; border: 1px solid #3e3e41; }
QDialogButtonBox QPushButton { min-width: 110px; }
)";
} // namespace
#endif

void QmlDlgPreferencesProxy::show() {
#if defined(Q_OS_ANDROID)
    // Full screen and in the Cutlab look, set once
    if (m_pDlgPreferences->styleSheet().isEmpty()) {
        m_pDlgPreferences->setStyleSheet(QString::fromUtf8(kCutlabPreferencesStyle));
    }
    m_pDlgPreferences->showMaximized();
#else
    m_pDlgPreferences->show();
#endif
}

// static
QmlDlgPreferencesProxy* QmlDlgPreferencesProxy::create(
        QQmlEngine* pQmlEngine,
        QJSEngine* pJsEngine) {
    Q_UNUSED(pQmlEngine);

    // The implementation of this method is mostly taken from the code example
    // that shows the replacement for `qmlRegisterSingletonInstance()` when
    // using `QML_SINGLETON`.
    // https://doc.qt.io/qt-6/qqmlengine.html#QML_SINGLETON

    // The instance has to exist before it is used. We cannot replace it.
    DEBUG_ASSERT(s_pInstance);

    // The engine has to have the same thread affinity as the singleton.
    DEBUG_ASSERT(pJsEngine->thread() == s_pInstance->thread());

    // There can only be one engine accessing the singleton.
    if (s_pJsEngine) {
        DEBUG_ASSERT(pJsEngine == s_pJsEngine);
    } else {
        s_pJsEngine = pJsEngine;
    }

    // Explicitly specify C++ ownership so that the engine doesn't delete
    // the instance.
    QJSEngine::setObjectOwnership(s_pInstance.get(), QJSEngine::CppOwnership);
    return s_pInstance.get();
}

} // namespace qml
} // namespace mixxx
