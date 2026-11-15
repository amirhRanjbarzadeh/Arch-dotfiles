import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../styles"

Item {
    id: root
    property var barWindow
    property var wifiDevice
    property var activeWifiNetwork
    signal passwordRequested(var network)

    implicitWidth: 250
    implicitHeight: 250

    onVisibleChanged: {
        if (visible && root.wifiDevice) {
            root.wifiDevice.scannerEnabled = true;
        }
    }

    Rectangle {
        anchors.fill: parent

        radius: 14
        color: Theme.background

        border {
            width: 1
            color: Theme.border
        }

        Column {
            anchors.fill: parent
            anchors.margins: 14

            spacing: 12

            // Header

            Text {
                text: "Wi-Fi Networks"

                color: Theme.text
                font.pixelSize: 13
                font.bold: true
            }

            // Current connection

            Column {
                spacing: 4

                Text {
                    text: "CONNECTED TO"

                    color: Theme.muted
                    font.pixelSize: 9
                }

                Text {
                    text: root.activeWifiNetwork ? root.activeWifiNetwork.name : "Not connected"

                    color: Theme.accent
                    font.pixelSize: 12
                    font.bold: true
                }

                Text {
                    text: root.activeWifiNetwork ? Math.round(root.activeWifiNetwork.signalStrength * 100) + "% signal" : "No active connection"

                    color: Theme.subtle
                    font.pixelSize: 10
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            // Available networks header + scanning indicator

            Row {
                width: parent.width
                height: 16
                spacing: 6

                Text {
                    text: "AVAILABLE NETWORKS"

                    color: Theme.muted
                    font.pixelSize: 9

                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: parent.width - 135
                    height: 1
                }

                BusyIndicator {
                    width: 15
                    height: 15

                    running: root.wifiDevice?.scannerEnabled ?? false
                    visible: running
                }
            }

            // Network list

            ListView {
                id: wifiNetworkList

                width: parent.width
                height: 125

                clip: true
                spacing: 8

                model: root.wifiDevice ? root.wifiDevice.networks : null

                delegate: Item {
                    id: networkDelegate

                    required property var modelData

                    readonly property bool canSelect: !modelData.connected && !modelData.stateChanging

                    property string failureMessage: ""

                    width: wifiNetworkList.width
                    height: 20

                    // Listen for connection failures

                    Connections {
                        target: networkDelegate.modelData
                        ignoreUnknownSignals: true

                        function onConnectionFailed(reason) {
                            networkDelegate.failureMessage = "Connection failed: " + reason;

                            console.log("Connection failed:", reason);
                        }
                    }

                    // Network row visuals

                    Row {
                        anchors.fill: parent
                        spacing: 6

                        BusyIndicator {
                            width: 16
                            height: 16

                            anchors.verticalCenter: parent.verticalCenter

                            running: modelData.stateChanging
                            visible: modelData.stateChanging
                        }

                        Text {
                            width: 16

                            anchors.verticalCenter: parent.verticalCenter

                            visible: !modelData.stateChanging

                            text: modelData.connected ? "󰤨" : "󰤯"

                            color: networkDelegate.failureMessage !== "" ? Theme.error : Theme.accent

                            font.pixelSize: 14
                        }

                        Text {
                            width: parent.width - 58

                            anchors.verticalCenter: parent.verticalCenter

                            text: {
                                if (modelData.connected)
                                    return modelData.name + "  ✓";

                                if (modelData.stateChanging)
                                    return modelData.name + "  Connecting...";

                                if (networkDelegate.failureMessage !== "")
                                    return modelData.name + "  · Failed";

                                return modelData.name;
                            }

                            color: {
                                if (modelData.connected)
                                    return Theme.success;

                                if (networkDelegate.failureMessage !== "")
                                    return Theme.error;

                                if (modelData.stateChanging)
                                    return Theme.warning;

                                return Theme.text;
                            }

                            font.pixelSize: 11
                            elide: Text.ElideRight

                            ToolTip.visible: networkDelegate.failureMessage !== ""

                            ToolTip.text: networkDelegate.failureMessage
                        }

                        Text {
                            width: 30

                            anchors.verticalCenter: parent.verticalCenter

                            text: Math.round(modelData.signalStrength * 100) + "%"

                            color: Theme.muted
                            font.pixelSize: 10

                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    // Individual network click handler

                    MouseArea {
                        anchors.fill: parent

                        enabled: networkDelegate.canSelect

                        hoverEnabled: true

                        cursorShape: containsMouse && enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onClicked: {
                            networkDelegate.failureMessage = "";

                            if (modelData.connected || modelData.stateChanging)
                                return;
                            if (modelData.known || modelData.security === WifiSecurityType.Open) {
                                modelData.connect();

                                console.log("Connecting to:", modelData.name);
                            } else {
                                root.passwordRequested(modelData);

                                console.log("Password required:", modelData.name);
                            }
                        }
                    }
                }

                // Empty state: scanning is finished, no networks found

                Text {
                    anchors.centerIn: parent

                    visible: wifiNetworkList.count === 0 && !(root.wifiDevice?.scannerEnabled ?? false)

                    text: "No networks found"

                    color: Theme.muted
                    font.pixelSize: 11
                }

                // Loading state: scanner is active, no networks yet

                Text {
                    anchors.centerIn: parent

                    visible: wifiNetworkList.count === 0 && (root.wifiDevice?.scannerEnabled ?? false)

                    text: "Scanning for networks..."

                    color: Theme.subtle
                    font.pixelSize: 11
                }
            }
        }
    }
}
