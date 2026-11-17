pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../components"
import "../styles"

// Clipboard history (cliphist): the island grows into a searchable list of
// everything you've copied, newest first. Enter copies the selected entry back
// to the clipboard; Shift+Delete removes it. Images get thumbnails.
Item {
    id: root

    signal closeRequested

    readonly property int textRowHeight: 52
    readonly property int imageRowHeight: 76
    readonly property int maxVisibleRows: 7

    property string query: ""
    property int selected: 0
    property bool revealed: false

    // Every history line, parsed: { line, id, kind, preview, ... }
    property var entries: []
    property bool loading: false
    property bool cliphistMissing: false
    // Bumped when thumbnails finish decoding so image rows load them.
    property int thumbsVersion: 0
    readonly property string thumbDir: Quickshell.cachePath("clipboard-thumbs")

    // ==========================================
    // CLIPHIST
    // ==========================================

    function parse(output) {
        const imagePattern = /^\[\[ binary data (.+?) (\w+) (\d+)x(\d+) \]\]$/;
        const binaryPattern = /^\[\[ binary data (.+?)(?: (\w+))? \]\]$/;
        return output.split("\n").filter(line => line.includes("\t")).map(line => {
            const tab = line.indexOf("\t");
            const entry = { line, id: line.slice(0, tab), preview: line.slice(tab + 1) };
            let match;
            if ((match = entry.preview.match(imagePattern))) {
                entry.kind = "image";
                entry.size = match[1];
                entry.format = match[2];
                entry.dimensions = match[3] + "×" + match[4];
                entry.thumb = entry.id + "." + match[2];
            } else if ((match = entry.preview.match(binaryPattern))) {
                entry.kind = "binary";
                entry.size = match[1];
                entry.format = match[2] ?? "";
            } else if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(entry.preview.trim())) {
                entry.kind = "color";
            } else if (/^(https?|ftp|file):\/\/\S+$/.test(entry.preview.trim())) {
                entry.kind = "link";
            } else {
                entry.kind = "text";
            }
            return entry;
        });
    }

    function reload() {
        loading = true;
        listProc.running = true;
    }

    Process {
        id: listProc

        command: ["sh", "-c", "command -v cliphist >/dev/null || exit 127; cliphist list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = root.parse(text);
                root.loading = false;
                root.decodeThumbs();
            }
        }
        onExited: code => root.cliphistMissing = code === 127
    }

    // Decode image entries into the cache (once each) and prune thumbnails of
    // entries that left the history.
    function decodeThumbs() {
        const names = entries.filter(e => e.kind === "image").map(e => e.thumb);
        thumbProc.command = ["sh", "-c", `
            dir=$1; shift
            mkdir -p "$dir" || exit 1
            for name; do
                [ -s "$dir/$name" ] || printf '%s\\t\\n' "\${name%%.*}" | cliphist decode > "$dir/$name"
            done
            for f in "$dir"/*; do
                [ -e "$f" ] || continue
                case " $* " in *" \${f##*/} "*) ;; *) rm -f -- "$f" ;; esac
            done`, "sh", thumbDir, ...names];
        thumbProc.running = true;
    }

    Process {
        id: thumbProc
        onExited: root.thumbsVersion++
    }

    function copy(index) {
        const entry = results[index];
        if (!entry)
            return;
        root.closeRequested();
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "sh", entry.line]);
    }

    function remove(index) {
        const entry = results[index];
        if (!entry)
            return;
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "sh", entry.line]);
        // Drop it locally right away instead of waiting for a reload.
        const keep = selected;
        entries = entries.filter(e => e !== entry);
        selected = Math.min(keep, results.length - 1);
    }

    function wipe() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        entries = [];
    }

    // ==========================================
    // SEARCH
    // ==========================================

    readonly property var results: {
        const needle = query.trim().toLowerCase();
        if (needle === "")
            return entries;
        return entries.filter(e => {
            if (e.kind === "image")
                return ("image " + e.format + " " + e.dimensions).toLowerCase().includes(needle);
            return e.preview.toLowerCase().includes(needle);
        });
    }

    onQueryChanged: {
        selected = 0;
        list.positionViewAtBeginning();
    }

    function move(step) {
        if (results.length === 0)
            return;
        selected = Math.max(0, Math.min(results.length - 1, selected + step));
    }

    function rowHeightOf(entry) {
        return entry.kind === "image" ? imageRowHeight : textRowHeight;
    }

    function describe(entry) {
        switch (entry.kind) {
        case "image":
            return entry.format.toUpperCase() + " · " + entry.dimensions + " · " + entry.size;
        case "binary":
            return (entry.format ? entry.format.toUpperCase() + " · " : "") + entry.size;
        case "color":
            return "Color";
        case "link":
            return "Link";
        default:
            return "";
        }
    }

    // ==========================================
    // SIZE: grows with the history, then scrolls
    // ==========================================

    readonly property int listHeight: {
        if (results.length === 0)
            return 96;
        return results.slice(0, maxVisibleRows).reduce((sum, e) => sum + rowHeightOf(e), 0);
    }

    implicitWidth: 600
    implicitHeight: 2 * card.padding + searchBox.height + 12 + listHeight + 10 + footer.height

    onVisibleChanged: {
        revealed = false;
        clearButton.armed = false;
        if (visible) {
            searchBox.text = "";
            selected = 0;
            list.positionViewAtBeginning();
            reload();
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
                icon: Icons.clipboard
                placeholder: "Search clipboard"
                pageSize: root.maxVisibleRows

                onTextChanged: root.query = text
                onMoved: step => root.move(step)
                onAccepted: root.copy(root.selected)
                onRemoveRequested: root.remove(root.selected)
                onCloseRequested: root.closeRequested()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.query.trim() === "" ? root.entries.length + (root.entries.length === 1 ? " item" : " items") : root.results.length + (root.results.length === 1 ? " match" : " matches")
                    color: Theme.muted
                    font.pixelSize: 11
                }

                // Clear history: the first click arms it, the second wipes.
                IconButton {
                    id: clearButton

                    property bool armed: false

                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.entries.length > 0
                    icon: Icons.trash
                    label: armed ? "Clear all?" : ""
                    iconSize: 13
                    iconColor: armed ? Theme.error : Theme.muted
                    tooltip: armed ? "" : "Clear history"
                    onClicked: {
                        if (armed) {
                            armed = false;
                            root.wipe();
                        } else {
                            armed = true;
                            disarmTimer.restart();
                        }
                    }

                    Timer {
                        id: disarmTimer
                        interval: 3000
                        onTriggered: clearButton.armed = false
                    }
                }
            }

            ListView {
                id: list

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: searchBox.bottom
                anchors.topMargin: 12
                height: root.listHeight

                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.results
                currentIndex: root.selected
                highlightMoveDuration: 140
                highlightMoveVelocity: -1
                highlightResizeDuration: 100
                highlightResizeVelocity: -1
                preferredHighlightBegin: 0
                preferredHighlightEnd: height - root.textRowHeight
                highlightRangeMode: ListView.ApplyRange

                highlight: SelectionHighlight {}

                delegate: Item {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property var entry: modelData
                    readonly property bool current: ListView.isCurrentItem
                    readonly property bool isImage: entry.kind === "image"

                    width: list.width
                    height: root.rowHeightOf(entry)

                    opacity: root.revealed ? 1 : 0
                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: Math.max(0, Math.min(row.index, 8)) * 22 }
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: root.selected = row.index
                        onClicked: root.copy(row.index)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        spacing: 12

                        // Leading tile: thumbnail, color swatch or kind glyph.
                        ClippingRectangle {
                            id: tile

                            implicitWidth: row.isImage ? 88 : 32
                            implicitHeight: row.isImage ? 56 : 32
                            radius: row.isImage ? 8 : 9
                            color: row.entry.kind === "color" ? row.entry.preview.trim() : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                            border.width: row.entry.kind === "color" || row.isImage ? 1 : 0
                            border.color: Theme.border

                            Image {
                                id: thumb
                                anchors.fill: parent
                                visible: row.isImage && status === Image.Ready
                                source: row.isImage && root.thumbsVersion > 0 ? "file://" + root.thumbDir + "/" + row.entry.thumb : ""
                                sourceSize.width: 176
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: row.entry.kind !== "color" && !thumb.visible
                                text: row.isImage || row.entry.kind === "binary" ? Icons.image : row.entry.kind === "link" ? Icons.link : Icons.clipboard
                                color: Theme.accent
                                font.pixelSize: 15
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: row.isImage ? "Image" : row.entry.kind === "binary" ? "Binary data" : row.entry.preview
                                color: row.entry.kind === "link" ? Theme.accent : row.current ? Theme.text : Theme.subtle
                                font.pixelSize: 12
                                font.bold: row.isImage && row.current
                                // Text gets two lines; the rest one line plus a description.
                                wrapMode: Text.WrapAnywhere
                                maximumLineCount: root.describe(row.entry) === "" ? 2 : 1
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: root.describe(row.entry)
                                color: Theme.muted
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        // Delete on hover; the Enter hint marks the selection otherwise.
                        Item {
                            implicitWidth: 26
                            implicitHeight: 24

                            IconButton {
                                id: removeButton
                                anchors.fill: parent
                                visible: rowMouse.containsMouse || hovered
                                icon: Icons.trash
                                iconSize: 13
                                iconColor: hovered ? Theme.error : Theme.muted
                                onClicked: root.remove(row.index)
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: row.current && !removeButton.visible
                                text: Icons.enterKey
                                color: Theme.accent
                                font.pixelSize: 15
                            }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    visible: list.count === 0 && !root.loading
                    spacing: 6

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Icons.clipboard
                        color: Theme.border
                        font.pixelSize: 30
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            if (root.cliphistMissing)
                                return "cliphist isn't installed";
                            if (root.entries.length === 0)
                                return "Nothing copied yet";
                            return "Nothing matches “" + root.query.trim() + "”";
                        }
                        color: root.cliphistMissing ? Theme.error : Theme.muted
                        font.pixelSize: 11
                    }
                }
            }

            KeyHints {
                id: footer

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: list.bottom
                anchors.topMargin: 10
                hints: [
                    { keys: "↑ ↓", label: "navigate" },
                    { keys: "↵", label: "copy" },
                    { keys: "⇧ del", label: "remove" },
                    { keys: "esc", label: "close" }
                ]
            }
        }
    }
}
