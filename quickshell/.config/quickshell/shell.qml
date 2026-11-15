//@ pragma UseQApplication

import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Hyprland

import QtQuick
import "components"
import "views"
import "services"
import "styles"

PanelWindow {
    id: bar

    // ==========================================
    // WI-FI PASSWORD STATE
    // ==========================================

    property var selectedWifiNetwork: null
    property string activePanel: ""
    property bool trayPopupOpen: false
    readonly property bool islandExpanded: activePanel !== ""
    readonly property int islandHeight: activePanel === "wifi" ? 250 : activePanel === "bluetooth" ? 190 : activePanel === "volume" ? 78 : 34

    onActivePanelChanged: {
        if (islandExpanded) {
            trayPopupOpen = false;
            islandDismissTimer.restart();
            escapeHandler.forceActiveFocus();
        }
    }

    // ==========================================
    // NETWORK STATE
    // ==========================================

    NetworkService {
        id: networkService
    }

    Timer {
        id: islandDismissTimer
        interval: 5000
        repeat: false
        running: bar.islandExpanded
        onTriggered: bar.activePanel = ""
    }
    AudioService {
        id: audioService
    }

    Connections {
        target: audioService.sink?.audio ?? null

        function onVolumeChanged() {
            bar.activePanel = "volume";
            islandDismissTimer.restart();
        }

        function onMutedChanged() {
            bar.activePanel = "volume";
            islandDismissTimer.restart();
        }
    }

    BluetoothService {
        id: bluetoothService
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property var wifiDevice: networkService.wifiDevice
    readonly property var activeWifiNetwork: networkService.activeWifiNetwork

    onActiveWifiNetworkChanged: {
        console.log("Active Wi-Fi:", activeWifiNetwork?.name ?? "Disconnected");

        if (activeWifiNetwork && selectedWifiNetwork && activeWifiNetwork.name === selectedWifiNetwork.name) {
            wifiPasswordView.connecting = false;
            wifiPasswordView.visible = false;
            selectedWifiNetwork = null;
        }
    }

    // ==========================================
    // MAIN WINDOW
    // ==========================================

    anchors {
        top: true
    }

    margins.top: 6

    implicitWidth: 520
    implicitHeight: islandExpanded ? islandHeight + 12 : (trayPopupOpen ? 68 : 34)
    // Reserve only the collapsed bar height so expanding the island doesn't
    // reduce the usable tiled area in Hyprland.
    exclusiveZone: 34
    Behavior on implicitHeight { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    color: "transparent"

    HyprlandFocusGrab {
        active: (bar.islandExpanded || bar.trayPopupOpen) && !systemTrayView.nativeMenuOpen
        windows: [bar, wifiPasswordView]
        onCleared: {
            bar.activePanel = "";
            if (!systemTrayView.nativeMenuOpen)
                bar.trayPopupOpen = false;
        }
    }

    Item {
        id: escapeHandler
        focus: bar.islandExpanded
        Keys.onEscapePressed: bar.activePanel = ""
    }

    Rectangle {
        visible: bar.height > 34 && !bar.islandExpanded
        width: bar.width
        height: bar.height
        radius: 17
        color: Theme.background
        border.width: 1
        border.color: Theme.border
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Island {
        id: island
        width: bar.islandExpanded ? (bar.activePanel === "volume" ? 240 : 270) : bar.width
        height: bar.islandExpanded ? bar.islandHeight : 34
        backgroundVisible: bar.islandExpanded || bar.height <= 34
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        WorkspaceSection {
            visible: !bar.islandExpanded
            anchors {
                left: parent.left
                leftMargin: 18
                verticalCenter: parent.verticalCenter
            }
        }

        Clock {
            visible: !bar.islandExpanded
            anchors.centerIn: parent
        }

        StatusIndicators {
            visible: !bar.islandExpanded
            anchors {
                right: parent.right
                rightMargin: 18
                verticalCenter: parent.verticalCenter
            }

            activeWifiNetwork: bar.activeWifiNetwork
            audioSink: audioService.sink
            adapter: bluetoothService.adapter
            onWifiRequested: bar.activePanel = bar.activePanel === "wifi" ? "" : "wifi"
            onVolumeRequested: bar.activePanel = bar.activePanel === "volume" ? "" : "volume"
            onBluetoothRequested: bar.activePanel = bar.activePanel === "bluetooth" ? "" : "bluetooth"
            trayOpen: bar.trayPopupOpen
            onTrayRequested: bar.trayPopupOpen = !bar.trayPopupOpen
        }
    }

    Island {
        id: trayRow
        visible: height > 0
        width: bar.width
        height: bar.trayPopupOpen && !bar.islandExpanded ? 34 : 0
        backgroundVisible: false
        anchors.horizontalCenter: parent.horizontalCenter
        y: 34

        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        SystemTrayView {
            id: systemTrayView
            anchors.fill: parent
            barWindow: bar
        }
    }

    WifiView {
        id: wifiView
        barWindow: bar
        wifiDevice: networkService.wifiDevice
        activeWifiNetwork: networkService.activeWifiNetwork
        visible: bar.activePanel === "wifi"
        width: island.width
        height: island.height
        anchors.centerIn: island
        onPasswordRequested: network => {
            bar.selectedWifiNetwork = network;
            wifiPasswordView.passwordError = "";
            wifiPasswordView.connecting = false;
            wifiPasswordView.visible = true;
        }
    }

    WifiPasswordView {
        id: wifiPasswordView
        barWindow: bar
        selectedWifiNetwork: bar.selectedWifiNetwork
        anchor.rect.x: bar.width - width - 18
        anchor.rect.y: bar.height + 8
        onCancelRequested: bar.selectedWifiNetwork = null
    }

    VolumeView {
        id: volumeView
        barWindow: bar
        audioSink: audioService.sink
        visible: bar.activePanel === "volume"
        width: island.width
        height: island.height
        anchors.centerIn: island
    }

    BluetoothView {
        id: bluetoothView
        barWindow: bar
        adapter: bluetoothService.adapter
        visible: bar.activePanel === "bluetooth"
        width: island.width
        height: island.height
        anchors.centerIn: island
    }

}
