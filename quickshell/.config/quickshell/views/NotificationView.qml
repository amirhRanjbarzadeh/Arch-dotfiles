pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../components"
import "../styles"

// A single notification shown inside the island.
Item {
    id: root

    property var notification: null
    // How many more notifications are queued behind this one.
    property int pendingCount: 0

    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property var buttons: (notification?.actions ?? []).filter(action => action.identifier !== "default" && action.text !== "")

    // Inline image (avatars, screenshots) wins; then the app icon, desktop entry and app name.
    // Theme icon names are checked so a missing icon falls through instead of
    // rendering the checkerboard "missing" texture.
    function resolveIcon(icon) {
        if (!icon)
            return "";
        if (icon.startsWith("image://icon/"))
            icon = icon.slice("image://icon/".length);
        else if (icon.startsWith("/"))
            return "file://" + icon;
        else if (icon.includes("://"))
            return icon;
        return Quickshell.iconPath(icon, true);
    }

    readonly property string iconSource: {
        const n = notification;
        if (!n)
            return "";
        return resolveIcon(n.image) || resolveIcon(n.appIcon) || resolveIcon(n.desktopEntry) || resolveIcon(n.appName.toLowerCase());
    }

    implicitWidth: 380
    implicitHeight: content.implicitHeight + 2 * card.padding

    function activateDefault() {
        const n = notification;
        if (!n)
            return;
        const action = n.actions.find(a => a.identifier === "default");
        if (action)
            action.invoke();
        if (n.tracked)
            n.dismiss();
    }

    function invoke(action) {
        const n = notification;
        action.invoke();
        if (n && n.tracked && !n.resident)
            n.dismiss();
    }

    Card {
        id: card

        anchors.fill: parent
        padding: 12
        border.color: root.critical ? Theme.error : Theme.border

        // Clicking the card itself runs the default action (usually focuses the app).
        MouseArea {
            anchors.fill: parent
            anchors.margins: -card.padding
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activateDefault()
        }

        RowLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 12

            // Icon / image
            ClippingRectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 40
                implicitHeight: 40
                radius: 10
                color: Theme.surface

                Image {
                    id: iconImage
                    anchors.fill: parent
                    source: root.iconSource
                    sourceSize.width: 80
                    sourceSize.height: 80
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: !iconImage.visible
                    text: Icons.bell
                    color: root.critical ? Theme.error : Theme.accent
                    font.pixelSize: 20
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                // App name, queue count, close
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: root.notification?.appName || "Notification"
                        color: root.critical ? Theme.error : Theme.muted
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        visible: root.pendingCount > 0
                        implicitWidth: moreLabel.implicitWidth + 12
                        implicitHeight: 16
                        radius: 8
                        color: Theme.surface

                        Text {
                            id: moreLabel
                            anchors.centerIn: parent
                            text: "+" + root.pendingCount
                            color: Theme.subtle
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }

                    IconButton {
                        implicitWidth: 20
                        implicitHeight: 20
                        icon: Icons.close
                        iconSize: 12
                        iconColor: Theme.muted
                        onClicked: root.notification?.dismiss()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.notification?.summary || root.notification?.appName || ""
                    color: Theme.text
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.notification?.body ?? ""
                    textFormat: Text.StyledText
                    color: Theme.subtle
                    linkColor: Theme.accent
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }

                // Action buttons
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    visible: root.buttons.length > 0
                    spacing: 6

                    Repeater {
                        model: root.buttons.slice(0, 3)

                        delegate: ActionButton {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            text: modelData.text
                            primary: index === 0
                            onClicked: root.invoke(modelData)
                        }
                    }
                }
            }
        }
    }
}
