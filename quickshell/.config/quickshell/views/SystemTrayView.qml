pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import "../components"
import "../styles"

Item {
    id: root

    property bool open: false
    property bool nativeMenuOpen: false
    readonly property int trayCount: SystemTray.items.values.length

    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }

    Row {
        anchors.centerIn: parent
        height: Theme.barHeight
        spacing: 6

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: trayDelegate

                required property var modelData
                readonly property var trayItem: modelData

                width: 30
                height: Theme.barHeight

                Rectangle {
                    id: iconTile

                    width: 28
                    height: 28
                    radius: Theme.itemRadius
                    anchors.centerIn: parent
                    color: trayMouseArea.containsMouse ? Theme.surface : "transparent"

                    IconImage {
                        id: iconImage
                        anchors.centerIn: parent
                        implicitSize: 20
                        source: trayDelegate.trayItem.icon
                        mipmap: true
                        visible: source.toString() !== "" && status !== Image.Error
                    }

                    // Fallback: first letter of the app name when the icon can't load
                    Text {
                        anchors.centerIn: parent
                        visible: !iconImage.visible
                        text: (trayDelegate.trayItem.title || trayDelegate.trayItem.id || "?").charAt(0).toUpperCase()
                        color: Theme.accent
                        font.pixelSize: 14
                        font.bold: true
                    }

                    QsMenuAnchor {
                        id: nativeMenu
                        menu: trayDelegate.trayItem.menu
                        anchor.item: iconTile
                        anchor.edges: Edges.Bottom
                        anchor.gravity: Edges.Bottom
                        onOpened: root.nativeMenuOpen = true
                        onClosed: root.nativeMenuOpen = false
                    }

                    MouseArea {
                        id: trayMouseArea

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor

                        onClicked: mouse => {
                            const item = trayDelegate.trayItem;
                            if (mouse.button === Qt.LeftButton) {
                                if (item.onlyMenu && item.hasMenu)
                                    nativeMenu.open();
                                else
                                    item.activate();
                            } else if (mouse.button === Qt.RightButton && item.hasMenu) {
                                nativeMenu.open();
                            } else if (mouse.button === Qt.MiddleButton) {
                                item.secondaryActivate();
                            }
                        }
                        // No onWheel: scrolling over tray icons switches the bar back to status.
                    }

                    BarTooltip {
                        target: iconTile
                        text: trayDelegate.trayItem.tooltipTitle || trayDelegate.trayItem.title || ""
                        hovered: trayMouseArea.containsMouse && !root.nativeMenuOpen
                    }
                }
            }
        }

        Text {
            visible: root.trayCount === 0
            anchors.verticalCenter: parent.verticalCenter
            text: "No tray applications"
            color: Theme.muted
            font.pixelSize: 11
        }
    }
}
