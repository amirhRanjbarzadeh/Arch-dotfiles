//@ pragma UseQApplication

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick

import "components"
import "lock"
import "services"
import "styles"
import "views"

PanelWindow {
    id: bar

    // ==========================================
    // STATE
    // ==========================================

    // Which island panel is open:
    //   "wifi", "bluetooth", "controls"  interactive panels you open by clicking
    //   "volume", "brightness"           key-press popups (one slider, auto-close)
    //   "notification"                   incoming notification card
    //   "notifications"                  notification history
    //   "launcher", "clipboard"          search lists
    //   "media"                          now-playing panel with controls
    //   "nowplaying"                     media-key popup (compact, auto-close)
    //   "calendar"                       month calendar (click the clock)
    //   "wallpaper"                      wallpaper picker (recolors the theme)
    //   "power"                          power menu, centered on screen
    property string activePanel: ""
    // Hidden entirely (SUPER+CTRL+B); also frees the reserved space.
    property bool hidden: false
    // The collapsed bar has two pages: status (false) and system tray (true).
    // Scroll down on the bar for the tray, scroll up to come back.
    property bool trayVisible: false
    property var selectedWifiNetwork: null

    readonly property bool islandExpanded: activePanel !== ""
    readonly property Item activeView: {
        switch (activePanel) {
        case "wifi":
            return wifiView;
        case "bluetooth":
            return bluetoothView;
        case "volume":
        case "brightness":
        case "controls":
            return controlsView;
        case "notification":
            return notificationView;
        case "notifications":
            return notificationHistoryView;
        case "power":
            return powerView;
        case "launcher":
            return launcherView;
        case "clipboard":
            return clipboardView;
        case "media":
        case "nowplaying":
            return mediaView;
        case "calendar":
            return calendarView;
        case "wallpaper":
            return wallpaperView;
        default:
            return null;
        }
    }
    // Panels you work in: they take clicks-outside-to-close and keyboard focus.
    readonly property bool interactivePanelOpen: ["wifi", "bluetooth", "controls", "notifications", "power", "launcher", "clipboard", "media", "calendar", "wallpaper"].includes(activePanel)

    // The power menu moves the island to the middle of the screen over a dimmed backdrop.
    readonly property bool powerOpen: activePanel === "power"
    readonly property int screenHeight: screen?.height ?? 1080

    // Each view owns its size; the island just morphs to fit it.
    readonly property int islandWidth: activeView ? activeView.implicitWidth : Theme.barWidth
    readonly property int islandHeight: activeView ? activeView.implicitHeight : Theme.barHeight

    function togglePanel(name) {
        activePanel = activePanel === name ? "" : name;
    }

    function setTrayVisible(show) {
        if (show)
            activePanel = "";
        trayVisible = show;
    }

    function closeAll() {
        // Closing a notification card stops showing it; it stays in history.
        if (activePanel === "notification")
            notificationService.hide(notificationService.current);
        activePanel = "";
        trayVisible = false;
    }

    function setHidden(hide) {
        if (hide)
            closeAll();
        hidden = hide;
    }

    visible: !hidden

    onActivePanelChanged: {
        if (islandExpanded)
            trayVisible = false;
        if (activePanel === "notifications")
            notificationService.markSeen();
        if (activePanel !== "wifi")
            selectedWifiNetwork = null;
        // Island freed up: show any notification that was waiting.
        if (activePanel === "")
            Qt.callLater(showNotification);
        updateAutoDismiss();
    }

    onTrayVisibleChanged: updateTrayReturn()

    // ==========================================
    // SERVICES
    // ==========================================

    NetworkService {
        id: networkService
    }

    AudioService {
        id: audioService
        onSinkChanged: bar.armOsd()
    }

    BrightnessService {
        id: brightnessService
    }

    BluetoothService {
        id: bluetoothService
    }

    NotificationService {
        id: notificationService
    }

    MediaService {
        id: mediaService
    }

    WallpaperService {
        id: wallpaperService
    }

    // Session lock (`qs ipc call lock lock`); shares the services above.
    LockScreen {
        id: lockScreen
        media: mediaService
        network: networkService
        notifications: notificationService
        // Start from a clean bar, so the snapshot (and the bar after unlock) has no panel open.
        onPreparingChanged: {
            if (preparing)
                bar.closeAll();
        }
    }

    Connections {
        target: notificationService

        function onCurrentChanged() {
            bar.showNotification();
        }

        // Arrivals while history is open show up in its list instead of popping up.
        function onQueueChanged() {
            if (bar.activePanel === "notifications")
                notificationService.markSeen();
        }

        // Replaced content (e.g. progress updates) restarts the countdown.
        function onUpdated(notification) {
            if (notification === notificationService.current)
                bar.updateAutoDismiss();
        }
    }

    PwObjectTracker {
        objects: [audioService.sink]
    }

    readonly property var activeWifiNetwork: networkService.activeWifiNetwork

    // Close the password prompt once we're connected to the network it was for.
    onActiveWifiNetworkChanged: {
        if (activeWifiNetwork && selectedWifiNetwork && activeWifiNetwork.name === selectedWifiNetwork.name)
            selectedWifiNetwork = null;
    }

    // ==========================================
    // TIMERS: key-press popups, notifications and tray page
    // ==========================================

    // PipeWire emits a burst of volume/mute changes while a sink first binds, and
    // the backlight is read once at startup; ignore those so no popup flashes.
    property bool osdArmed: false

    function armOsd() {
        osdArmed = false;
        osdArmTimer.restart();
    }

    // kind: "volume", "brightness" or "nowplaying"
    function showOsd(kind) {
        // Don't hijack a panel in use (the open controls panel already shows the
        // change live). A notification is fine to interrupt: it comes back after.
        if (!osdArmed || interactivePanelOpen)
            return;
        activePanel = kind;
        updateAutoDismiss();
    }

    // Notifications take the island whenever it's idle or only showing the volume OSD;
    // while Wi-Fi/Bluetooth are open they wait in the queue.
    function showNotification() {
        if (!notificationService.current) {
            if (activePanel === "notification")
                activePanel = "";
            return;
        }
        if (activePanel === "" || activePanel === "notification") {
            activePanel = "notification";
            updateAutoDismiss();
        }
    }

    // Volume OSD and notifications auto-close, but never while the pointer is on the bar.
    function updateAutoDismiss() {
        let timeout = 0;
        if (activePanel === "volume" || activePanel === "brightness" || activePanel === "nowplaying")
            timeout = 3000;
        else if (activePanel === "notification")
            timeout = notificationService.timeoutFor(notificationService.current);

        if (timeout > 0 && !barHover.hovered) {
            autoDismissTimer.interval = timeout;
            autoDismissTimer.restart();
        } else {
            autoDismissTimer.stop();
        }
    }

    // The tray page flips back to status 5s after the pointer leaves the bar.
    function updateTrayReturn() {
        if (trayVisible && !barHover.hovered && !systemTrayView.nativeMenuOpen)
            trayReturnTimer.restart();
        else
            trayReturnTimer.stop();
    }

    Timer {
        id: osdArmTimer
        interval: 1500
        running: true
        onTriggered: bar.osdArmed = true
    }

    Timer {
        id: autoDismissTimer
        onTriggered: {
            if (bar.activePanel === "volume" || bar.activePanel === "brightness" || bar.activePanel === "nowplaying")
                bar.activePanel = "";
            else if (bar.activePanel === "notification")
                notificationService.hide(notificationService.current);
        }
    }

    Timer {
        id: trayReturnTimer
        interval: 5000
        onTriggered: bar.trayVisible = false
    }

    Connections {
        target: audioService.sink?.audio ?? null

        function onVolumeChanged() {
            bar.showOsd("volume");
        }

        function onMutedChanged() {
            bar.showOsd("volume");
        }
    }

    Connections {
        target: brightnessService

        function onRawChanged() {
            bar.showOsd("brightness");
        }
    }

    Connections {
        target: systemTrayView

        function onNativeMenuOpenChanged() {
            bar.updateTrayReturn();
        }
    }

    // ==========================================
    // WINDOW
    // ==========================================

    // Covers the whole screen, always: panels, shadows and the power menu's
    // backdrop all fit without the window ever resizing. (Resizing mid-animation
    // swaps buffers, which made the edge buttons flicker and the island jump.)
    // The mask keeps everything but the island and edge buttons click-through;
    // the gap above the bar is the island's own y offset.
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: screenHeight

    // Reserve only the collapsed bar (and the gap above it) so expanding the
    // island doesn't shrink the tiled area in Hyprland.
    exclusiveZone: Theme.barTopMargin + Theme.barHeight
    color: "transparent"

    WlrLayershell.namespace: "quickshell:bar"
    // Panels and the tray page accept the keyboard once clicked (Escape to close).
    // Not Exclusive: on this Hyprland, switching to Exclusive stalls the bar's
    // rendering. Key-press popups stay None so they never steal focus from your app.
    WlrLayershell.keyboardFocus: interactivePanelOpen || trayVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Only the island and edge buttons accept input; the transparent rest of the
    // window is click-through. With the power menu up, the backdrop takes clicks
    // too (to close it).
    mask: Region {
        item: bar.powerOpen ? backdrop : island

        Region { item: launcherButton }
        // Only while shown, so the empty spot stays click-through.
        Region { item: mediaIndicator.visible ? mediaIndicator : null }
        Region { item: powerButton }
    }

    // Clicking anywhere outside closes panels and returns from the tray page.
    HyprlandFocusGrab {
        // Not for the volume OSD or notifications: they pop up on their own, and
        // an active grab would swallow your next click elsewhere.
        active: (bar.interactivePanelOpen || bar.trayVisible) && !systemTrayView.nativeMenuOpen
        windows: [bar, wifiPasswordView]
        onCleared: {
            if (!systemTrayView.nativeMenuOpen)
                bar.closeAll();
        }
    }

    // Control the bar from keybinds/scripts, e.g. `qs ipc call bar toggle wifi`.
    IpcHandler {
        target: "bar"

        // wifi | bluetooth | controls | volume | brightness | notifications | power | launcher | clipboard | media | calendar | wallpaper | tray
        function toggle(panel: string): void {
            if (bar.hidden)
                bar.setHidden(false);
            if (panel === "tray")
                bar.setTrayVisible(!bar.trayVisible);
            else if (["wifi", "bluetooth", "controls", "volume", "brightness", "notifications", "power", "launcher", "clipboard", "media", "calendar", "wallpaper"].includes(panel))
                bar.togglePanel(panel);
        }

        // Media keys: playPause | next | previous. Acts on the player the bar
        // shows and pops up the now-playing card.
        function media(action: string): void {
            if (action === "playPause")
                mediaService.togglePlaying();
            else if (action === "next")
                mediaService.next();
            else if (action === "previous")
                mediaService.previous();
            else
                return;
            nowPlaying();
        }

        // Peek at the current track without changing anything.
        function nowPlaying(): void {
            if (mediaService.player)
                bar.showOsd("nowplaying");
        }

        function close(): void {
            bar.closeAll();
        }

        // Hide or show the whole bar.
        function toggleHidden(): void {
            bar.setHidden(!bar.hidden);
        }

        function clearNotifications(): void {
            notificationService.clearHistory();
        }

        // Apply a wallpaper (and its colors) without opening the picker.
        function setWallpaper(path: string): void {
            wallpaperService.apply(path);
        }
    }

    Shortcut {
        sequences: ["Escape"]
        enabled: bar.islandExpanded || bar.trayVisible
        onActivated: bar.closeAll()
    }

    // ==========================================
    // CONTENT
    // ==========================================

    Item {
        anchors.fill: parent

        HoverHandler {
            id: barHover
            onHoveredChanged: {
                bar.updateAutoDismiss();
                bar.updateTrayReturn();
            }
        }

        // Edge buttons, outside the island and in line with the window gaps.
        // The backdrop covers them while the power menu is up.

        EdgeButton {
            id: launcherButton

            x: Theme.edgeMargin
            y: Theme.barTopMargin
            icon: Icons.arch
            iconColor: Theme.accent
            iconSize: 17
            // The Arch glyph sits left of center in its font box.
            iconOffsetX: 1
            tooltip: "Applications"
            active: bar.activePanel === "launcher"
            onClicked: bar.togglePanel("launcher")
        }

        // Now playing, beside the launcher button; hidden when nothing plays.
        MediaIndicator {
            id: mediaIndicator

            x: launcherButton.x + launcherButton.width + 6
            y: Theme.barTopMargin
            // Never run under the island, even while it's expanded.
            maximumWidth: Math.max(0, Math.min(300, island.x - x - 12))
            player: mediaService.player
            active: bar.activePanel === "media"
            onClicked: bar.togglePanel("media")
        }

        EdgeButton {
            id: powerButton

            x: parent.width - width - Theme.edgeMargin
            y: Theme.barTopMargin
            icon: Icons.power
            iconColor: Theme.error
            tooltip: "Power"
            active: bar.powerOpen
            onClicked: bar.togglePanel("power")
        }

        // Dims the screen behind the power menu; clicking it closes the menu.
        Rectangle {
            id: backdrop

            anchors.fill: parent
            color: "#000000"
            opacity: bar.powerOpen ? 0.5 : 0
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: Theme.animDuration + 100; easing.type: Easing.OutCubic } }

            MouseArea {
                anchors.fill: parent
                enabled: bar.powerOpen
                onClicked: bar.closeAll()
            }
        }

        Island {
            id: island

            anchors.horizontalCenter: parent.horizontalCenter
            // Glides down to the middle of the screen for the power menu.
            y: bar.powerOpen ? Math.round((bar.screenHeight - bar.islandHeight) / 2) : Theme.barTopMargin
            width: bar.islandWidth
            height: bar.islandHeight
            // Expanded views draw their own card.
            backgroundVisible: !bar.islandExpanded

            Behavior on y { NumberAnimation { duration: Theme.animDuration + 100; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }

            // Collapsed bar: status and tray pages stacked vertically, sliding in a clipped viewport.
            Item {
                id: collapsedPages

                anchors.fill: parent
                clip: true
                opacity: bar.islandExpanded ? 0 : 1
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: 150 } }

                // Scroll down for the tray, up for status. Children that use the
                // wheel themselves (the volume icon) take precedence.
                WheelHandler {
                    enabled: !bar.islandExpanded
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x;
                        if (delta < 0 && !bar.trayVisible)
                            bar.setTrayVisible(true);
                        else if (delta > 0 && bar.trayVisible)
                            bar.trayVisible = false;
                    }
                }

                // Status page
                Item {
                    width: parent.width
                    height: Theme.barHeight
                    y: bar.trayVisible ? -Theme.barHeight : 0
                    opacity: bar.trayVisible ? 0 : 1

                    Behavior on y { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animDuration } }

                    WorkspaceSection {
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Clock {
                        anchors.centerIn: parent
                        active: bar.activePanel === "calendar"
                        onClicked: bar.togglePanel("calendar")
                    }

                    StatusIndicators {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter

                        activeWifiNetwork: networkService.activeWifiNetwork
                        audioSink: audioService.sink
                        adapter: bluetoothService.adapter

                        onWifiRequested: bar.togglePanel("wifi")
                        onVolumeRequested: bar.togglePanel("controls")
                        onBluetoothRequested: bar.togglePanel("bluetooth")
                    }
                }

                // Tray page
                SystemTrayView {
                    id: systemTrayView

                    width: parent.width
                    height: Theme.barHeight
                    y: bar.trayVisible ? 0 : Theme.barHeight
                    open: bar.trayVisible

                    Behavior on y { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
                }
            }
        }

        // Island views: each fills the island while active.

        WifiView {
            id: wifiView
            anchors.fill: island
            visible: bar.activePanel === "wifi"
            wifiDevice: networkService.wifiDevice
            activeWifiNetwork: networkService.activeWifiNetwork
            onPasswordRequested: network => bar.selectedWifiNetwork = network
        }

        BluetoothView {
            id: bluetoothView
            anchors.fill: island
            visible: bar.activePanel === "bluetooth"
            adapter: bluetoothService.adapter
        }

        NotificationView {
            id: notificationView
            anchors.fill: island
            visible: bar.activePanel === "notification"
            notification: notificationService.current
            pendingCount: Math.max(0, notificationService.queue.length - 1)
        }

        NotificationHistoryView {
            id: notificationHistoryView
            anchors.fill: island
            visible: bar.activePanel === "notifications"
            service: notificationService
        }

        PowerView {
            id: powerView
            anchors.fill: island
            visible: bar.powerOpen
            onCloseRequested: bar.closeAll()
        }

        LauncherView {
            id: launcherView
            anchors.fill: island
            visible: bar.activePanel === "launcher"
            onCloseRequested: bar.closeAll()
        }

        MediaView {
            id: mediaView
            anchors.fill: island
            visible: bar.activePanel === "media" || bar.activePanel === "nowplaying"
            service: mediaService
            // The media-key popup is the compact card; the panel has full controls.
            compact: bar.activePanel === "nowplaying"
        }

        CalendarView {
            id: calendarView
            anchors.fill: island
            visible: bar.activePanel === "calendar"
            onCloseRequested: bar.closeAll()
        }

        WallpaperView {
            id: wallpaperView
            anchors.fill: island
            visible: bar.activePanel === "wallpaper"
            service: wallpaperService
            onCloseRequested: bar.closeAll()
        }

        ClipboardView {
            id: clipboardView
            anchors.fill: island
            visible: bar.activePanel === "clipboard"
            onCloseRequested: bar.closeAll()
        }

        ControlsView {
            id: controlsView
            anchors.fill: island
            visible: bar.activePanel === "volume" || bar.activePanel === "brightness" || bar.activePanel === "controls"
            audioSink: audioService.sink
            brightness: brightnessService
            // Key-press popups show only the slider that changed; the panel shows both.
            showVolume: bar.activePanel !== "brightness"
            showBrightness: bar.activePanel !== "volume"
        }
    }

    WifiPasswordView {
        id: wifiPasswordView

        anchor.window: bar
        anchor.rect.x: (bar.width - width) / 2
        anchor.rect.y: island.y + island.height + 10

        selectedWifiNetwork: bar.selectedWifiNetwork
        onCancelRequested: bar.selectedWifiNetwork = null
    }
}
