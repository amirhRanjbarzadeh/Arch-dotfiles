pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../components"
import "../styles"

// Power menu: the island in the middle of the screen with one big button per action.
// Keys: ←/→ (or Tab) to pick, Enter to run, or the underlined letter directly.
Item {
    id: root

    signal closeRequested

    readonly property var actions: [
        { name: "Lock", key: Qt.Key_L, icon: Icons.lock, danger: false,
          command: "loginctl lock-session" },
        { name: "Suspend", key: Qt.Key_S, icon: Icons.sleep, danger: false,
          command: "systemctl suspend" },
        { name: "Logout", key: Qt.Key_O, icon: Icons.logout, danger: false,
          command: "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'" },
        { name: "Reboot", key: Qt.Key_R, icon: Icons.restart, danger: true,
          command: "systemctl reboot" },
        { name: "Power off", key: Qt.Key_P, icon: Icons.power, danger: true,
          command: "systemctl poweroff" }
    ]

    property int selected: 0

    function run(index) {
        const action = actions[index];
        if (!action)
            return;
        root.closeRequested();
        // Let the island collapse first so the lock screen doesn't capture it mid-animation.
        Quickshell.execDetached(["sh", "-c", "sleep 0.3; " + action.command]);
    }

    function formatUptime(seconds) {
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor(seconds % 86400 / 3600);
        const minutes = Math.floor(seconds % 3600 / 60);
        if (days > 0)
            return days + "d " + hours + "h";
        return hours > 0 ? hours + "h " + minutes + "m" : minutes + "m";
    }

    implicitWidth: buttons.implicitWidth + 2 * card.padding
    implicitHeight: column.implicitHeight + 2 * card.padding

    onVisibleChanged: {
        if (visible) {
            selected = 0;
            uptimeFile.reload();
            forceActiveFocus();
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_Backtab:
            selected = (selected + actions.length - 1) % actions.length;
            break;
        case Qt.Key_Right:
        case Qt.Key_Tab:
            selected = (selected + 1) % actions.length;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            run(selected);
            break;
        case Qt.Key_Escape:
            root.closeRequested();
            break;
        default:
            const index = actions.findIndex(action => action.key === event.key);
            if (index < 0)
                return;
            run(index);
        }
        event.accepted = true;
    }

    Card {
        id: card

        anchors.fill: parent
        padding: 18

        ColumnLayout {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 14

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    const seconds = parseFloat(uptimeFile.text());
                    return isNaN(seconds) ? "Power" : "Up " + root.formatUptime(seconds);
                }
                color: Theme.muted
                font.pixelSize: 11
            }

            Row {
                id: buttons

                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                Repeater {
                    model: root.actions

                    delegate: Item {
                        id: button

                        required property var modelData
                        required property int index
                        readonly property bool current: root.selected === index
                        readonly property color tint: modelData.danger ? Theme.error : Theme.accent

                        width: 84
                        height: 92

                        Rectangle {
                            id: tile

                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            width: 64
                            height: 64
                            radius: 20
                            color: button.current ? button.tint : Theme.surface
                            border.width: 1
                            border.color: button.current ? button.tint : Theme.border
                            scale: mouseArea.pressed ? 0.94 : 1

                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on scale { NumberAnimation { duration: 90 } }

                            Text {
                                anchors.centerIn: parent
                                text: button.modelData.icon
                                color: button.current ? Theme.accentText : button.tint
                                font.pixelSize: 26

                                Behavior on color { ColorAnimation { duration: 140 } }
                            }
                        }

                        // Label with the shortcut letter underlined.
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            textFormat: Text.StyledText
                            text: {
                                const name = button.modelData.name;
                                const letter = String.fromCharCode(button.modelData.key).toLowerCase();
                                const at = name.toLowerCase().indexOf(letter);
                                return at < 0 ? name : name.slice(0, at) + "<u>" + name[at] + "</u>" + name.slice(at + 1);
                            }
                            color: button.current ? Theme.text : Theme.subtle
                            font.pixelSize: 11
                            font.bold: button.current
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selected = button.index
                            onClicked: root.run(button.index)
                        }
                    }
                }
            }
        }
    }
}
