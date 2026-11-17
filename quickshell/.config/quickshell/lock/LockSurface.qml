pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.UPower
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../components"
import "../styles"

// What one screen shows while locked. Enter: the desktop snapshot blurs, zooms
// and dims while the bar pill, clock, card and media pill arrive in turn.
// Unlock plays it backwards so the session comes back where it was.
Item {
    id: root

    required property var lock // LockScreen
    property string screenName: ""

    // Timelines, 0 → 1. Every element maps them through its own stage window.
    property real intro: 0
    property real outro: 0
    // Eases in and out of the idle state (card hidden, clock centered).
    property real idleT: lock.idle ? 1 : 0

    Behavior on idleT { NumberAnimation { duration: 700; easing.type: Easing.InOutCubic } }

    function stage(t, from, to) {
        return Math.max(0, Math.min(1, (t - from) / (to - from)));
    }

    function ease(x) {
        return 1 - Math.pow(1 - x, 3);
    }

    // How "in" an element is: rises during the intro window, falls during the outro window.
    function presence(inFrom, inTo, outFrom, outTo) {
        return ease(stage(intro, inFrom, inTo)) * (1 - ease(stage(outro, outFrom, outTo)));
    }

    readonly property real backdrop: presence(0, 0.55, 0.25, 1)
    readonly property real pillIn: presence(0.05, 0.4, 0.55, 1)
    readonly property real clockIn: presence(0.2, 0.7, 0, 0.45)
    readonly property real cardIn: presence(0.32, 0.85, 0, 0.4)
    readonly property real bottomIn: presence(0.45, 1, 0, 0.35)

    NumberAnimation {
        id: introAnim
        target: root
        property: "intro"
        from: 0
        to: 1
        duration: 1300
    }

    NumberAnimation {
        id: outroAnim
        target: root
        property: "outro"
        from: 0
        to: 1
        duration: root.lock.exitDuration
    }

    Connections {
        target: root.lock

        function onUnlockingChanged() {
            if (root.lock.unlocking)
                outroAnim.restart();
        }

        function onLockSerialChanged() {
            root.outro = 0;
            introAnim.restart();
        }
    }

    Component.onCompleted: {
        introAnim.start();
        forceActiveFocus();
    }

    // ==========================================
    // INPUT
    // ==========================================

    focus: true

    Keys.onPressed: event => {
        lock.wake();
        const ctrl = event.modifiers & Qt.ControlModifier;
        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
            lock.submit();
            break;
        case Qt.Key_Backspace:
            lock.backspace(ctrl);
            break;
        case Qt.Key_Escape:
            lock.backspace(true);
            break;
        default:
            if (ctrl && event.key === Qt.Key_U)
                lock.backspace(true);
            else if (!ctrl && event.text.length > 0 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127)
                lock.type(event.text);
        }
        event.accepted = true;
    }

    Keys.onReleased: event => {
        if (event.key === Qt.Key_CapsLock)
            lock.refreshCapsLock();
    }

    // Any pointer movement wakes the card back up; clicks give this screen focus.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: root.lock.wake()
        onPressed: {
            root.lock.wake();
            root.forceActiveFocus();
        }
    }

    // ==========================================
    // BACKGROUND
    // ==========================================

    Item {
        id: background

        anchors.fill: parent
        clip: true

        // Desktop snapshot taken just before locking, else the wallpaper.
        Image {
            id: snapshot

            anchors.fill: parent
            source: root.screenName !== "" ? root.lock.snapshotPath(root.screenName) : ""
            fillMode: Image.PreserveAspectCrop
            cache: false
            // Synchronous: the first frame must already be the desktop, not black.
            asynchronous: false
            visible: false
        }

        Image {
            id: wallpaper

            anchors.fill: parent
            source: root.lock.wallpaper !== "" ? "file://" + root.lock.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: root.width
            sourceSize.height: root.height
            asynchronous: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: snapshot.status === Image.Ready ? snapshot : wallpaper
            scale: 1 + 0.06 * root.backdrop
            blurEnabled: true
            blurMax: 64
            blur: root.backdrop
            saturation: 0.15 * root.backdrop
            brightness: -0.18 * root.backdrop - 0.08 * root.idleT
        }

        // Darken the middle and bottom so the text always reads.
        Rectangle {
            anchors.fill: parent
            opacity: root.backdrop
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.15) }
                GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.3) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.6) }
            }
        }
    }

    // ==========================================
    // TOP PILL: where the bar was
    // ==========================================

    Rectangle {
        id: pill

        readonly property var battery: UPower.displayDevice
        readonly property var wifi: root.lock.network?.activeWifiNetwork ?? null
        readonly property int unread: root.lock.notifications?.unreadCount ?? 0

        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barTopMargin
        // Same size as the bar, so it reads as the bar turning into the lock.
        width: Theme.barWidth
        height: Theme.barHeight
        radius: height / 2
        color: Theme.background
        border.width: 1
        border.color: Theme.border
        opacity: Math.min(1, root.pillIn * 2.5)

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            opacity: root.pillIn
            transform: Translate { x: -12 * (1 - root.pillIn) }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.lock.unlocking ? Icons.lockOpen : Icons.lock
                color: root.lock.unlocking ? Theme.success : Theme.accent
                font.pixelSize: 14
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.lock.unlocking ? "Unlocking" : "Locked"
                color: Theme.text
                font.pixelSize: 12
                font.bold: true
            }
        }

        Text {
            anchors.centerIn: parent
            opacity: root.pillIn
            text: root.lock.userName + (root.lock.hostName !== "" ? "@" + root.lock.hostName : "")
            color: Theme.muted
            font.pixelSize: 11
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            opacity: root.pillIn
            transform: Translate { x: 12 * (1 - root.pillIn) }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: pill.unread > 0
                spacing: 4

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.bell
                    color: Theme.accent
                    font.pixelSize: 13
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: pill.unread
                    color: Theme.text
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.wifi ? Icons.wifiLevels[Math.min(3, Math.floor(pill.wifi.signalStrength * 4))] : Icons.wifiOff
                color: pill.wifi ? Theme.text : Theme.muted
                font.pixelSize: 14
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: pill.battery.ready && pill.battery.isLaptopBattery
                spacing: 4

                readonly property bool charging: pill.battery.state === UPowerDeviceState.Charging || pill.battery.state === UPowerDeviceState.FullyCharged

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.charging ? Icons.batteryCharging : Icons.batteryLevels[Math.min(9, Math.floor(pill.battery.percentage * 10))]
                    color: parent.charging ? Theme.success : pill.battery.percentage < 0.15 ? Theme.error : Theme.text
                    font.pixelSize: 14
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(pill.battery.percentage * 100) + "%"
                    color: Theme.text
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }

    // ==========================================
    // CLOCK
    // ==========================================

    LockClock {
        id: clock

        anchors.horizontalCenter: parent.horizontalCenter
        // Drops into place; settles lower (toward the middle) when idle.
        y: Math.round(root.height / 2 - height - 40 + 110 * root.idleT - 40 * (1 - root.clockIn) - 60 * root.outro)
        name: root.lock.displayName
        opacity: root.clockIn
        scale: 0.94 + 0.06 * root.clockIn + 0.08 * root.outro
    }

    // ==========================================
    // AUTH CARD
    // ==========================================

    Card {
        id: card

        readonly property real shown: root.cardIn * (1 - root.idleT)

        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height / 2 + 10 + 40 * (1 - root.cardIn) + 30 * root.idleT)
        width: 360
        height: cardColumn.implicitHeight + 2 * padding
        padding: 22
        opacity: shown
        scale: 0.94 + 0.06 * shown + 0.06 * root.outro
        visible: opacity > 0

        Column {
            id: cardColumn

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 12

            // Avatar with a ring that spins while checking and closes green on success.
            Item {
                id: avatar

                anchors.horizontalCenter: parent.horizontalCenter
                width: 78
                height: 78

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.border
                }

                Shape {
                    id: ring

                    property real sweep: root.lock.unlocking ? 360 : root.lock.checking ? 110 : 0

                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    Behavior on sweep { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

                    RotationAnimation on rotation {
                        running: root.lock.checking
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                    }

                    ShapePath {
                        strokeColor: root.lock.unlocking ? Theme.success : Theme.accent
                        strokeWidth: 3
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap

                        PathAngleArc {
                            centerX: ring.width / 2
                            centerY: ring.height / 2
                            radiusX: ring.width / 2 - 1
                            radiusY: ring.height / 2 - 1
                            startAngle: -90
                            sweepAngle: ring.sweep
                        }
                    }
                }

                ClippingRectangle {
                    anchors.centerIn: parent
                    width: 64
                    height: 64
                    radius: 32
                    scale: root.lock.unlocking ? 1.08 : 1

                    Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.accent }
                            GradientStop { position: 1.0; color: Qt.darker(Theme.accent, 1.6) }
                        }
                    }

                    // No picture: the Arch logo, spinning in with the card (as on the login screen).
                    Text {
                        anchors.centerIn: parent
                        // The glyph sits a bit left of center in its font box.
                        anchors.horizontalCenterOffset: 1
                        visible: face.status !== Image.Ready
                        text: Icons.arch
                        color: Theme.accentText
                        font.pixelSize: 32
                        rotation: -180 * (1 - root.ease(root.stage(root.intro, 0.35, 0.9)))
                        scale: 0.4 + 0.6 * root.ease(root.stage(root.intro, 0.35, 0.9))
                    }

                    Image {
                        id: face
                        anchors.fill: parent
                        source: "file://" + root.lock.avatar
                        sourceSize.width: 128
                        sourceSize.height: 128
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.lock.displayName
                color: Theme.text
                font.pixelSize: 16
                font.bold: true
            }

            PasswordField {
                width: parent.width
                length: root.lock.buffer.length
                checking: root.lock.checking
                success: root.lock.unlocking
                capsLock: root.lock.capsLock
                failCount: root.lock.failCount
                focused: root.activeFocus
            }

            // Status line under the field. Fixed height so the card never jumps.
            Item {
                width: parent.width
                height: 16

                Text {
                    id: status

                    readonly property string value: {
                        if (root.lock.unlocking)
                            return "Welcome back";
                        if (root.lock.checking)
                            return "Checking…";
                        if (root.lock.message !== "")
                            return root.lock.message;
                        return root.lock.buffer.length > 0 ? "Press Enter to unlock" : "";
                    }

                    anchors.horizontalCenter: parent.horizontalCenter
                    text: value
                    color: root.lock.unlocking ? Theme.success : root.lock.messageIsError && !root.lock.checking ? Theme.error : Theme.muted
                    font.pixelSize: 11
                    opacity: value !== "" ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
            }
        }
    }

    // ==========================================
    // BOTTOM: hints, media, power
    // ==========================================

    KeyHints {
        anchors.left: parent.left
        anchors.leftMargin: 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36 - 20 * (1 - root.bottomIn)
        opacity: root.bottomIn * (1 - 0.6 * root.idleT)
        hints: [
            { keys: "↵", label: "unlock" },
            { keys: "esc", label: "clear" }
        ]
    }

    LockMedia {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28 - 30 * (1 - root.bottomIn)
        service: root.lock.media
        opacity: root.bottomIn
        visible: player !== null && opacity > 0
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28 - 20 * (1 - root.bottomIn)
        spacing: 10
        opacity: root.bottomIn * (1 - 0.6 * root.idleT)

        HoldButton {
            icon: Icons.sleep
            label: "Suspend"
            onActivated: Quickshell.execDetached(["systemctl", "suspend"])
        }

        HoldButton {
            icon: Icons.restart
            label: "Reboot"
            tint: Theme.error
            onActivated: Quickshell.execDetached(["systemctl", "reboot"])
        }

        HoldButton {
            icon: Icons.power
            label: "Power off"
            tint: Theme.error
            onActivated: Quickshell.execDetached(["systemctl", "poweroff"])
        }
    }
}
