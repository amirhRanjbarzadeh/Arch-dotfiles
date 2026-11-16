pragma ComponentBehavior: Bound

import Quickshell.Networking
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../styles"

Item {
    id: root

    property var wifiDevice
    property var activeWifiNetwork
    signal passwordRequested(var network)

    // Network name -> failure message. Kept here (not in delegates) so it survives list re-sorts.
    property var failures: ({})

    // Sorted snapshot of the network list. Re-sorted when networks appear/disappear,
    // not on every signal-strength tick, so rows don't jump around under the cursor.
    property var sortedNetworks: []

    implicitWidth: 270
    implicitHeight: 250

    function failureText(reason) {
        switch (reason) {
        case ConnectionFailReason.NoSecrets:
            return "Wrong password";
        case ConnectionFailReason.WifiAuthTimeout:
            return "Authentication timed out";
        case ConnectionFailReason.WifiNetworkLost:
            return "Network lost";
        default:
            return "Connection failed";
        }
    }

    function setFailure(name, message) {
        const next = Object.assign({}, failures);
        if (message)
            next[name] = message;
        else
            delete next[name];
        failures = next;
    }

    function resortNetworks() {
        const networks = Array.from(wifiDevice?.networks.values ?? []).filter(network => network.name !== "");
        networks.sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength));
        sortedNetworks = networks;
    }

    // Scan only while the panel is open; scanning in the background drains the battery.
    function syncScanner() {
        if (wifiDevice)
            wifiDevice.scannerEnabled = visible;
    }

    onVisibleChanged: {
        syncScanner();
        if (visible)
            resortNetworks();
    }
    onWifiDeviceChanged: {
        syncScanner();
        resortNetworks();
    }
    onActiveWifiNetworkChanged: resortNetworks()
    Component.onCompleted: resortNetworks()

    Connections {
        target: root.wifiDevice?.networks ?? null
        function onValuesChanged() {
            root.resortNetworks();
        }
    }

    Card {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            // Header + current connection
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: "Wi-Fi"
                    color: Theme.text
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: root.activeWifiNetwork ? root.activeWifiNetwork.name : "Not connected"
                    color: root.activeWifiNetwork ? Theme.accent : Theme.muted
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    text: root.activeWifiNetwork ? Math.round(root.activeWifiNetwork.signalStrength * 100) + "% signal" : "No active connection"
                    color: Theme.subtle
                    font.pixelSize: 10
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "AVAILABLE NETWORKS"
                    color: Theme.muted
                    font.pixelSize: 9
                }

                BusyIndicator {
                    implicitWidth: 14
                    implicitHeight: 14
                    padding: 0
                    running: root.wifiDevice?.scannerEnabled ?? false
                    visible: running
                }
            }

            // Network list
            ListView {
                id: networkList

                Layout.fillWidth: true
                Layout.fillHeight: true

                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: root.sortedNetworks

                delegate: Rectangle {
                    id: networkRow

                    required property var modelData
                    readonly property var network: modelData
                    readonly property string failure: root.failures[network.name] ?? ""
                    readonly property bool secured: network.security !== WifiSecurityType.Open
                    readonly property bool canSelect: !network.connected && !network.stateChanging

                    width: networkList.width
                    height: 26
                    radius: 6
                    color: rowMouse.containsMouse && canSelect ? Theme.surface : "transparent"

                    Connections {
                        target: networkRow.network
                        function onConnectionFailed(reason) {
                            root.setFailure(networkRow.network.name, root.failureText(reason));
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 6

                        Item {
                            implicitWidth: 16
                            implicitHeight: 16

                            BusyIndicator {
                                anchors.fill: parent
                                padding: 0
                                running: networkRow.network.stateChanging
                                visible: running
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !networkRow.network.stateChanging
                                text: Icons.wifiLevels[Math.min(3, Math.floor(networkRow.network.signalStrength * 4))]
                                color: networkRow.failure !== "" ? Theme.error : networkRow.network.connected ? Theme.success : Theme.accent
                                font.pixelSize: 14
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (networkRow.network.stateChanging)
                                    return networkRow.network.name + "  · Connecting…";
                                if (networkRow.failure !== "")
                                    return networkRow.network.name + "  · " + networkRow.failure;
                                return networkRow.network.name;
                            }
                            color: {
                                if (networkRow.network.connected)
                                    return Theme.success;
                                if (networkRow.failure !== "")
                                    return Theme.error;
                                return networkRow.network.stateChanging ? Theme.warning : Theme.text;
                            }
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: networkRow.network.connected
                            text: Icons.check
                            color: Theme.success
                            font.pixelSize: 12
                        }

                        Text {
                            visible: networkRow.secured && !networkRow.network.connected
                            text: Icons.lock
                            color: Theme.muted
                            font.pixelSize: 10
                        }

                        Text {
                            Layout.preferredWidth: 30
                            text: Math.round(networkRow.network.signalStrength * 100) + "%"
                            color: Theme.muted
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    MouseArea {
                        id: rowMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: networkRow.canSelect ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onClicked: {
                            if (!networkRow.canSelect)
                                return;
                            root.setFailure(networkRow.network.name, "");
                            if (networkRow.network.known || !networkRow.secured)
                                networkRow.network.connect();
                            else
                                root.passwordRequested(networkRow.network);
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: networkList.count === 0
                    text: !root.wifiDevice ? "No Wi-Fi device" : root.wifiDevice.scannerEnabled ? "Scanning for networks…" : "No networks found"
                    color: Theme.muted
                    font.pixelSize: 11
                }
            }
        }
    }
}
