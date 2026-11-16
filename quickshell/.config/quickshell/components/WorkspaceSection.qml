pragma ComponentBehavior: Bound

import Quickshell.Hyprland
import QtQuick
import "../styles"

Item {
    id: root

    property int workspaceCount: 4
    property int itemSpacing: 5

    // Special workspaces (scratchpads) have negative ids; keep the pill on the
    // last regular workspace while one is open.
    property int activeWorkspace: 1
    readonly property int focusedId: Hyprland.focusedWorkspace?.id ?? 0
    onFocusedIdChanged: {
        if (focusedId > 0)
            activeWorkspace = focusedId;
    }
    Component.onCompleted: {
        if (focusedId > 0)
            activeWorkspace = focusedId;
    }

    // id -> "occupied" | "urgent" for regular workspaces that have windows
    readonly property var workspaceStates: {
        const states = {};
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id > 0 && ws.toplevels.values.length > 0)
                states[ws.id] = ws.urgent ? "urgent" : "occupied";
        }
        return states;
    }

    // Always show 1..workspaceCount, plus any higher workspace that is active or has windows.
    readonly property var workspaceIds: {
        const ids = new Set(Array.from({ length: workspaceCount }, (_, i) => i + 1));
        ids.add(activeWorkspace);
        for (const id in workspaceStates)
            ids.add(Number(id));
        return Array.from(ids).sort((a, b) => a - b);
    }

    function pillWidth(id) {
        return id >= 10 ? 34 : 28;
    }

    readonly property real activeX: {
        let x = 0;
        for (const id of workspaceIds) {
            if (id === activeWorkspace)
                break;
            x += pillWidth(id) + itemSpacing;
        }
        return x;
    }

    width: workspaceRow.implicitWidth
    height: 20

    Rectangle {
        id: activePill
        x: root.activeX
        width: root.pillWidth(root.activeWorkspace)
        height: root.height
        radius: height / 2
        color: Theme.accent

        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    }

    Row {
        id: workspaceRow
        spacing: root.itemSpacing
        anchors.fill: parent

        Repeater {
            model: root.workspaceIds

            delegate: Item {
                id: workspaceItem

                required property int modelData
                readonly property bool isActive: root.activeWorkspace === modelData
                readonly property string wsState: root.workspaceStates[modelData] ?? ""

                width: root.pillWidth(modelData)
                height: 20

                Text {
                    anchors.centerIn: parent
                    text: workspaceItem.modelData
                    color: {
                        if (workspaceItem.isActive)
                            return Theme.accentText;
                        if (workspaceItem.wsState === "urgent")
                            return Theme.error;
                        return workspaceItem.wsState === "occupied" ? Theme.text : Theme.muted;
                    }
                    font.pixelSize: 12
                    font.bold: workspaceItem.isActive || workspaceItem.wsState !== ""
                }

                // Small dot under workspaces that have windows
                Rectangle {
                    visible: !workspaceItem.isActive && workspaceItem.wsState !== ""
                    width: 3
                    height: 3
                    radius: 1.5
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    color: workspaceItem.wsState === "urgent" ? Theme.error : Theme.subtle
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspaceItem.modelData + " })")
                }
            }
        }
    }
}
