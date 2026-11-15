import Quickshell.Hyprland
import QtQuick
import "../styles"

Item {
    id: root

    property int workspaceCount: 4
    property int activeWorkspace: Hyprland.focusedWorkspace?.id ?? 1

    property int itemSpacing: 5

    readonly property var workspaceIds: {
        if (activeWorkspace > workspaceCount)
            return Array.from({
                length: workspaceCount
            }, (_, i) => i + 1).concat([activeWorkspace]);

        return Array.from({
            length: workspaceCount
        }, (_, i) => i + 1);
    }

    readonly property int activeIndex: Math.max(0, workspaceIds.indexOf(activeWorkspace))
    readonly property real activeX: {
        let x = 0;
        for (let i = 0; i < activeIndex; i++)
            x += (workspaceIds[i] >= 10 ? 34 : 28) + itemSpacing;
        return x;
    }
    readonly property int activeWidth: activeWorkspace >= 10 ? 34 : 28

    width: workspaceRow.implicitWidth
    height: 20

    Rectangle {
        id: activePill
        x: root.activeX
        width: root.activeWidth
        height: root.height
        radius: height / 2
        color: Theme.accent

        Behavior on x {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }
    }

    Row {
        id: workspaceRow
        spacing: root.itemSpacing
        anchors.fill: parent

        Repeater {
            model: root.workspaceIds

            delegate: Item {
                required property int modelData

                readonly property bool isActive: root.activeWorkspace === modelData
                readonly property int workspaceId: modelData

                width: modelData >= 10 ? 34 : 28
                height: 20

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
}
