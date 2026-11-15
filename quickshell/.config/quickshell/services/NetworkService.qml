import Quickshell.Networking
import QtQuick

QtObject {
    readonly property var wifiDevice: Networking.devices.values.find(device => device.type === DeviceType.Wifi) ?? null

    readonly property var activeWifiNetwork: wifiDevice?.networks.values.find(network => network.connected) ?? null
}
