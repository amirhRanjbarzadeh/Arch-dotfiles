import Quickshell
import Quickshell.Services.SystemTray

import QtQuick
import QtQuick.Controls
import "../styles"

Item {
    id: root

    property var barWindow
    property bool nativeMenuOpen: false
    readonly property int trayCount: SystemTray.items.values.length

    opacity: barWindow?.trayPopupOpen ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        height: 34
        spacing: 6

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: trayDelegate
                required property var modelData
                readonly property var trayItem: modelData
                width: 30
                height: 34

                Rectangle {
                    id: iconTile
                    width: 28
                    height: 28
                    radius: 8
                    anchors.centerIn: parent
                    color: trayMouseArea.containsMouse ? Theme.surface : "transparent"

                    Image {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: trayDelegate.trayItem.icon
                        sourceSize.width: width
                        sourceSize.height: height
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        visible: source.toString() !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: trayDelegate.trayItem.icon.toString() === ""
                        text: (trayDelegate.trayItem.title || trayDelegate.trayItem.id || "?").charAt(0).toUpperCase()
                        color: Theme.accent
                        font.pixelSize: 14
                        font.bold: true
                    }

                    QsMenuAnchor {
                        id: nativeMenu
                        menu: trayDelegate.trayItem.menu
                        anchor.item: iconTile
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
                            if (mouse.button === Qt.LeftButton) {
                                if (trayDelegate.trayItem.onlyMenu && trayDelegate.trayItem.hasMenu)
                                    nativeMenu.open();
                                else
                                    trayDelegate.trayItem.activate();
                            } else if (mouse.button === Qt.RightButton && trayDelegate.trayItem.hasMenu) {
                                nativeMenu.open();
                            } else if (mouse.button === Qt.MiddleButton) {
                                trayDelegate.trayItem.secondaryActivate();
                            }
                        }
                        onWheel: wheel => {
                            const horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y);
                            const delta = horizontal ? wheel.angleDelta.x : wheel.angleDelta.y;
                            if (delta !== 0)
                                trayDelegate.trayItem.scroll(delta, horizontal);
                            wheel.accepted = true;
                        }
                        ToolTip.visible: containsMouse && trayDelegate.trayItem.title !== ""
                        ToolTip.delay: 500
                        ToolTip.text: trayDelegate.trayItem.tooltipTitle || trayDelegate.trayItem.title
                    }
                }
            }
        }

        Text {
            visible: root.trayCount === 0
            text: "No tray applications"
            color: Theme.muted
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
