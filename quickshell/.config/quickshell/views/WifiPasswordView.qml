import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../styles"

// Password prompt for a secured network. Visible while `selectedWifiNetwork`
// is set; emits cancelRequested whenever it closes so the owner can clear it.
PopupWindow {
    id: root

    property var selectedWifiNetwork: null
    property string passwordError: ""
    property bool connecting: false
    signal cancelRequested

    color: "transparent"
    implicitWidth: 270
    implicitHeight: content.implicitHeight + 2 * Theme.popupPadding
    visible: selectedWifiNetwork !== null
    grabFocus: true

    function submit() {
        if (!selectedWifiNetwork || passwordField.text.length === 0 || connecting)
            return;
        passwordError = "";
        connecting = true;
        selectedWifiNetwork.connectWithPsk(passwordField.text);
    }

    onVisibleChanged: {
        passwordField.text = "";
        passwordError = "";
        connecting = false;
        if (visible)
            passwordField.forceActiveFocus();
        else
            cancelRequested();
    }

    Connections {
        target: root.selectedWifiNetwork
        ignoreUnknownSignals: true

        function onConnectionFailed(reason) {
            root.passwordError = reason === ConnectionFailReason.NoSecrets ? "Wrong password" : reason === ConnectionFailReason.WifiAuthTimeout ? "Authentication timed out" : "Connection failed";
            root.connecting = false;
            passwordField.selectAll();
            passwordField.forceActiveFocus();
        }
    }

    Card {
        anchors.fill: parent
        shadowEnabled: false

        ColumnLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 10

            Text {
                text: "Connect to Wi-Fi"
                color: Theme.text
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: root.selectedWifiNetwork?.name ?? ""
                color: Theme.accent
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            TextField {
                id: passwordField

                Layout.fillWidth: true
                implicitHeight: 34

                placeholderText: "Password"
                placeholderTextColor: Theme.muted
                echoMode: TextInput.Password
                enabled: !root.connecting
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText

                background: Rectangle {
                    radius: 7
                    color: Theme.surface
                    border.width: 1
                    border.color: passwordField.activeFocus ? Theme.accent : Theme.border
                }

                onAccepted: root.submit()
                Keys.onEscapePressed: root.cancelRequested()
            }

            Text {
                Layout.fillWidth: true
                visible: root.passwordError !== ""
                text: root.passwordError
                color: Theme.error
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item {
                    Layout.fillWidth: true
                }

                ActionButton {
                    text: "Cancel"
                    onClicked: root.cancelRequested()
                }

                ActionButton {
                    primary: true
                    text: root.connecting ? "Connecting…" : "Connect"
                    enabled: passwordField.text.length > 0 && !root.connecting && !(root.selectedWifiNetwork?.stateChanging ?? false)
                    onClicked: root.submit()
                }
            }
        }
    }
}
