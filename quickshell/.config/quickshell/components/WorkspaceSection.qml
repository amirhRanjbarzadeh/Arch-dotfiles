import Quickshell.Hyprland
import QtQuick
import "../styles"

Row {
    id: root

    property int workspaceCount: 4
    property int activeWorkspace: Hyprland.focusedWorkspace?.id ?? 1

    spacing: 5

    readonly property var workspaceIds: {
        if (activeWorkspace > workspaceCount)
            return Array.from({
                length: workspaceCount
            }, (_, i) => i + 1).concat([activeWorkspace]);

        return Array.from({
            length: workspaceCount
        }, (_, i) => i + 1);
    }

    Repeater {
        model: root.workspaceIds

        delegate: Rectangle {
            required property int modelData

            readonly property bool isActive: root.activeWorkspace === modelData
            readonly property int workspaceId: modelData

            width: modelData >= 10 ? 26 : 20
            height: 20
            radius: 10
            color: isActive ? Theme.accent : "transparent"

            Text {
                anchors.centerIn: parent
                text: parent.workspaceId
                color: parent.isActive ? "#11111b" : Theme.muted
                font.pixelSize: 12
                font.bold: parent.isActive
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + parent.workspaceId + " })")
            }
        }
    }
}
