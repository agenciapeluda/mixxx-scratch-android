pragma Singleton
import Mixxx 1.0 as Mixxx
import QtQuick

// One reader of the play position for everything that shows numbers or
// marks (time left, drop radar, sections, the dial's ring): 15 times a
// second, all at once, instead of each of them running on every update of
// the audio engine. What moves with the music frame by frame (waveforms,
// the dial's dot) does not use it: it has its own smooth position.
Item {
    id: root

    property real position1: 0
    property real position2: 0
    property real position3: 0
    property real position4: 0
    signal tick

    function position(group) {
        switch (group) {
        case "[Channel1]":
            return root.position1;
        case "[Channel2]":
            return root.position2;
        case "[Channel3]":
            return root.position3;
        case "[Channel4]":
            return root.position4;
        }
        return 0;
    }

    Mixxx.ControlProxy {
        id: p1

        group: "[Channel1]"
        key: "playposition"
    }
    Mixxx.ControlProxy {
        id: p2

        group: "[Channel2]"
        key: "playposition"
    }
    Mixxx.ControlProxy {
        id: p3

        group: "[Channel3]"
        key: "playposition"
    }
    Mixxx.ControlProxy {
        id: p4

        group: "[Channel4]"
        key: "playposition"
    }
    Timer {
        interval: 66
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            // Only a change wakes the bindings
            if (root.position1 !== p1.value) root.position1 = p1.value;
            if (root.position2 !== p2.value) root.position2 = p2.value;
            if (root.position3 !== p3.value) root.position3 = p3.value;
            if (root.position4 !== p4.value) root.position4 = p4.value;
            root.tick();
        }
    }
}
