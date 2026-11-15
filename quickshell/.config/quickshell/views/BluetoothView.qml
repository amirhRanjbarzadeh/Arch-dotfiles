import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Layouts

import "../styles"

Item {
    id: root
    property var barWindow
    property var adapter

    implicitWidth: 250
    implicitHeight: 190

    Rectangle {
        anchors.fill: parent

        radius: 14
        color: Theme.popupBackground

        border {
            width: 1
            color: Theme.border
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadow
            shadowBlur: 0.8
            shadowVerticalOffset: 7
            shadowScale: 1.03
        }

        Column {
            anchors.fill: parent
            anchors.margins: 14

            spacing: 12

            // Header

            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: "Bluetooth"
                    color: Theme.text
                    font.pixelSize: 13
                    font.bold: true

                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: parent.width - 145
                    height: 1
                }

                Text {
                    text: root.adapter?.enabled ? "ON" : "OFF"

                    color: root.adapter?.enabled ? Theme.success : Theme.muted

                    font.pixelSize: 11

                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: root.adapter?.enabled ? "●" : "○"

                    color: root.adapter?.enabled ? Theme.success : Theme.error

                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent

                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (root.adapter) {
                                root.adapter.enabled = !root.adapter.enabled;
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            // Device list

            ListView {
                id: bluetoothDeviceList

                width: parent.width
                height: 125

                clip: true
                spacing: 6

                model: root.adapter ? root.adapter.devices : null

                delegate: Rectangle {
                    required property var modelData

                    width: bluetoothDeviceList.width
                    height: 43

                    radius: 8
                    color: Theme.surface

                    Row {
                        anchors.fill: parent

                        anchors.leftMargin: 10
                        anchors.rightMargin: 10

                        spacing: 8

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            width: parent.width - 75
                            spacing: 3

                            Text {
                                width: parent.width

                                text: modelData.name

                                color: Theme.text
                                font.pixelSize: 11

                                elide: Text.ElideRight
                            }

                            Text {
                                text: {
                                    if (modelData.pairing)
                                        return "Pairing...";

                                    switch (modelData.state) {
                                    case BluetoothDeviceState.Connected:
                                        return "Connected";
                                    case BluetoothDeviceState.Connecting:
                                        return "Connecting...";
                                    case BluetoothDeviceState.Disconnecting:
                                        return "Disconnecting...";
                                    case BluetoothDeviceState.Disconnected:
                                        return "Disconnected";
                                    default:
                                        return "Unknown";
                                    }
                                }

                                color: {
                                    if (modelData.pairing || modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting)
                                        return Theme.warning;

                                    return modelData.state === BluetoothDeviceState.Connected ? Theme.success : Theme.muted;
                                }

                                font.pixelSize: 9
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter

                            visible: modelData.batteryAvailable && modelData.connected

                            text: Math.round(modelData.battery * 100) + "%"

                            color: Theme.subtle
                            font.pixelSize: 10
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter

                            text: modelData.connected ? "−" : "+"

                            color: Theme.accent
                            font.pixelSize: 17

                            MouseArea {
                                anchors.fill: parent

                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    if (modelData.connected)
                                        modelData.disconnect();
                                    else
                                        modelData.connect();
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent

                    visible: bluetoothDeviceList.count === 0

                    text: "No Bluetooth devices found"

                    color: Theme.muted
                    font.pixelSize: 11
                }
            }
        }
    }
}
