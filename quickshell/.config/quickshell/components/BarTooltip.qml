import Quickshell
import QtQuick
import "../styles"

// Tooltip drawn in its own popup surface. QtQuick.Controls ToolTips are
// clipped to the 34px-tall bar window, so they never become visible there.
PopupWindow {
    id: root

    required property Item target
    property string text: ""
    property bool hovered: false
    property int delay: 450

    anchor.item: target
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 8

    color: "transparent"
    implicitWidth: label.implicitWidth + 18
    implicitHeight: label.implicitHeight + 10
    visible: false

    onHoveredChanged: {
        if (hovered) {
            showTimer.restart();
        } else {
            showTimer.stop();
            visible = false;
        }
    }

    onTextChanged: {
        if (text === "")
            visible = false;
    }

    Timer {
        id: showTimer
        interval: root.delay
        onTriggered: root.visible = root.text !== "" && root.target.visible
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.itemRadius
        color: Theme.background
        border.width: 1
        border.color: Theme.border

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: Theme.text
            font.pixelSize: 11
        }
    }
}
