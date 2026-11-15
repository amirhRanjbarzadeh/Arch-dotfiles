import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../styles"

PopupWindow {
    id: root
    property var barWindow
    property var selectedWifiNetwork
    property string passwordError: ""
    property bool connecting: false
    signal cancelRequested

    anchor.window: root.barWindow
    anchor.rect.x: root.barWindow.width - width - 18
    anchor.rect.y: root.barWindow.height + 8

    color: "transparent"

    implicitWidth: 270
    implicitHeight: 180

    visible: false
    grabFocus: true

    onVisibleChanged: {
        if (visible) {
            passwordField.text = "";
            root.passwordError = "";
            root.connecting = false;
            passwordField.forceActiveFocus();
        } else {
            root.connecting = false;
        }
    }

    // Listen for authentication failures

    Connections {
        target: root.selectedWifiNetwork
        ignoreUnknownSignals: true

        function onConnectionFailed(reason) {
            root.passwordError = "Connection failed: " + reason;

            root.connecting = false;

            console.log("Wi-Fi authentication failed:", reason);
        }
    }

    Rectangle {
        anchors.fill: parent

        radius: 14
        color: Theme.background

        border {
            width: 1
            color: Theme.border
        }

        Column {
            anchors.fill: parent
            anchors.margins: 14

            spacing: 10

            Text {
                text: "Connect to Wi-Fi"

                color: Theme.text
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                text: root.selectedWifiNetwork ? root.selectedWifiNetwork.name : ""

                color: Theme.accent
                font.pixelSize: 11
                elide: Text.ElideRight

                width: parent.width
            }

            TextField {
                id: passwordField

                width: parent.width
                height: 34

                placeholderText: "Enter Wi-Fi password"
                echoMode: TextInput.Password

                enabled: !root.connecting

                color: Theme.text

                background: Rectangle {
                    radius: 7
                    color: Theme.surface

                    border {
                        width: 1
                        color: "#45475a"
                    }
                }

                onAccepted: connectButton.clicked()
            }

            Text {
                width: parent.width

                visible: root.passwordError !== ""

                text: root.passwordError

                color: Theme.error
                font.pixelSize: 10

                wrapMode: Text.WordWrap
            }

            Row {
                width: parent.width
                spacing: 8

                Item {
                    width: parent.width - 148
                    height: 1
                }

                Button {
                    text: "Cancel"

                    onClicked: {
                        root.visible = false;
                        root.cancelRequested();
                    }
                }

                Button {
                    id: connectButton

                    text: root.connecting ? "Connecting..." : "Connect"

                    enabled: passwordField.text.length > 0 && root.selectedWifiNetwork !== null && !root.connecting && !root.selectedWifiNetwork.stateChanging

                    onClicked: {
                        if (!root.selectedWifiNetwork)
                            return;
                        root.passwordError = "";
                        root.connecting = true;

                        root.selectedWifiNetwork.connectWithPsk(passwordField.text);

                        console.log("Authenticating:", root.selectedWifiNetwork.name);
                    }
                }
            }
        }
    }
}
