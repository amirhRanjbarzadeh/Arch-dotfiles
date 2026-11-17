pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "components"
import "lock"
import "styles"

// SDDM login screen, built from the same pieces as the quickshell lock screen
// (install.sh copies them in). The wallpaper blurs in like the lock screen does,
// and on login everything clears away so Hyprland starts on the same wallpaper.
Rectangle {
    id: root

    width: 1920
    height: 1080
    color: "black"

    // ==========================================
    // STATE
    // ==========================================

    // Filled from userModel / sessionModel (SDDM models have no index getters).
    property var users: []
    property var sessions: []
    property int userIndex: Math.max(0, userModel.lastIndex)
    property int sessionIndex: Math.max(0, sessionModel.lastIndex)
    readonly property var user: users[userIndex] ?? null
    readonly property string userName: user?.name ?? ""
    readonly property string displayName: user ? (user.realName || user.name) : ""
    readonly property string sessionName: sessions[sessionIndex] ?? ""

    // Wallpaper colors from the quickshell picker: sync-login-screen.sh writes them
    // to theme.conf.user (as "rrggbb"). Missing keys keep Theme's static palette.
    function loadWallpaperColors() {
        const colors = {};
        for (const key of ["accent", "secondary", "accentText", "surface", "border", "text", "subtle", "muted"]) {
            const value = String(config[key] ?? "");
            if (/^[0-9a-fA-F]{6}$/.test(value))
                colors[key] = "#" + value;
        }
        Theme.dynamic = colors;
    }

    property string buffer: ""
    property bool checking: false
    property bool succeeded: false
    property string message: ""
    property bool messageIsError: false
    property int failCount: 0
    property bool idle: false
    property bool sessionMenuOpen: false

    // Timelines, 0 → 1 (same scheme as the lock screen).
    property real intro: 0
    property real outro: 0
    property real idleT: idle ? 1 : 0

    Behavior on idleT { NumberAnimation { duration: 700; easing.type: Easing.InOutCubic } }

    function stage(t, from, to) {
        return Math.max(0, Math.min(1, (t - from) / (to - from)));
    }

    function ease(x) {
        return 1 - Math.pow(1 - x, 3);
    }

    function presence(inFrom, inTo, outFrom, outTo) {
        return ease(stage(intro, inFrom, inTo)) * (1 - ease(stage(outro, outFrom, outTo)));
    }

    readonly property real backdrop: presence(0, 0.55, 0.25, 1)
    readonly property real pillIn: presence(0.05, 0.4, 0.55, 1)
    readonly property real clockIn: presence(0.2, 0.7, 0, 0.45)
    readonly property real cardIn: presence(0.32, 0.85, 0, 0.4)
    readonly property real bottomIn: presence(0.45, 1, 0, 0.35)

    function submit() {
        if (checking || succeeded || !user)
            return;
        if (buffer === "" && user.needsPassword)
            return;
        checking = true;
        message = "";
        messageIsError = false;
        sddm.login(userName, buffer, sessionIndex);
    }

    function wake() {
        idle = false;
        if (!succeeded)
            idleTimer.restart();
    }

    function cycleUser(step) {
        if (users.length < 2 || checking)
            return;
        userIndex = (userIndex + step + users.length) % users.length;
        buffer = "";
        message = "";
        userSwitch.restart();
    }

    function cycleSession(step) {
        if (sessions.length > 0)
            sessionIndex = (sessionIndex + step + sessions.length) % sessions.length;
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            root.checking = false;
            root.succeeded = true;
            root.idle = false;
            outroAnim.start();
        }

        function onLoginFailed() {
            root.checking = false;
            root.buffer = "";
            root.message = "Wrong password";
            root.messageIsError = true;
            root.failCount++;
            root.wake();
        }

        function onInformationMessage(text) {
            root.message = text;
            root.messageIsError = false;
        }
    }

    // Fonts bundled by install.sh: the sddm user can't read ~/.local/share/fonts.
    FontLoader { source: "fonts/JetBrainsMonoNerdFont-Regular.ttf" }
    FontLoader { source: "fonts/JetBrainsMonoNerdFont-Bold.ttf" }

    Item {
        visible: false

        Repeater {
            model: userModel

            delegate: Item {
                required property int index
                required property string name
                required property string realName
                required property string icon
                required property bool needsPassword

                Component.onCompleted: {
                    const list = root.users.slice();
                    // SDDM's generic placeholder isn't worth showing; use the initial instead.
                    list[index] = { name, realName, needsPassword, icon: /\/\.face\.icon$/.test(icon) ? "" : icon };
                    root.users = list;
                }
            }
        }

        Repeater {
            model: sessionModel

            delegate: Item {
                required property int index
                required property string name

                Component.onCompleted: {
                    const list = root.sessions.slice();
                    list[index] = name;
                    root.sessions = list;
                }
            }
        }
    }

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
        duration: 650
    }

    Timer {
        id: idleTimer
        interval: 15000
        running: true
        onTriggered: {
            if (root.buffer === "" && !root.checking && !root.sessionMenuOpen)
                root.idle = true;
        }
    }

    Component.onCompleted: {
        loadWallpaperColors();
        introAnim.start();
        input.forceActiveFocus();
    }

    // ==========================================
    // INPUT
    // ==========================================

    Item {
        id: input

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            root.wake();
            const ctrl = event.modifiers & Qt.ControlModifier;
            if (root.succeeded) {
                event.accepted = true;
                return;
            }
            switch (event.key) {
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (root.sessionMenuOpen)
                    root.sessionMenuOpen = false;
                else
                    root.submit();
                break;
            case Qt.Key_Backspace:
                if (!root.checking)
                    root.buffer = ctrl ? "" : root.buffer.slice(0, -1);
                break;
            case Qt.Key_Escape:
                if (root.sessionMenuOpen)
                    root.sessionMenuOpen = false;
                else if (!root.checking)
                    root.buffer = "";
                break;
            case Qt.Key_Tab:
                root.cycleSession(1);
                break;
            case Qt.Key_Backtab:
                root.cycleSession(-1);
                break;
            case Qt.Key_Up:
            case Qt.Key_Down:
                if (root.sessionMenuOpen)
                    root.cycleSession(event.key === Qt.Key_Down ? 1 : -1);
                break;
            case Qt.Key_Left:
            case Qt.Key_Right:
                if (ctrl)
                    root.cycleUser(event.key === Qt.Key_Right ? 1 : -1);
                break;
            default:
                if (ctrl && event.key === Qt.Key_U)
                    root.buffer = "";
                else if (!ctrl && !root.checking && event.text.length > 0 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
                    root.buffer += event.text;
                    if (root.messageIsError)
                        root.message = "";
                }
            }
            event.accepted = true;
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: root.wake()
            onPressed: {
                root.wake();
                root.sessionMenuOpen = false;
                input.forceActiveFocus();
            }
        }
    }

    // ==========================================
    // BACKGROUND
    // ==========================================

    Item {
        anchors.fill: parent
        clip: true

        Image {
            id: wallpaper
            anchors.fill: parent
            source: config.background
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: root.width
            sourceSize.height: root.height
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: wallpaper
            scale: 1 + 0.06 * root.backdrop
            blurEnabled: true
            blurMax: 64
            blur: root.backdrop
            saturation: 0.15 * root.backdrop
            brightness: -0.18 * root.backdrop - 0.08 * root.idleT
        }

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
    // TOP PILL
    // ==========================================

    Rectangle {
        id: pill

        readonly property var layout: keyboard.layouts[keyboard.currentLayout] ?? null

        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barTopMargin
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
                text: Icons.arch
                color: Theme.accent
                font.pixelSize: 15
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: sddm.hostName
                color: Theme.text
                font.pixelSize: 12
                font.bold: true
            }
        }

        Text {
            anchors.centerIn: parent
            opacity: root.pillIn
            text: root.succeeded ? "Starting " + root.sessionName : "Welcome"
            color: root.succeeded ? Theme.success : Theme.muted
            font.pixelSize: 11

            Behavior on color { ColorAnimation { duration: 200 } }
        }

        // Keyboard layout; click to switch.
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: pill.layout !== null
            width: layoutText.implicitWidth + 20
            height: 24
            radius: Theme.itemRadius
            color: layoutMouse.containsMouse ? Theme.surface : "transparent"
            opacity: root.pillIn

            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                id: layoutText
                anchors.centerIn: parent
                text: (pill.layout?.shortName ?? "").toUpperCase()
                color: Theme.text
                font.pixelSize: 11
                font.bold: true
            }

            MouseArea {
                id: layoutMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: keyboard.layouts.length > 1
                onClicked: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
            }
        }
    }

    // ==========================================
    // CLOCK
    // ==========================================

    LockClock {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height / 2 - height - 40 + 110 * root.idleT - 40 * (1 - root.clockIn) - 60 * root.outro)
        name: root.displayName
        opacity: root.clockIn
        scale: 0.94 + 0.06 * root.clockIn + 0.08 * root.outro
    }

    // ==========================================
    // LOGIN CARD
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

            // Avatar, flanked by user switchers when there's more than one account.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 78

                Repeater {
                    model: root.users.length > 1 ? [-1, 1] : []

                    delegate: Rectangle {
                        id: switcher

                        required property int modelData

                        anchors.verticalCenter: parent.verticalCenter
                        x: modelData < 0 ? 40 : parent.width - width - 40
                        width: 30
                        height: 30
                        radius: 15
                        color: switcherMouse.containsMouse ? Theme.surface : "transparent"

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: switcher.modelData < 0 ? Icons.chevronLeft : Icons.chevronRight
                            color: Theme.subtle
                            font.pixelSize: 18
                        }

                        MouseArea {
                            id: switcherMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cycleUser(switcher.modelData)
                        }
                    }
                }

                Item {
                    id: avatar

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 78
                    height: 78

                    // Played when switching user.
                    SequentialAnimation {
                        id: userSwitch
                        NumberAnimation { target: avatar; property: "scale"; to: 0.85; duration: 110; easing.type: Easing.InQuad }
                        NumberAnimation { target: avatar; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.border
                    }

                    Shape {
                        id: ring

                        property real sweep: root.succeeded ? 360 : root.checking ? 110 : 0

                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        Behavior on sweep { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

                        RotationAnimation on rotation {
                            running: root.checking
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                        }

                        ShapePath {
                            strokeColor: root.succeeded ? Theme.success : Theme.accent
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

                    Rectangle {
                        id: face

                        anchors.centerIn: parent
                        width: 64
                        height: 64
                        radius: 32
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.accent }
                            GradientStop { position: 1.0; color: Qt.darker(Theme.accent, 1.6) }
                        }
                        scale: root.succeeded ? 1.08 : 1

                        Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

                        // No picture: the Arch logo. Spins and pops in with the card.
                        Text {
                            anchors.centerIn: parent
                            // The glyph sits a bit left of center in its font box.
                            anchors.horizontalCenterOffset: 1
                            visible: faceImage.status !== Image.Ready
                            text: Icons.arch
                            color: Theme.accentText
                            font.pixelSize: 32
                            rotation: -180 * (1 - root.ease(root.stage(root.intro, 0.35, 0.9)))
                            scale: 0.4 + 0.6 * root.ease(root.stage(root.intro, 0.35, 0.9))
                        }

                        Image {
                            id: faceImage
                            anchors.fill: parent
                            source: root.user?.icon ? "file://" + root.user.icon : ""
                            sourceSize.width: 128
                            sourceSize.height: 128
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                        }

                        // Round mask for the picture.
                        MultiEffect {
                            anchors.fill: parent
                            source: faceImage
                            visible: faceImage.status === Image.Ready
                            maskEnabled: true
                            maskSource: faceMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }

                        Item {
                            id: faceMask
                            anchors.fill: parent
                            layer.enabled: true
                            visible: false

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "black"
                            }
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.displayName
                color: Theme.text
                font.pixelSize: 16
                font.bold: true
            }

            PasswordField {
                width: parent.width
                length: root.buffer.length
                checking: root.checking
                success: root.succeeded
                capsLock: keyboard.capsLock
                failCount: root.failCount
                focused: input.activeFocus
                placeholder: root.user?.needsPassword === false ? "Press Enter to log in" : "Enter password"
            }

            Item {
                width: parent.width
                height: 16

                Text {
                    readonly property string value: {
                        if (root.succeeded)
                            return "Welcome back";
                        if (root.checking)
                            return "Logging in…";
                        if (root.message !== "")
                            return root.message;
                        return root.buffer.length > 0 ? "Press Enter to log in" : "";
                    }

                    anchors.horizontalCenter: parent.horizontalCenter
                    text: value
                    color: root.succeeded ? Theme.success : root.messageIsError && !root.checking ? Theme.error : Theme.muted
                    font.pixelSize: 11
                    opacity: value !== "" ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
            }
        }
    }

    // ==========================================
    // BOTTOM: session picker, hints, power
    // ==========================================

    // Session picker: the pill opens a menu that grows up out of it.
    Item {
        id: sessionPicker

        anchors.left: parent.left
        anchors.leftMargin: 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28 - 20 * (1 - root.bottomIn)
        width: sessionPill.width
        height: sessionPill.height
        opacity: root.bottomIn * (1 - 0.6 * root.idleT)

        Card {
            id: sessionMenu

            property real open: root.sessionMenuOpen ? 1 : 0

            anchors.left: parent.left
            anchors.bottom: sessionPill.top
            anchors.bottomMargin: 10
            // As wide as the pill, which already fits the (bold) session name.
            width: Math.max(220, sessionPill.width)
            height: sessionList.implicitHeight + 2 * padding
            padding: 6
            opacity: open
            scale: 0.9 + 0.1 * open
            transformOrigin: Item.BottomLeft
            visible: opacity > 0

            Behavior on open { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Column {
                id: sessionList

                anchors.left: parent.left
                anchors.right: parent.right

                Repeater {
                    model: root.sessions

                    delegate: Rectangle {
                        id: sessionRow

                        required property string modelData
                        required property int index
                        readonly property bool current: index === root.sessionIndex

                        width: parent.width
                        height: 32
                        radius: Theme.itemRadius
                        color: current ? Theme.surface : rowMouse.containsMouse ? Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.5) : "transparent"

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.check
                            color: Theme.accent
                            font.pixelSize: 13
                            opacity: sessionRow.current ? 1 : 0
                            scale: sessionRow.current ? 1 : 0.5

                            Behavior on opacity { NumberAnimation { duration: 140 } }
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                        }

                        Text {
                            id: rowText
                            anchors.left: parent.left
                            anchors.leftMargin: 32
                            anchors.verticalCenter: parent.verticalCenter
                            text: sessionRow.modelData
                            color: sessionRow.current ? Theme.text : Theme.subtle
                            font.pixelSize: 12
                            font.bold: sessionRow.current
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.sessionIndex = sessionRow.index;
                                root.sessionMenuOpen = false;
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: sessionPill

            width: sessionRowContent.implicitWidth + 28
            height: 40
            radius: height / 2
            color: Theme.background
            border.width: 1
            border.color: root.sessionMenuOpen || sessionMouse.containsMouse ? Theme.accent : Theme.border
            scale: sessionMouse.pressed ? 0.95 : 1

            Behavior on border.color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

            Row {
                id: sessionRowContent

                anchors.centerIn: parent
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.apps
                    color: Theme.accent
                    font.pixelSize: 15
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.sessionName
                    color: Theme.text
                    font.pixelSize: 12
                    font.bold: true
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.chevronDown
                    color: Theme.subtle
                    font.pixelSize: 14
                    rotation: root.sessionMenuOpen ? 180 : 0

                    Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
            }

            MouseArea {
                id: sessionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.wake();
                    root.sessionMenuOpen = !root.sessionMenuOpen;
                    input.forceActiveFocus();
                }
            }
        }
    }

    KeyHints {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 38 - 20 * (1 - root.bottomIn)
        opacity: root.bottomIn * (1 - 0.6 * root.idleT)
        hints: {
            const list = [{ keys: "↵", label: "log in" }, { keys: "tab", label: "session" }];
            if (root.users.length > 1)
                list.push({ keys: "ctrl ←→", label: "user" });
            return list;
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28 - 20 * (1 - root.bottomIn)
        spacing: 10
        opacity: root.bottomIn * (1 - 0.6 * root.idleT)

        HoldButton {
            visible: sddm.canSuspend
            icon: Icons.sleep
            label: "Suspend"
            onActivated: sddm.suspend()
        }

        HoldButton {
            visible: sddm.canReboot
            icon: Icons.restart
            label: "Reboot"
            tint: Theme.error
            onActivated: sddm.reboot()
        }

        HoldButton {
            visible: sddm.canPowerOff
            icon: Icons.power
            label: "Power off"
            tint: Theme.error
            onActivated: sddm.powerOff()
        }
    }
}
