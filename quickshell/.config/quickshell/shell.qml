import Quickshell
import Quickshell.Services.Pipewire

import QtQuick
import "components"
import "views"
import "services"

PanelWindow {
    id: bar

    // ==========================================
    // WI-FI PASSWORD STATE
    // ==========================================

    property var selectedWifiNetwork: null

    // ==========================================
    // NETWORK STATE
    // ==========================================

    NetworkService {
        id: networkService
    }
    AudioService {
        id: audioService
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
    implicitHeight: 34

    color: "transparent"

    Island {
        anchors.fill: parent

        WorkspaceSection {
            anchors {
                left: parent.left
                leftMargin: 18
                verticalCenter: parent.verticalCenter
            }
        }

        Clock {
            anchors.centerIn: parent
        }

        StatusIndicators {
            anchors {
                right: parent.right
                rightMargin: 18
                verticalCenter: parent.verticalCenter
            }

            activeWifiNetwork: bar.activeWifiNetwork
            audioSink: audioService.sink
            adapter: bluetoothService.adapter
            onWifiRequested: wifiView.visible = !wifiView.visible
            onVolumeRequested: volumeView.visible = !volumeView.visible
            onBluetoothRequested: bluetoothView.visible = !bluetoothView.visible
        }
    }

    WifiView {
        id: wifiView
        barWindow: bar
        wifiDevice: networkService.wifiDevice
        activeWifiNetwork: networkService.activeWifiNetwork
        onPasswordRequested: network => {
            bar.selectedWifiNetwork = network;
            wifiPasswordView.passwordError = "";
            wifiPasswordView.connecting = false;
            wifiPasswordView.visible = true;
        }
        anchor.rect.x: bar.width - width - 18
        anchor.rect.y: bar.height + 8
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
        anchor.rect.x: bar.width - width - 18
        anchor.rect.y: bar.height + 8
    }

    BluetoothView {
        id: bluetoothView
        barWindow: bar
        adapter: bluetoothService.adapter
        anchor.rect.x: bar.width - width - 45
        anchor.rect.y: bar.height + 8
    }
}
