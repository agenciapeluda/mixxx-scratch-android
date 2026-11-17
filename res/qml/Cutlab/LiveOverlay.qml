import QtQuick

// Over the waveform of a deck while it plays its turntable live
// (passthrough): "En vivo" instead of a track, and Capturar. A tap keeps
// the last beats picked (1, 2, 4, 8), held it keeps what plays while held.
Rectangle {
    id: root

    required property string group
    property real u: 1
    readonly property var engine: Live.forGroup(group)
    readonly property bool live: !!engine && engine.live
    readonly property bool tall: height >= 110 * u

    function px(value) {
        return Math.round(value * root.u);
    }

    visible: live
    color: Qt.rgba(0.05, 0.02, 0.04, 0.9)
    z: 40

    // Nothing reaches the waveform below (scratch, zoom)
    MouseArea {
        anchors.fill: parent
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - root.px(16)
        spacing: root.px(6)

        // Wraps on a narrow lane (upright)
        Flow {
            width: parent.width
            spacing: root.px(10)

            // ● EN VIVO
            Row {
                height: root.px(40)
                spacing: root.px(6)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.px(10)
                    height: width
                    radius: width / 2
                    color: Style.danger

                    SequentialAnimation on opacity {
                        running: root.visible
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 0.25
                            duration: 700
                        }
                        NumberAnimation {
                            to: 1
                            duration: 700
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Style.text
                    font.family: Style.font
                    font.pixelSize: root.px(15)
                    font.weight: Font.Bold
                    font.letterSpacing: 0.8
                    text: qsTr("EN VIVO")
                }
            }
            // Beats of a tap
            Row {
                height: root.px(40)
                spacing: root.px(4)

                Repeater {
                    model: [1, 2, 4, 8]

                    CLButton {
                        required property int modelData

                        anchors.verticalCenter: parent.verticalCenter
                        width: root.px(40)
                        height: root.px(34)
                        radius: root.px(8)
                        fontSize: root.px(14)
                        text: String(modelData)
                        highlighted: !!root.engine && root.engine.beats === modelData
                        onClicked: if (root.engine) root.engine.setBeats(modelData)
                    }
                }
            }
            // Capturar: tap or hold
            Rectangle {
                id: captureButton

                width: captureLabel.implicitWidth + root.px(32)
                height: root.px(40)
                radius: height / 2
                color: captureMouse.pressed ? Style.danger : (root.engine && root.engine.busy ? Style.raised : Style.deckColor(root.group))

                Text {
                    id: captureLabel

                    anchors.centerIn: parent
                    color: "#ffffff"
                    font.family: Style.font
                    font.pixelSize: root.px(15)
                    font.weight: Font.Bold
                    text: captureMouse.pressed && captureMouse.held ? qsTr("GRABANDO…") : qsTr("CAPTURAR")
                }
                MouseArea {
                    id: captureMouse

                    property bool held: false

                    anchors.fill: parent
                    anchors.margins: -root.px(4)
                    preventStealing: true
                    onPressed: {
                        held = false;
                        holdTimer.restart();
                        if (root.engine) {
                            root.engine.pressCapture();
                        }
                    }
                    onReleased: {
                        holdTimer.stop();
                        if (root.engine) {
                            root.engine.releaseCapture();
                        }
                    }
                    onCanceled: holdTimer.stop()

                    Timer {
                        id: holdTimer

                        interval: 400
                        onTriggered: captureMouse.held = true
                    }
                }
            }
            // Out of EN VIVO (also where the screen has no EN VIVO button)
            CLButton {
                width: root.px(64)
                height: root.px(40)
                radius: root.px(10)
                fontSize: root.px(13)
                text: qsTr("Salir")
                onClicked: if (root.engine) root.engine.toggle()
            }
            // The capture loops on a sampler: stop it
            CLButton {
                visible: !!root.engine && root.engine.samplerPlaying
                width: root.px(44)
                height: root.px(40)
                radius: root.px(10)
                fontSize: root.px(15)
                text: "■"
                onClicked: root.engine.stopSampler()
            }
        }
        Text {
            width: parent.width
            visible: root.tall || text !== ""
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: root.engine && root.engine.statusError ? Style.danger : Style.textSecondary
            font.family: Style.font
            font.pixelSize: root.px(12)
            text: {
                if (!root.engine) {
                    return "";
                }
                if (root.engine.status !== "") {
                    return root.engine.status;
                }
                if (!root.tall) {
                    return "";
                }
                return root.engine.referenceBpm > 0
                    ? qsTr("Tocá: los últimos %1 tiempos a %2 BPM (del otro deck) · mantené: graba mientras apretás").arg(root.engine.beats).arg(root.engine.referenceBpm.toFixed(1))
                    : qsTr("Sin BPM en el otro deck: se corta a 120 BPM y el tempo se detecta · mantené: graba mientras apretás");
            }
        }
        // A turntable straight into the interface, no preamp
        Rectangle {
            visible: !!root.engine && root.engine.noPreamp
            width: parent.width
            height: noPreText.implicitHeight + root.px(10)
            radius: root.px(8)
            color: Qt.rgba(1, 0.3, 0.37, 0.16)
            border.width: 1
            border.color: Style.danger

            Text {
                id: noPreText

                anchors.centerIn: parent
                width: parent.width - root.px(16)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Style.text
                font.family: Style.font
                font.pixelSize: root.px(12)
                text: qsTr("El plato entra sin pre: sin RIAA la música suena baja y finita. Pasalo por un pre phono (como el de JJ) o una entrada PHONO.")
            }
        }
    }
}
