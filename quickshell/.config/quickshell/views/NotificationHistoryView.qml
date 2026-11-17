pragma ComponentBehavior: Bound

import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import "../components"
import "../styles"

// Every notification still open, newest first. Click one to run its default
// action; × dismisses it; "Clear all" dismisses everything.
Item {
    id: root

    property var service // NotificationService
    readonly property var entries: service?.history ?? []

    // Ticks while open so "2m ago" labels stay current.
    property date now: new Date()

    function relativeTime(time) {
        const seconds = Math.max(0, Math.floor((now - time) / 1000));
        if (seconds < 60)
            return "now";
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60)
            return minutes + "m ago";
        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return hours + "h ago";
        return Qt.formatDateTime(time, "MMM d, hh:mm");
    }

    function activateDefault(notification) {
        const action = notification.actions.find(a => a.identifier === "default");
        if (action)
            action.invoke();
        if (notification.tracked)
            notification.dismiss();
    }

    implicitWidth: 380
    // Grow with the list up to a cap, then scroll.
    implicitHeight: Math.min(440, header.implicitHeight + 10 + 1 + 10 + Math.max(60, list.contentHeight)) + 2 * card.padding

    onVisibleChanged: {
        if (visible)
            now = new Date();
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.visible
        onTriggered: root.now = new Date()
    }

    Card {
        id: card

        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            RowLayout {
                id: header

                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "Notifications"
                    color: Theme.text
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: root.entries.length > 0 ? root.entries.length : ""
                    color: Theme.muted
                    font.pixelSize: 11
                }

                ActionButton {
                    visible: root.entries.length > 0
                    implicitHeight: 24
                    text: "Clear all"
                    onClicked: root.service.clearHistory()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.border
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true

                clip: true
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds
                model: root.entries

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    readonly property var notification: modelData.notification
                    readonly property bool critical: notification.urgency === NotificationUrgency.Critical

                    width: list.width
                    height: rowContent.implicitHeight + 16
                    radius: Theme.itemRadius
                    color: rowMouse.containsMouse ? Theme.border : Theme.surface
                    border.width: critical ? 1 : 0
                    border.color: Theme.error

                    Behavior on color { ColorAnimation { duration: 120 } }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activateDefault(row.notification)
                    }

                    RowLayout {
                        id: rowContent

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 10

                        NotificationIcon {
                            Layout.alignment: Qt.AlignTop
                            size: 32
                            notification: row.notification
                            critical: row.critical
                            color: Theme.popupBackground
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    Layout.fillWidth: true
                                    text: row.notification.appName || "Notification"
                                    color: row.critical ? Theme.error : Theme.muted
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: root.relativeTime(row.modelData.time)
                                    color: Theme.muted
                                    font.pixelSize: 9
                                }

                                IconButton {
                                    implicitWidth: 18
                                    implicitHeight: 18
                                    icon: Icons.close
                                    iconSize: 11
                                    iconColor: Theme.muted
                                    onClicked: row.notification.dismiss()
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.notification.summary || row.notification.appName || ""
                                color: Theme.text
                                font.pixelSize: 11
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: row.notification.body
                                textFormat: Text.StyledText
                                color: Theme.subtle
                                linkColor: Theme.accent
                                font.pixelSize: 10
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                onLinkActivated: link => Qt.openUrlExternally(link)
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: Icons.bell + "  No notifications"
                    color: Theme.muted
                    font.pixelSize: 11
                }
            }
        }
    }
}
