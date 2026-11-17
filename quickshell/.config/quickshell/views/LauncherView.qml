pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../components"
import "../styles"

// App launcher: the island grows into a search card. Type to filter, ↑/↓ (or
// Tab, Ctrl+J/K) to pick, Enter to launch. Apps you launch often float to the top.
Item {
    id: root

    signal closeRequested

    readonly property int rowHeight: 48
    readonly property int maxVisibleRows: 7
    readonly property int frequentCount: 5

    property string query: ""
    property int selected: 0
    // Flips on each open to replay the content's entry animation.
    property bool revealed: false

    // ==========================================
    // USAGE: launch counts, persisted across sessions
    // ==========================================

    FileView {
        id: usageFile

        path: Quickshell.statePath("launcher-usage.json")
        blockLoading: true
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: usage
            property var counts: ({})
        }
    }

    function usageOf(entry) {
        return usage.counts[entry.id] ?? 0;
    }

    function recordLaunch(entry) {
        const counts = Object.assign({}, usage.counts);
        counts[entry.id] = (counts[entry.id] ?? 0) + 1;
        usage.counts = counts;
        usageFile.writeAdapter();
    }

    // ==========================================
    // SEARCH
    // ==========================================

    readonly property var applications: DesktopEntries.applications.values.filter(entry => !entry.noDisplay).sort((a, b) => a.name.localeCompare(b.name))

    // Higher is better; 0 means no match. Name hits beat description hits, and
    // a loose in-order character match ("ffx" → Firefox) is the last resort.
    function score(entry, needle) {
        const name = entry.name.toLowerCase();
        if (name === needle)
            return 1000;
        if (name.startsWith(needle))
            return 800;
        if (name.split(/[\s\-_.]+/).some(word => word.startsWith(needle)))
            return 600;
        if (name.includes(needle))
            return 450;

        const extras = [entry.genericName, entry.id, ...(entry.keywords ?? [])].join(" ").toLowerCase();
        if (extras.includes(needle))
            return 300;
        if ((entry.comment ?? "").toLowerCase().includes(needle))
            return 150;

        // Subsequence: every query char in order, tighter runs score higher.
        let at = -1;
        let gaps = 0;
        for (const ch of needle) {
            const next = name.indexOf(ch, at + 1);
            if (next < 0)
                return 0;
            if (at >= 0)
                gaps += next - at - 1;
            at = next;
        }
        return Math.max(1, 100 - gaps * 5);
    }

    // Each result: { entry, group } where group is the list section title.
    readonly property var results: {
        const needle = query.trim().toLowerCase();
        if (needle === "") {
            const frequent = applications.filter(entry => usageOf(entry) > 0).sort((a, b) => usageOf(b) - usageOf(a)).slice(0, frequentCount);
            const rest = applications.filter(entry => !frequent.includes(entry));
            return frequent.map(entry => ({ entry, group: "Frequent" })).concat(rest.map(entry => ({ entry, group: "All applications" })));
        }
        return applications.map(entry => ({ entry, rank: score(entry, needle) })).filter(r => r.rank > 0)
            // Usage breaks ties and nudges close calls.
            .sort((a, b) => (b.rank + Math.min(usageOf(b.entry), 50)) - (a.rank + Math.min(usageOf(a.entry), 50)) || a.entry.name.localeCompare(b.entry.name))
            .map(r => ({ entry: r.entry, group: "Results" }));
    }

    // ListView sections need real roles, so results are mirrored into a ListModel
    // that points back into `results` by index.
    ListModel {
        id: resultModel
    }

    onResultsChanged: {
        resultModel.clear();
        resultModel.append(results.map((r, i) => ({ group: r.group, resultIndex: i })));
        selected = 0;
        list.positionViewAtBeginning();
    }

    function accentAlpha(alpha) {
        return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, alpha);
    }

    function move(step) {
        if (results.length === 0)
            return;
        selected = Math.max(0, Math.min(results.length - 1, selected + step));
    }

    function launch(index) {
        const result = results[index];
        if (!result)
            return;
        const entry = result.entry;
        recordLaunch(entry);
        root.closeRequested();
        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: ["kitty", "-e", ...entry.command],
                workingDirectory: entry.workingDirectory || Quickshell.env("HOME")
            });
        else
            entry.execute();
    }

    // ==========================================
    // SIZE: grows with the results, then scrolls
    // ==========================================

    readonly property int listHeight: {
        if (results.length === 0)
            return 96;
        const sections = query.trim() === "" && results[0].group === "Frequent" ? 2 : 1;
        return Math.min(results.length, maxVisibleRows) * rowHeight + sections * 26;
    }

    implicitWidth: 600
    implicitHeight: 2 * card.padding + searchBox.height + 12 + listHeight + 10 + footer.height

    onVisibleChanged: {
        revealed = false;
        if (visible) {
            query = "";
            searchBox.text = "";
            selected = 0;
            list.positionViewAtBeginning();
            revealTimer.restart();
            searchBox.focusInput();
        }
    }

    // Let the island start morphing before the content fades in.
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
            id: content

            anchors.fill: parent
            opacity: root.revealed ? 1 : 0
            transform: Translate { y: root.revealed ? 0 : -8 }

            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            SearchField {
                id: searchBox

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                placeholder: "Search applications"
                pageSize: root.maxVisibleRows

                onTextChanged: root.query = text
                onMoved: step => root.move(step)
                onAccepted: root.launch(root.selected)
                onCloseRequested: root.closeRequested()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.query.trim() === "" ? root.applications.length + " apps" : root.results.length + (root.results.length === 1 ? " match" : " matches")
                    color: Theme.muted
                    font.pixelSize: 11
                }
            }

            // Results
            ListView {
                id: list

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: searchBox.bottom
                anchors.topMargin: 12
                height: root.listHeight

                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: resultModel
                currentIndex: root.selected
                highlightMoveDuration: 140
                highlightMoveVelocity: -1
                highlightResizeDuration: 0
                preferredHighlightBegin: 26
                preferredHighlightEnd: height - root.rowHeight
                highlightRangeMode: ListView.ApplyRange

                section.property: "group"
                section.delegate: Item {
                    required property string section

                    width: list.width
                    height: 26

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        text: parent.section.toUpperCase()
                        color: Theme.muted
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1.2
                    }
                }

                highlight: SelectionHighlight {}

                delegate: Item {
                    id: row

                    required property int resultIndex
                    required property int index
                    readonly property var entry: root.results[resultIndex]?.entry ?? null
                    readonly property bool current: ListView.isCurrentItem
                    readonly property string iconSource: {
                        const icon = entry?.icon ?? "";
                        if (icon === "")
                            return "";
                        return icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, true);
                    }

                    width: list.width
                    height: root.rowHeight

                    // Rows cascade in when the launcher opens.
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
                        // Only follow the pointer when it actually moves, so a list
                        // scrolling under a still cursor doesn't steal the selection.
                        onPositionChanged: root.selected = row.index
                        onClicked: root.launch(row.index)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        // App icon, or its initial on a tinted tile.
                        Item {
                            implicitWidth: 32
                            implicitHeight: 32
                            scale: row.current ? 1.08 : 1

                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                            IconImage {
                                id: appIcon
                                anchors.centerIn: parent
                                implicitSize: 32
                                source: row.iconSource
                                mipmap: true
                                asynchronous: true
                                visible: row.iconSource !== "" && status === Image.Ready
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: !appIcon.visible
                                radius: 9
                                color: root.accentAlpha(0.18)

                                Text {
                                    anchors.centerIn: parent
                                    text: row.entry?.runInTerminal ? Icons.terminal : (row.entry?.name ?? "?").charAt(0).toUpperCase()
                                    color: Theme.accent
                                    font.pixelSize: 15
                                    font.bold: true
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: row.entry?.name ?? ""
                                color: row.current ? Theme.text : Theme.subtle
                                font.pixelSize: 13
                                font.bold: row.current
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: row.entry?.genericName || row.entry?.comment || ""
                                color: Theme.muted
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            visible: row.current
                            text: Icons.enterKey
                            color: Theme.accent
                            font.pixelSize: 15
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    spacing: 6

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Icons.apps
                        color: Theme.border
                        font.pixelSize: 30
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No apps match “" + root.query.trim() + "”"
                        color: Theme.muted
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
                    { keys: "↵", label: "open" },
                    { keys: "esc", label: "close" }
                ]
            }
        }
    }
}
