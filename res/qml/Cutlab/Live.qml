pragma Singleton
import QtQuick

// Where the screens find the passthrough and capture of each deck
// (LiveCapture), which live in the performance screen
QtObject {
    property var deck1: null
    property var deck2: null

    function forGroup(group) {
        return group === "[Channel2]" ? deck2 : (group === "[Channel1]" ? deck1 : null);
    }
    function isLive(group) {
        const deck = forGroup(group);
        return !!deck && deck.live;
    }
}
