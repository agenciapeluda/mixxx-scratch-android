#include "qmlsoundmanagerproxy.h"

#include <qqmlengine.h>

#include <QClipboard>
#include <algorithm>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QTextStream>

#include <memory>
#include <utility>

#include "moc_qmlsoundmanagerproxy.cpp"
#include "qml/qmlconfigproxy.h"
#include "qml_owned_ptr.h"
#include "soundio/soundmanager.h"
#include "soundio/soundmanagerutil.h"
#include "control/controlobject.h"
#include "util/assert.h"
#include "util/cmdlineargs.h"
#include "util/scopedoverridecursor.h"

namespace mixxx {
namespace qml {

namespace {
const QString kAppGroup = QStringLiteral("[App]");
const ConfigKey kKeylockEngineCfgkey =
        ConfigKey(kAppGroup, QStringLiteral("keylock_engine"));

} // namespace

uint QmlSoundInputDeviceProxy::getChannelCount() const {
    return m_pInternal->getNumInputChannels();
}
uint QmlSoundOutputDeviceProxy::getChannelCount() const {
    return m_pInternal->getNumOutputChannels();
}
SoundDeviceId QmlSoundDeviceProxy::getDeviceId() const {
    return m_pInternal->getDeviceId();
}

QmlSoundDeviceConnectionList QmlSoundInputDeviceProxy::connections(
        mixxx::qml::QmlSoundManagerProxy* manager) {
    DEBUG_ASSERT(qml_owned_ptr<mixxx::qml::QmlSoundManagerProxy>(manager));
    QmlSoundDeviceConnectionList connections;

    auto pManager = manager->internal();
    auto config = pManager->getConfig();

    const auto inputDeviceMap = config.getInputs();
    for (auto it = inputDeviceMap.cbegin(); it != inputDeviceMap.cend(); ++it) {
        if (it.key() == getDeviceId()) {
            connections.push_back(make_qml_owned<QmlSoundDeviceConnection>(
                    std::make_unique<AudioInput>(it.value()), this));
        }
    }
    return connections;
}

QmlSoundDeviceConnectionList QmlSoundOutputDeviceProxy::connections(
        mixxx::qml::QmlSoundManagerProxy* manager) {
    DEBUG_ASSERT(qml_owned_ptr<mixxx::qml::QmlSoundManagerProxy>(manager));
    QmlSoundDeviceConnectionList connections;

    auto pManager = manager->internal();
    auto config = pManager->getConfig();
    const auto ouputDeviceMap = config.getOutputs();
    for (auto it = ouputDeviceMap.cbegin(); it != ouputDeviceMap.cend(); ++it) {
        if (it.key() == getDeviceId()) {
            connections.push_back(make_qml_owned<QmlSoundDeviceConnection>(
                    std::make_unique<AudioOutput>(it.value()), this));
        }
    }
    return connections;
}

int QmlSoundDeviceConnection::getType() const {
    return static_cast<int>(m_audioPath->getType());
}

uchar QmlSoundDeviceConnection::getChannelGroup() const {
    auto group = m_audioPath->getChannelGroup();
    return group.getChannelBase();
}
uchar QmlSoundDeviceConnection::getIndex() const {
    return m_audioPath->getIndex();
}

QmlSoundManagerProxy::QmlSoundManagerProxy(
        std::shared_ptr<SoundManager> pSoundManager,
        QObject* parent)
        : QObject(parent),
          m_pSoundManager(pSoundManager),
          m_keylockEngine(kKeylockEngineCfgkey),
          m_config(m_pSoundManager->getConfig()) {
    connect(m_pSoundManager.get(), &SoundManager::devicesClosed, this, [this]() {
        SoundDeviceStatus status = SoundDeviceStatus::Ok;
        {
            ScopedWaitCursor cursor;

            if (m_commitInProgress.fetchAndStoreRelease(0) != 1) {
                return;
            }

            status = m_pSoundManager->setConfig(m_config);
        }
        if (status != SoundDeviceStatus::Ok) {
            m_lastError = m_pSoundManager->getLastErrorMessage(status);
            emit committed(m_lastError);
        } else {
            m_lastError.clear();
            emit committed();
        }
        m_config = m_pSoundManager->getConfig();
    });
}

void QmlSoundManagerProxy::reload() {
    m_config = m_pSoundManager->getConfig();
}

// static
QmlSoundManagerProxy* QmlSoundManagerProxy::create(
        QQmlEngine* pQmlEngine,
        QJSEngine*) {
    // The instance has to exist before it is used. We cannot replace it.
    VERIFY_OR_DEBUG_ASSERT(s_pSoundManager) {
        qWarning() << "SoundManager hasn't been registered yet";
        return nullptr;
    }
    return make_qml_owned<QmlSoundManagerProxy>(s_pSoundManager, pQmlEngine);
}

QList<QString> QmlSoundManagerProxy::getHostAPIList() const {
    return m_pSoundManager->getHostAPIList();
}

QmlSoundDeviceProxyList QmlSoundManagerProxy::availableInputDevices(const QString& filterAPI) {
    QmlSoundDeviceProxyList devicesQml;
    const QList<SoundDevicePointer> devices =
            m_pSoundManager->getDeviceList(filterAPI, false, true);
    for (const auto& device : devices) {
        devicesQml.push_back(make_qml_owned<QmlSoundInputDeviceProxy>(device, this));
    }
    return devicesQml;
}

QmlSoundDeviceProxyList QmlSoundManagerProxy::availableOutputDevices(const QString& filterAPI) {
    QmlSoundDeviceProxyList devicesQml;
    const QList<SoundDevicePointer> devices =
            m_pSoundManager->getDeviceList(filterAPI, true, false);
    for (const auto& device : devices) {
        devicesQml.push_back(make_qml_owned<QmlSoundOutputDeviceProxy>(device, this));
    }
    return devicesQml;
}

QList<EngineBuffer::KeylockEngine> QmlSoundManagerProxy::getKeylockEngines() const {
    QList<EngineBuffer::KeylockEngine> list;
    for (const auto engine : EngineBuffer::kKeylockEngines) {
        if (EngineBuffer::isKeylockEngineAvailable(engine)) {
            list.append(engine);
        }
    }
    return list;
}

void QmlSoundManagerProxy::setKeylockEngine(EngineBuffer::KeylockEngine keylockEngine) {
    m_keylockEngine.set(static_cast<double>(keylockEngine));
    m_pSoundManager->userSettings()->setValue(kKeylockEngineCfgkey, keylockEngine);
}

EngineBuffer::KeylockEngine QmlSoundManagerProxy::getKeylockEngine() const {
    return m_pSoundManager->userSettings()
            ->getValue<EngineBuffer::KeylockEngine>(
                    kKeylockEngineCfgkey, EngineBuffer::defaultKeylockEngine());
}

QString QmlSoundManagerProxy::getAPI() const {
    return m_config.getAPI();
}
void QmlSoundManagerProxy::setAPI(const QString& api) {
    m_config.setAPI(api);
}

unsigned int QmlSoundManagerProxy::getSyncBuffers() const {
    return m_config.getSyncBuffers();
}

void QmlSoundManagerProxy::setSyncBuffers(unsigned int syncBuffers) {
    m_config.setSyncBuffers(syncBuffers);
}

uint32_t QmlSoundManagerProxy::getSampleRate() const {
    return m_config.getSampleRate();
}

void QmlSoundManagerProxy::setSampleRate(uint32_t sampleRate) {
    m_config.setSampleRate(mixxx::audio::SampleRate(sampleRate));
}

QList<uint32_t> QmlSoundManagerProxy::getSampleRates(const QString& filterAPI) const {
    QList<uint32_t> sampleRatesU32;
    const QList<mixxx::audio::SampleRate> sampleRates = m_pSoundManager->getSampleRates(filterAPI);
    for (const auto& sampleRate : sampleRates) {
        if (sampleRate.isValid()) {
            sampleRatesU32.append(sampleRate);
        }
    }
    return sampleRatesU32;
}

bool QmlSoundManagerProxy::getForceNetworkClock() const {
    return m_config.getForceNetworkClock();
}

void QmlSoundManagerProxy::setForceNetworkClock(bool force) {
    m_config.setForceNetworkClock(force);
}

unsigned int QmlSoundManagerProxy::getAudioBufferSizeIndex() const {
    return m_config.getAudioBufferSizeIndex();
}

void QmlSoundManagerProxy::setAudioBufferSizeIndex(unsigned int latency) {
    m_config.setAudioBufferSizeIndex(latency);
}

void QmlSoundManagerProxy::addOutput(QmlSoundOutputDeviceProxy* device,
        int type,
        unsigned char channelGroup,
        unsigned char index) {
    VERIFY_OR_DEBUG_ASSERT(device && qml_owned_ptr<QmlSoundOutputDeviceProxy>(device)) {
        return;
    }
    m_config.addOutput(device->getDeviceId(),
            AudioOutput(static_cast<AudioPathType>(type),
                    channelGroup,
                    mixxx::audio::ChannelCount::stereo(),
                    index));
}

void QmlSoundManagerProxy::addInput(QmlSoundInputDeviceProxy* device,
        int type,
        unsigned char channelGroup,
        unsigned char index) {
    VERIFY_OR_DEBUG_ASSERT(device && qml_owned_ptr<QmlSoundInputDeviceProxy>(device)) {
        return;
    }
    m_config.addInput(device->getDeviceId(),
            AudioInput(static_cast<AudioPathType>(type),
                    channelGroup,
                    mixxx::audio::ChannelCount::stereo(),
                    index));
}

void QmlSoundManagerProxy::setVinylControlInput(QmlSoundInputDeviceProxy* device,
        unsigned char channelGroup,
        unsigned char index) {
    m_config = m_pSoundManager->getConfig();
    auto& inputs = m_config.getInputsRef();
    for (auto it = inputs.begin(); it != inputs.end();) {
        if (it.value().getType() == AudioPathType::VinylControl &&
                it.value().getIndex() == index) {
            it = inputs.erase(it);
        } else {
            ++it;
        }
    }
    // Two outputs on the same channels of a device make the whole
    // configuration fail ("Two outputs cannot share channels..."), and then
    // the vinyl control input is not applied either. Keep the main output
    // and drop the clashing ones (e.g. headphones on the phone speaker).
    removeClashingOutputs();
    if (!device) {
        // "No input": forget the input kept for USB cards that appear late
        if (const UserSettingsPointer pSettings = QmlConfigProxy::get()) {
            pSettings->setValue(ConfigKey(QStringLiteral("[Cutlab]"),
                                        QStringLiteral("vinyl_input_%1").arg(index + 1)),
                    QString());
        }
    }
    if (device && qml_owned_ptr<QmlSoundInputDeviceProxy>(device)) {
        m_config.addInput(device->getDeviceId(),
                AudioInput(AudioPathType::VinylControl,
                        channelGroup,
                        mixxx::audio::ChannelCount::stereo(),
                        index));
    }
    commit();
}

void QmlSoundManagerProxy::removeClashingOutputs() {
    auto& outputs = m_config.getOutputsRef();
    QList<QPair<SoundDeviceId, AudioOutput>> kept;
    // Main first, so it wins over headphones, booth...
    QList<QPair<SoundDeviceId, AudioOutput>> ordered;
    for (auto it = outputs.cbegin(); it != outputs.cend(); ++it) {
        if (it.value().getType() == AudioPathType::Main) {
            ordered.prepend(qMakePair(it.key(), it.value()));
        } else {
            ordered.append(qMakePair(it.key(), it.value()));
        }
    }
    for (const auto& candidate : std::as_const(ordered)) {
        bool clashes = false;
        for (const auto& existing : std::as_const(kept)) {
            if (existing.first == candidate.first &&
                    existing.second.getChannelGroup().clashesWith(
                            candidate.second.getChannelGroup())) {
                clashes = true;
                break;
            }
        }
        if (clashes) {
            qWarning() << "Dropping output"
                       << AudioPath::getStringFromType(candidate.second.getType())
                       << "that shares channels with another output on"
                       << candidate.first.name;
        } else {
            kept.append(candidate);
        }
    }
    outputs.clear();
    for (const auto& output : std::as_const(kept)) {
        outputs.insert(output.first, output.second);
    }
}

void QmlSoundManagerProxy::useAndroidAudioForUsbDevices() {
    const UserSettingsPointer pConfig = QmlConfigProxy::get();
    if (pConfig) {
        // 1 = always use the USB driver of Cutlab for USB sound cards: it
        // reads their inputs directly (Android often hides multichannel
        // USB inputs)
        pConfig->setValue(ConfigKey(QStringLiteral("[Soundcard]"), QStringLiteral("AndroidUsbDirectMode")), 1);
    }
    // List the USB sound cards again, now through Android audio
    m_pSoundManager->clearAndQueryDevices();
    m_config = m_pSoundManager->getConfig();
    removeClashingOutputs();
    commit();
}

QString QmlSoundManagerProxy::vinylControlInputName(unsigned char index) const {
    const auto inputs = m_pSoundManager->getConfig().getInputs();
    for (auto it = inputs.cbegin(); it != inputs.cend(); ++it) {
        if (it.value().getType() == AudioPathType::VinylControl &&
                it.value().getIndex() == index) {
            return it.key().name;
        }
    }
    return QString();
}

int QmlSoundManagerProxy::vinylControlInputChannelGroup(unsigned char index) const {
    const auto inputs = m_pSoundManager->getConfig().getInputs();
    for (auto it = inputs.cbegin(); it != inputs.cend(); ++it) {
        if (it.value().getType() == AudioPathType::VinylControl &&
                it.value().getIndex() == index) {
            return it.value().getChannelGroup().getChannelBase();
        }
    }
    return -1;
}

void QmlSoundManagerProxy::clearOutputs() {
    m_config.clearOutputs();
}

void QmlSoundManagerProxy::clearInputs() {
    m_config.clearInputs();
}

bool QmlSoundManagerProxy::hasMicInputs() {
    return m_config.hasMicInputs();
}

std::shared_ptr<SoundManager> QmlSoundManagerProxy::internal() const {
    return m_pSoundManager;
}

void QmlSoundManagerProxy::reapply() {
    m_config = m_pSoundManager->getConfig();
    commit();
}

QString QmlSoundManagerProxy::diagnostics() const {
    QString text;
    QTextStream out(&text);
    const SoundManagerConfig config = m_pSoundManager->getConfig();
    out << "== Cutlab sound diagnostics ==\n";
    out << "API: " << config.getAPI() << ", " << config.getSampleRate().value()
        << " Hz, buffer " << config.getFramesPerBuffer() << " frames\n";
    out << "Last error: " << (m_lastError.isEmpty() ? QStringLiteral("none") : m_lastError) << "\n";
    out << "-- Devices --\n";
    const auto devices = m_pSoundManager->getDeviceList(QString(), false, false);
    for (const auto& pDevice : devices) {
        out << pDevice->getDisplayName() << " [" << pDevice->getHostAPI() << "] in "
            << static_cast<int>(pDevice->getNumInputChannels()) << " out "
            << static_cast<int>(pDevice->getNumOutputChannels())
            << (pDevice->isOpen() ? " OPEN" : "") << "\n";
    }
    out << "-- Outputs --\n";
    const auto outputs = config.getOutputs();
    for (auto it = outputs.cbegin(); it != outputs.cend(); ++it) {
        out << it.value().getString() << " ch " << it.value().getChannelGroup().getChannelBase() + 1
            << " -> " << it.key().name << "\n";
    }
    out << "-- Inputs --\n";
    const auto inputs = config.getInputs();
    for (auto it = inputs.cbegin(); it != inputs.cend(); ++it) {
        out << it.value().getString() << " ch " << it.value().getChannelGroup().getChannelBase() + 1
            << " <- " << it.key().name << "\n";
    }
    out << "-- Decks --\n";
    for (int i = 1; i <= 2; ++i) {
        const QString group = QStringLiteral("[Channel%1]").arg(i);
        out << group << " input_configured " << ControlObject::get(ConfigKey(group, QStringLiteral("input_configured")))
            << " vinyl_enabled " << ControlObject::get(ConfigKey(group, QStringLiteral("vinylcontrol_enabled")))
            << " vinyl_status " << ControlObject::get(ConfigKey(group, QStringLiteral("vinylcontrol_status")))
            << " vinyl_mode " << ControlObject::get(ConfigKey(group, QStringLiteral("vinylcontrol_mode"))) << "\n";
    }
    out << "USB in channels " << ControlObject::get(ConfigKey(QStringLiteral("[Cutlab]"), QStringLiteral("usb_in_channels")))
        << " blocks " << ControlObject::get(ConfigKey(QStringLiteral("[Cutlab]"), QStringLiteral("usb_in_blocks")));
    for (int c = 1; c <= 8; ++c) {
        out << (c == 1 ? " peaks " : " ")
            << QString::number(ControlObject::get(ConfigKey(QStringLiteral("[Cutlab]"),
                                       QStringLiteral("usb_in_peak_%1").arg(c))),
                       'f',
                       3);
    }
    out << "\n-- Log (sound, USB, vinyl) --\n";
    QFile log(QDir(CmdlineArgs::Instance().getSettingsPath()).filePath(QStringLiteral("mixxx.log")));
    if (log.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QStringList lines = QString::fromUtf8(log.readAll()).split('\n');
        QStringList kept;
        for (const QString& line : lines) {
            if (line.contains(QStringLiteral("Sound"), Qt::CaseInsensitive) ||
                    line.contains(QStringLiteral("USB"), Qt::CaseInsensitive) ||
                    line.contains(QStringLiteral("vinyl"), Qt::CaseInsensitive) ||
                    line.contains(QStringLiteral("device"), Qt::CaseInsensitive) ||
                    line.contains(QStringLiteral("Unable"), Qt::CaseInsensitive) ||
                    line.contains(QStringLiteral("Error"), Qt::CaseInsensitive)) {
                kept.append(line.left(300));
            }
        }
        out << kept.mid(std::max<qsizetype>(0, kept.size() - 80)).join('\n');
    } else {
        out << "(no log file)";
    }
    return text;
}

void QmlSoundManagerProxy::copyToClipboard(const QString& text) const {
    if (QClipboard* pClipboard = QGuiApplication::clipboard()) {
        pClipboard->setText(text);
    }
}

void QmlSoundManagerProxy::commit() {
    removeClashingOutputs();
    m_commitInProgress.storeRelease(1);
    m_pSoundManager->closeActiveConfig(true);
}

} // namespace qml
} // namespace mixxx
