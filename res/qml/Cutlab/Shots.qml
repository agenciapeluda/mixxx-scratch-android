pragma Singleton
import QtQuick

// Where the FX pad finds the one shot effects of each deck. The engines
// live in the performance screen so the controllers can fire them with the
// pad closed.
QtObject {
    property var deck1: null
    property var deck2: null

    function forGroup(group) {
        return group === "[Channel2]" ? deck2 : deck1;
    }
}
