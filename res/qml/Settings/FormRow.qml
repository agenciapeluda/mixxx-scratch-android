import QtQuick
import QtQuick.Layouts

// A row of a settings page that never runs past its width: when the label
// and the controls fit it is a plain row; when they don't (a phone upright,
// a narrow pane) the label goes on top, across the whole width, and the
// controls go under it, each one no wider than the row. It decides from the
// sizes of its children, in the same frame, with no timers, so a page shows
// up already laid out.
GridLayout {
    id: row

    // Like RowLayout
    property real spacing: 5
    // The least room the label (the first child) keeps beside the controls
    property real labelMinimum: 120

    // The children the layout places (not repeaters, not hidden ones)
    function placed() {
        const list = [];
        const kids = row.children;
        for (let i = 0; i < kids.length; ++i) {
            const kid = kids[i];
            if (!kid || !kid.visible) {
                continue;
            }
            // A Repeater sits among the children but takes no room
            if (kid.delegate !== undefined && kid.model !== undefined && kid.count !== undefined && kid.itemAt !== undefined) {
                continue;
            }
            list.push(kid);
        }
        return list;
    }
    // The width the row needs to stay a single row
    readonly property real needed: {
        const kids = row.placed();
        if (kids.length < 2) {
            return 0;
        }
        let total = row.labelMinimum;
        for (let i = 1; i < kids.length; ++i) {
            const kid = kids[i];
            const layout = kid.Layout;
            let width = layout.preferredWidth > 0 ? layout.preferredWidth : kid.implicitWidth;
            if (layout.fillWidth) {
                // What stretches only needs its minimum (texts elide)
                width = Math.min(width, Math.max(layout.minimumWidth, 60));
            } else {
                width = Math.max(width, layout.minimumWidth);
            }
            total += width + layout.leftMargin + layout.rightMargin;
        }
        return total + row.columnSpacing * (kids.length - 1);
    }
    // A little slack before going back to one row, so it never flickers
    property bool stacked: false
    readonly property bool wantStacked: row.width > 0 && row.needed > 0 && (row.stacked ? row.width < row.needed + 8 : row.width < row.needed)
    onWantStackedChanged: row.stacked = row.wantStacked

    // What it changed on the children, to give it back
    property var saved: []

    function apply() {
        // Back to how the children were
        for (let i = 0; i < row.saved.length; ++i) {
            const entry = row.saved[i];
            if (entry.item) {
                entry.item.Layout.columnSpan = entry.span;
                entry.item.Layout.maximumWidth = entry.max;
            }
        }
        row.saved = [];
        const kids = row.placed();
        if (!row.stacked || kids.length < 2) {
            row.columns = -1;
            return;
        }
        const controls = kids.length - 1;
        const widest = Math.max(0, (row.width - row.columnSpacing * (controls - 1)) / controls);
        const saved = [];
        for (let i = 0; i < kids.length; ++i) {
            const kid = kids[i];
            saved.push({item: kid, span: kid.Layout.columnSpan, max: kid.Layout.maximumWidth});
            if (i === 0) {
                kid.Layout.columnSpan = controls;
            } else {
                kid.Layout.maximumWidth = Math.min(kid.Layout.maximumWidth, widest);
            }
        }
        row.saved = saved;
        row.columns = controls;
    }

    columns: -1
    columnSpacing: row.spacing
    rowSpacing: 4

    readonly property int placedCount: row.placed().length

    onStackedChanged: row.apply()
    onPlacedCountChanged: {
        if (row.stacked) {
            row.apply();
        }
    }
    onWidthChanged: {
        if (row.stacked) {
            row.apply();
        }
    }
    Component.onCompleted: {
        row.stacked = row.wantStacked;
        row.apply();
    }
}
