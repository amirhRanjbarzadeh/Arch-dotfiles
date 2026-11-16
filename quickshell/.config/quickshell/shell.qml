//@ pragma UseQApplication

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick

import "components"
import "services"
import "styles"
import "views"

PanelWindow {
    id: bar

    // ==========================================
    // STATE
    // ==========================================

    // Which island panel is open: "", "wifi", "bluetooth" or "volume"
    property string activePanel: ""
    // The collapsed bar has two pages: status (false) and system tray (true).
    // Scroll down on the bar for the tray, scroll up to come back.
    property bool trayVisible: false
    property var selectedWifiNetwork: null

    readonly property bool islandExpanded: activePanel !== ""
    readonly property Item activeView: activePanel === "wifi" ? wifiView : activePanel === "bluetooth" ? bluetoothView : activePanel === "volume" ? volumeView : null

    // Each view owns its size; the island just morphs to fit it.
    readonly property int islandWidth: activeView ? activeView.implicitWidth : Theme.barWidth
    readonly property int islandHeight: activeView ? activeView.implicitHeight : Theme.barHeight

    // Extra transparent room below expanded views so their drop shadow isn't clipped.
    // Input there is masked out, so it never blocks clicks on windows underneath.
    readonly property int shadowPadding: 24

    function togglePanel(name) {
        activePanel = activePanel === name ? "" : name;
    }

    function setTrayVisible(show) {
        if (show)
            activePanel = "";
        trayVisible = show;
    }

    function closeAll() {
        activePanel = "";
        trayVisible = false;
    }

    onActivePanelChanged: {
        if (islandExpanded)
            trayVisible = false;
        if (activePanel !== "wifi")
            selectedWifiNetwork = null;
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
        onSinkChanged: bar.armVolumeOsd()
    }

    BluetoothService {
        id: bluetoothService
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
    // TIMERS: volume OSD and tray page
    // ==========================================

    // PipeWire emits a burst of volume/mute changes while a sink first binds;
    // ignore those so the OSD doesn't flash at startup or on device switch.
    property bool volumeOsdArmed: false

    function armVolumeOsd() {
        volumeOsdArmed = false;
        osdArmTimer.restart();
    }

    function showVolumeOsd() {
        // Don't hijack the island while another panel is in use.
        if (!volumeOsdArmed || (activePanel !== "" && activePanel !== "volume"))
            return;
        activePanel = "volume";
        updateAutoDismiss();
    }

    // Only the volume island auto-closes, and never while the pointer is on it.
    function updateAutoDismiss() {
        if (activePanel === "volume" && !barHover.hovered)
            autoDismissTimer.restart();
        else
            autoDismissTimer.stop();
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
        onTriggered: bar.volumeOsdArmed = true
    }

    Timer {
        id: autoDismissTimer
        interval: 3000
        onTriggered: {
            if (bar.activePanel === "volume")
                bar.activePanel = "";
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
            bar.showVolumeOsd();
        }

        function onMutedChanged() {
            bar.showVolumeOsd();
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

    anchors.top: true
    margins.top: Theme.barTopMargin

    implicitWidth: Theme.barWidth
    // Grow instantly when expanding; follow the island's animation when collapsing.
    implicitHeight: Math.max(islandExpanded ? islandHeight + shadowPadding : 0, island.height + (island.height > Theme.barHeight ? shadowPadding : 0))

    // Reserve only the collapsed bar height so expanding the island doesn't
    // shrink the tiled area in Hyprland.
    exclusiveZone: Theme.barHeight
    color: "transparent"

    WlrLayershell.namespace: "quickshell:bar"
    // Panels and the tray page accept the keyboard once clicked (Escape to close).
    // Not Exclusive: on this Hyprland, switching to Exclusive stalls the bar's
    // rendering. The volume OSD stays None so volume keys never steal focus.
    WlrLayershell.keyboardFocus: activePanel === "wifi" || activePanel === "bluetooth" || trayVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Only the island accepts input; the transparent rest of the window is click-through.
    mask: Region {
        item: island
    }

    // Clicking anywhere outside closes panels and returns from the tray page.
    HyprlandFocusGrab {
        active: (bar.islandExpanded || bar.trayVisible) && !systemTrayView.nativeMenuOpen
        windows: [bar, wifiPasswordView]
        onCleared: {
            if (!systemTrayView.nativeMenuOpen)
                bar.closeAll();
        }
    }

    // Control the bar from keybinds/scripts, e.g. `qs ipc call bar toggle wifi`.
    IpcHandler {
        target: "bar"

        function toggle(panel: string): void {
            if (panel === "tray")
                bar.setTrayVisible(!bar.trayVisible);
            else if (["wifi", "bluetooth", "volume"].includes(panel))
                bar.togglePanel(panel);
        }

        function close(): void {
            bar.closeAll();
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

        Island {
            id: island

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: bar.islandWidth
            height: bar.islandHeight
            // Expanded views draw their own card.
            backgroundVisible: !bar.islandExpanded

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
                    }

                    StatusIndicators {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter

                        activeWifiNetwork: networkService.activeWifiNetwork
                        audioSink: audioService.sink
                        adapter: bluetoothService.adapter

                        onWifiRequested: bar.togglePanel("wifi")
                        onVolumeRequested: bar.togglePanel("volume")
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

        VolumeView {
            id: volumeView
            anchors.fill: island
            visible: bar.activePanel === "volume"
            audioSink: audioService.sink
        }
    }

    WifiPasswordView {
        id: wifiPasswordView

        anchor.window: bar
        anchor.rect.x: (bar.width - width) / 2
        anchor.rect.y: island.height + 10

        selectedWifiNetwork: bar.selectedWifiNetwork
        onCancelRequested: bar.selectedWifiNetwork = null
    }
}
