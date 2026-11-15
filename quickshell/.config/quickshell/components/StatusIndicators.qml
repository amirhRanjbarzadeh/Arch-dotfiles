import QtQuick
import QtQuick.Controls
import "../styles"

Row {
    id: root

    property var activeWifiNetwork: null
    property var audioSink: null
    property var adapter: null
    signal wifiRequested
    signal volumeRequested
    signal bluetoothRequested

    spacing: 7

    // ----------------------------------
    // WI-FI ICON
    // ----------------------------------

    Text {
        id: wifiIcon

        anchors.verticalCenter: parent.verticalCenter

        text: {
            if (!root.activeWifiNetwork)
                return "󰤭";

            const strength = root.activeWifiNetwork.signalStrength;

            if (strength < 0.25)
                return "󰤟";

            if (strength < 0.50)
                return "󰤢";

            if (strength < 0.75)
                return "󰤥";

            return "󰤨";
        }

        color: root.activeWifiNetwork ? Theme.text : Theme.muted

        font.pixelSize: 14

        MouseArea {
            id: wifiMouseArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                root.wifiRequested();
            }
        }

        ToolTip.visible: wifiMouseArea.containsMouse

        ToolTip.text: root.activeWifiNetwork ? root.activeWifiNetwork.name + " · " + Math.round(root.activeWifiNetwork.signalStrength * 100) + "%" : "Disconnected"
    }

    // ----------------------------------
    // VOLUME ICON
    // ----------------------------------

    Text {
        id: volumeIcon

        anchors.verticalCenter: parent.verticalCenter

        text: {
            if (!root.audioSink?.audio)
                return "?";

            if (root.audioSink.audio.muted)
                return "󰖁";

            if (root.audioSink.audio.volume < 0.01)
                return "󰕿";

            return "󰕾";
        }

        color: root.audioSink?.audio?.muted ? Theme.error : Theme.text

        font.pixelSize: 14

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                root.volumeRequested();
            }
        }
    }

    // ----------------------------------
    // BLUETOOTH ICON
    // ----------------------------------

    Text {
        id: bluetoothIcon

        anchors.verticalCenter: parent.verticalCenter

        text: "󰂯"

        color: {
            if (!root.adapter)
                return Theme.error;

            return root.adapter.enabled ? Theme.accent : Theme.muted;
        }

        font.pixelSize: 15

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                root.bluetoothRequested();
            }
        }
    }
}
