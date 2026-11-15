import Quickshell.Bluetooth
import QtQuick

QtObject {
    readonly property var adapter: Bluetooth.defaultAdapter
}
