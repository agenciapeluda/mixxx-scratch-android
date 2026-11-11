import QtQuick

// letsktch! on both decks: the voice (or the stem picked) scratched on the
// deck, its beat looping on a hidden deck (3 for A, 4 for B). Played from
// the Scratch pads of each deck; see LetsktchDeck.
Item {
    id: root

    // The deck it plays on now ("" none), the one shown over the waves
    readonly property string group: deck1.active ? "[Channel1]" : (deck2.active ? "[Channel2]" : "")
    readonly property bool active: root.group !== ""

    signal failed(string text)

    function deckOf(group) {
        return group === "[Channel2]" ? deck2 : deck1;
    }
    // A button of a controller: the first free slot, or out
    function toggle(group) {
        root.deckOf(group).toggleFromController();
    }
    function stop(group) {
        root.deckOf(group).exit();
    }

    LetsktchDeck {
        id: deck1

        group: "[Channel1]"
        helper: "[Channel3]"
        onFailed: text => root.failed(text)
    }
    LetsktchDeck {
        id: deck2

        group: "[Channel2]"
        helper: "[Channel4]"
        onFailed: text => root.failed(text)
    }
}
