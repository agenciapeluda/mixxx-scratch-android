import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Mixxx 1.0 as Mixxx
import "." as Skin
import "Theme"
import "Cutlab" as Cutlab

// Cutlab: Auto DJ controls for the touch interface. The queue is the Auto DJ
// playlist of the library ("Add to Auto DJ" in the track menu).
Popup {
    id: root

    readonly property var modes: [
        qsTr("Intro → Outro"),
        qsTr("Al empezar el outro"),
        qsTr("Tema completo"),
        qsTr("Saltear silencios"),
        qsTr("Saltear silencios, entrar a pleno")
    ]

    // The queue is shown by whoever opened the panel
    signal queueRequested

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    focus: true
    modal: true
    padding: 20
    width: Math.min(parent ? parent.width - 40 : 640, 640)
    height: Math.min(implicitHeight, parent ? parent.height - 24 : 600)

    background: Rectangle {
        border.color: "#3e3e41"
        border.width: 1
        color: Cutlab.Style.panelDark
        radius: 16
    }

    // How many tracks wait in the queue, read when the panel opens and
    // after each change made here
    property int queued: 0
    onOpened: root.queued = Mixxx.Cutlab.queueCount()

    // Why Auto DJ would not start, in the words of the booth; "" when it can
    function startProblem() {
        root.queued = Mixxx.Cutlab.queueCount();
        if (Math.round(orientation1.value) !== 0 || Math.round(orientation2.value) !== 2) {
            return qsTr("Auto DJ pasa del deck A (izquierda) al B (derecha): dejá A a la izquierda y B a la derecha del crossfader.");
        }
        if (play1.value > 0 && play2.value > 0) {
            return qsTr("Los dos decks están sonando: pausá uno y Auto DJ sigue desde el otro.");
        }
        if (play3.value > 0 || play4.value > 0) {
            return qsTr("Hay otro deck sonando (C o D): paralo y probá de nuevo.");
        }
        if (root.queued === 0) {
            return qsTr("La cola está vacía: tocá «Llenar la cola» o agregá temas desde la biblioteca.");
        }
        return qsTr("Auto DJ no arrancó: revisá que el tema siguiente de la cola no sea el que está sonando.");
    }
    function fill() {
        const group = play2.value > 0 && play1.value <= 0 ? "[Channel2]" : "[Channel1]";
        const added = Mixxx.Cutlab.fillQueue(group, 10);
        root.queued = Mixxx.Cutlab.queueCount();
        autoDJHint.text = added > 0 ? qsTr("Sumé %1 temas que pegan: BPM cercano, tono compatible, sin repetir artista.").arg(added)
            : (root.queued === 0 && !(Mixxx.PlayerManager.getPlayer(group) && Mixxx.PlayerManager.getPlayer(group).currentTrack)
                ? qsTr("Cargá un tema en un deck: la cola se arma a partir de él.")
                : qsTr("No encontré más temas que peguen: falta analizar BPM y tono, o ya están todos en la cola."));
        autoDJHint.color = added > 0 ? Cutlab.Style.ok : Cutlab.Style.cue;
        autoDJHint.visible = true;
    }

    Mixxx.ControlProxy {
        id: orientation1

        group: "[Channel1]"
        key: "orientation"
    }
    Mixxx.ControlProxy {
        id: orientation2

        group: "[Channel2]"
        key: "orientation"
    }
    Mixxx.ControlProxy {
        id: play1

        group: "[Channel1]"
        key: "play"
    }
    Mixxx.ControlProxy {
        id: play2

        group: "[Channel2]"
        key: "play"
    }
    Mixxx.ControlProxy {
        id: play3

        group: "[Channel3]"
        key: "play"
    }
    Mixxx.ControlProxy {
        id: play4

        group: "[Channel4]"
        key: "play"
    }
    Mixxx.ControlProxy {
        id: enabledControl

        group: "[AutoDJ]"
        key: "enabled"
    }
    Mixxx.ControlProxy {
        id: fadeNowControl

        group: "[AutoDJ]"
        key: "fade_now"
    }
    Mixxx.ControlProxy {
        id: skipNextControl

        group: "[AutoDJ]"
        key: "skip_next"
    }
    Mixxx.ControlProxy {
        id: shuffleControl

        group: "[AutoDJ]"
        key: "shuffle_playlist"
    }
    Mixxx.ControlProxy {
        id: addRandomControl

        group: "[AutoDJ]"
        key: "add_random_track"
    }
    Mixxx.ControlProxy {
        id: transitionTimeControl

        group: "[AutoDJ]"
        key: "transition_time"
    }
    Mixxx.ControlProxy {
        id: transitionModeControl

        group: "[AutoDJ]"
        key: "transition_mode"
    }

    contentItem: Flickable {
        implicitHeight: panelLayout.implicitHeight
        contentHeight: panelLayout.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

    ColumnLayout {
        id: panelLayout

        width: parent.width
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Image {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                source: "Cutlab/icons/autodj.svg"
                sourceSize.width: 64
                sourceSize.height: 64
            }
            Text {
                Layout.fillWidth: true
                color: Cutlab.Style.text
                font.family: Cutlab.Style.font
                font.pixelSize: 20
                font.weight: Font.Medium
                text: qsTr("Auto DJ")
            }
            // On / off switch
            Rectangle {
                id: autoSwitch

                readonly property bool on: enabledControl.value > 0

                Layout.preferredWidth: 58
                Layout.preferredHeight: 32
                radius: 16
                color: on ? Cutlab.Style.play : "#48484b"

                Rectangle {
                    x: autoSwitch.on ? parent.width - width - 3 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: 13
                    color: "#ffffff"

                    Behavior on x {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: {
                        const turningOn = !autoSwitch.on;
                        enabledControl.value = turningOn ? 1 : 0;
                        autoDJHint.visible = false;
                        if (turningOn) {
                            refusedCheck.restart();
                        }
                    }
                }
                // Auto DJ refuses to start without tracks in the queue or
                // with both decks playing: say why
                Timer {
                    id: refusedCheck

                    interval: 400
                    onTriggered: {
                        if (enabledControl.value <= 0) {
                            autoDJHint.text = root.startProblem();
                            autoDJHint.color = Cutlab.Style.cue;
                            autoDJHint.visible = true;
                        }
                    }
                }
            }
        }
        Text {
            id: autoDJHint

            Layout.fillWidth: true
            visible: false
            color: Cutlab.Style.cue
            font.family: Cutlab.Style.font
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
        Text {
            Layout.fillWidth: true
            color: Cutlab.Style.textSecondary
            font.family: Cutlab.Style.font
            font.pixelSize: 13
            text: (root.queued > 0 ? qsTr("Cola: %1 temas. ").arg(root.queued) : qsTr("La cola está vacía. ")) + qsTr("Auto DJ pasa la cola mezclando entre el deck A y el B. Sumá temas con «Llenar la cola», manteniendo un tema en la biblioteca o con la controladora (mantené BROWSE).")
            wrapMode: Text.WordWrap
        }
        Cutlab.CLButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            icon: "queue"
            text: qsTr("Llenar la cola con temas que pegan")
            fontSize: 15
            highlighted: true
            textColor: "#ffffff"
            onClicked: root.fill()
        }
        GridLayout {
            Layout.fillWidth: true
            columnSpacing: 8
            columns: root.width > 520 ? 4 : 2
            rowSpacing: 8

            Cutlab.CLButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                text: qsTr("Mezclar ya")
                fontSize: 14
                onClicked: {
                    fadeNowControl.value = 1;
                    fadeNowControl.value = 0;
                }
            }
            Cutlab.CLButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                text: qsTr("Saltear el próximo")
                fontSize: 14
                onClicked: {
                    skipNextControl.value = 1;
                    skipNextControl.value = 0;
                }
            }
            Cutlab.CLButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                text: qsTr("Cola al azar")
                fontSize: 14
                onClicked: {
                    shuffleControl.value = 1;
                    shuffleControl.value = 0;
                }
            }
            Cutlab.CLButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                text: qsTr("Sumar uno al azar")
                fontSize: 14
                onClicked: {
                    addRandomControl.value = 1;
                    addRandomControl.value = 0;
                }
            }
        }
        // Transition: one chip per mode
        Text {
            color: Cutlab.Style.textSecondary
            font.family: Cutlab.Style.font
            font.pixelSize: 13
            text: qsTr("Transición")
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.modes

                Cutlab.CLButton {
                    required property int index
                    required property string modelData

                    height: 36
                    text: modelData
                    fontSize: 13
                    fontWeight: Font.Normal
                    radius: 18
                    highlighted: Math.round(transitionModeControl.value) === index
                    onClicked: transitionModeControl.value = index
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                color: Cutlab.Style.textSecondary
                font.family: Cutlab.Style.font
                font.pixelSize: 13
                text: qsTr("Duración de la mezcla")
            }
            Slider {
                id: fadeSlider

                Layout.fillWidth: true
                from: 0
                stepSize: 1
                to: 30
                value: transitionTimeControl.value

                onMoved: transitionTimeControl.value = value

                background: Rectangle {
                    x: fadeSlider.leftPadding
                    y: fadeSlider.topPadding + fadeSlider.availableHeight / 2 - height / 2
                    width: fadeSlider.availableWidth
                    height: 6
                    radius: 3
                    color: Cutlab.Style.track

                    Rectangle {
                        width: fadeSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 3
                        color: Cutlab.Style.accent
                    }
                }
                handle: Rectangle {
                    x: fadeSlider.leftPadding + fadeSlider.visualPosition * (fadeSlider.availableWidth - width)
                    y: fadeSlider.topPadding + fadeSlider.availableHeight / 2 - height / 2
                    width: 26
                    height: 26
                    radius: 13
                    color: "#e5e5ea"
                }
            }
            Text {
                Layout.preferredWidth: 44
                color: Cutlab.Style.text
                font.family: Cutlab.Style.font
                font.pixelSize: 14
                horizontalAlignment: Text.AlignRight
                text: qsTr("%1 s").arg(Math.round(fadeSlider.value))
            }
        }
        Cutlab.CLButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            icon: "queue"
            iconSize: 20
            text: qsTr("Ver la cola")
            fontSize: 14
            highlighted: true
            onClicked: {
                root.close();
                root.queueRequested();
            }
        }
    }
    }
}
