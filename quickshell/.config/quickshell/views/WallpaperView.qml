pragma ComponentBehavior: Bound

import Quickshell.Widgets
import QtQuick
import "../components"
import "../services"
import "../styles"

// Wallpaper picker: the island grows into a grid of everything in
// ~/Pictures/Wallpapers, each with its name and five main colors. Enter (or a
// click) applies it: hyprpaper, the shell's colors and Hyprland's borders all
// follow. The island stays open so you can try a few; Escape closes.
Item {
    id: root

    required property WallpaperService service

    signal closeRequested

    readonly property int columns: 3
    readonly property int cellWidth: 212
    readonly property int cellHeight: 178
    readonly property int maxVisibleRows: 2

    property string query: ""
    property int selected: 0
    property bool revealed: false
    // The selection starts on the wallpaper in use and keeps tracking it while the
    // list and current path finish loading, until you move it yourself.
    property bool followCurrent: false

    function selectCurrent() {
        selected = Math.max(0, results.findIndex(w => w.path === service.current));
        grid.positionViewAtIndex(selected, GridView.Contain);
    }

    Connections {
        target: root.service

        function onCurrentChanged() {
            if (root.followCurrent)
                root.selectCurrent();
        }

        function onWallpapersChanged() {
            if (root.followCurrent)
                root.selectCurrent();
        }
    }

    readonly property var results: {
        const needle = query.trim().toLowerCase();
        const all = service.wallpapers;
        return needle === "" ? all : all.filter(w => w.name.toLowerCase().includes(needle));
    }

    onQueryChanged: {
        followCurrent = false;
        selected = 0;
        grid.positionViewAtBeginning();
    }

    function move(step) {
        followCurrent = false;
        if (results.length === 0)
            return;
        selected = Math.max(0, Math.min(results.length - 1, selected + step));
    }

    function apply(index) {
        const wallpaper = results[index];
        if (wallpaper)
            service.apply(wallpaper.path);
    }

    // ==========================================
    // SIZE: grows to two rows, then scrolls
    // ==========================================

    readonly property int rows: Math.ceil(results.length / columns)
    readonly property int gridHeight: results.length === 0 ? 120 : Math.min(rows, maxVisibleRows) * cellHeight

    implicitWidth: 2 * card.padding + columns * cellWidth
    implicitHeight: 2 * card.padding + searchBox.height + 12 + gridHeight + 10 + footer.height

    onVisibleChanged: {
        revealed = false;
        if (visible) {
            searchBox.text = "";
            followCurrent = true;
            selectCurrent();
            service.refresh();
            revealTimer.restart();
            searchBox.focusInput();
        }
    }

    Timer {
        id: revealTimer
        interval: 60
        onTriggered: root.revealed = true
    }

    // ==========================================
    // CONTENT
    // ==========================================

    Card {
        id: card

        anchors.fill: parent
        padding: 14
        clip: true

        Item {
            anchors.fill: parent
            opacity: root.revealed ? 1 : 0
            transform: Translate { y: root.revealed ? 0 : -8 }

            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            SearchField {
                id: searchBox

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                icon: Icons.image
                placeholder: "Search wallpapers"
                columns: root.columns
                pageSize: root.maxVisibleRows

                onTextChanged: root.query = text
                onMoved: step => root.move(step)
                onAccepted: root.apply(root.selected)
                onCloseRequested: root.closeRequested()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (root.service.extracting !== "")
                            return "Reading colors…";
                        const n = root.query.trim() === "" ? root.service.wallpapers.length : root.results.length;
                        return n + (root.query.trim() === "" ? (n === 1 ? " wallpaper" : " wallpapers") : (n === 1 ? " match" : " matches"));
                    }
                    color: Theme.muted
                    font.pixelSize: 11
                }
            }

            GridView {
                id: grid

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: searchBox.bottom
                anchors.topMargin: 12
                height: root.gridHeight

                clip: true
                boundsBehavior: Flickable.StopAtBounds
                cellWidth: root.cellWidth
                cellHeight: root.cellHeight
                model: root.results
                currentIndex: root.selected
                highlightMoveDuration: 140
                highlightFollowsCurrentItem: true
                preferredHighlightBegin: 0
                preferredHighlightEnd: height
                highlightRangeMode: GridView.ApplyRange

                highlight: Item {
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 14
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                        border.width: 1
                        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
                    }
                }

                delegate: Item {
                    id: cell

                    required property var modelData
                    required property int index
                    readonly property var wallpaper: modelData
                    readonly property bool current: GridView.isCurrentItem
                    readonly property bool inUse: wallpaper.path === root.service.current
                    // Five main colors, or null while sampling.
                    readonly property var colors: root.service.paletteOf(wallpaper.path)

                    width: root.cellWidth
                    height: root.cellHeight

                    opacity: root.revealed ? 1 : 0
                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: Math.max(0, Math.min(cell.index, 8)) * 26 }
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: {
                            root.followCurrent = false;
                            root.selected = cell.index;
                        }
                        onClicked: {
                            root.followCurrent = false;
                            root.selected = cell.index;
                            root.apply(cell.index);
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        // Preview
                        ClippingRectangle {
                            width: parent.width
                            height: Math.round(width * 9 / 16)
                            radius: 9
                            color: Theme.surface
                            border.width: 1
                            border.color: cell.inUse ? Theme.accent : Theme.border

                            Image {
                                id: preview
                                anchors.fill: parent
                                source: "file://" + cell.wallpaper.path
                                sourceSize.width: 384
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                opacity: status === Image.Ready ? 1 : 0

                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: preview.status !== Image.Ready
                                text: Icons.image
                                color: Theme.border
                                font.pixelSize: 24
                            }

                            // In-use badge
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                visible: cell.inUse
                                width: 22
                                height: 22
                                radius: 11
                                color: Theme.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.check
                                    color: Theme.accentText
                                    font.pixelSize: 13
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: cell.wallpaper.name
                            color: cell.current || cell.inUse ? Theme.text : Theme.subtle
                            font.pixelSize: 12
                            font.bold: cell.inUse
                            elide: Text.ElideRight
                        }

                        // Five main colors, most common first; placeholders while sampling.
                        Row {
                            spacing: 7

                            Repeater {
                                model: 5

                                delegate: Rectangle {
                                    id: swatch

                                    required property int index
                                    readonly property var entry: cell.colors ? cell.colors[index] ?? null : null

                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: entry ? entry.hex : Theme.surface
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.18)
                                    opacity: entry ? 1 : 0.5

                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    visible: grid.count === 0 && !root.service.loading
                    spacing: 6

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Icons.image
                        color: Theme.border
                        font.pixelSize: 30
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.service.wallpapers.length === 0 ? "No images in ~/Pictures/Wallpapers" : "Nothing matches “" + root.query.trim() + "”"
                        color: Theme.muted
                        font.pixelSize: 11
                    }
                }
            }

            KeyHints {
                id: footer

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: grid.bottom
                anchors.topMargin: 10
                hints: [
                    { keys: "← ↑ ↓ →", label: "navigate" },
                    { keys: "↵", label: "apply" },
                    { keys: "esc", label: "close" }
                ]
            }
        }
    }
}
