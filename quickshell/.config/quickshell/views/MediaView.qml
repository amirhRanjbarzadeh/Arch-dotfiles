pragma ComponentBehavior: Bound

import Quickshell.Services.Mpris
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../components"
import "../styles"

// Now playing. Full panel: album art, track info, seek bar and controls, over a
// blurred copy of the art. Compact (media-key popup): art, title and progress only.
Item {
    id: root

    property var service // MediaService
    property bool compact: false

    readonly property var player: service?.player ?? null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property bool hasLength: (player?.lengthSupported ?? false) && player.length > 0
    readonly property string artUrl: player?.trackArtUrl ?? ""

    function formatTime(seconds) {
        seconds = Math.max(0, Math.floor(seconds));
        const h = Math.floor(seconds / 3600);
        const m = Math.floor(seconds % 3600 / 60);
        const s = String(seconds % 60).padStart(2, "0");
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + s : m + ":" + s;
    }

    implicitWidth: compact ? 340 : 420
    implicitHeight: player === null ? 120 : (compact ? compactLayout.implicitHeight : fullLayout.implicitHeight) + 2 * card.padding

    // Refresh the position right away instead of waiting for the next tick.
    onVisibleChanged: {
        if (visible && player)
            player.positionChanged();
    }

    Card {
        id: card

        anchors.fill: parent
        padding: root.compact ? 12 : 16

        // Blurred album art behind everything, faded into the card.
        ClippingRectangle {
            anchors.fill: parent
            anchors.margins: -card.padding + card.border.width
            radius: card.radius - card.border.width
            color: "transparent"
            visible: backdropArt.status === Image.Ready

            Image {
                id: backdropArt
                anchors.fill: parent
                source: root.artUrl
                sourceSize.width: 128
                sourceSize.height: 128
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: root.compact ? 0.3 : 0.4

                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                    saturation: 0.2
                }
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.1) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
                }
            }
        }

        // ==========================================
        // FULL PANEL
        // ==========================================

        ColumnLayout {
            id: fullLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            visible: !root.compact && root.player !== null
            spacing: 14

            // Player switcher, when more than one app is playing media.
            Row {
                Layout.fillWidth: true
                visible: (root.service?.players.length ?? 0) > 1
                spacing: 6

                Repeater {
                    model: root.service?.players ?? []

                    delegate: Rectangle {
                        id: chip

                        required property var modelData
                        readonly property bool current: modelData === root.player

                        implicitWidth: chipText.implicitWidth + 20
                        implicitHeight: 22
                        radius: height / 2
                        color: current ? Theme.accent : chipMouse.containsMouse ? Theme.border : Theme.surface

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: (chip.modelData.isPlaying ? "♪ " : "") + (chip.modelData.identity || "Player")
                            color: chip.current ? Theme.accentText : Theme.subtle
                            font.pixelSize: 10
                            font.bold: chip.current
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.service.pin(chip.modelData)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                AlbumArt {
                    size: 112
                    source: root.artUrl
                    playing: root.playing
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        text: (root.player?.identity ?? "").toUpperCase()
                        color: Theme.accent
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1.2
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.player?.trackTitle || "Unknown title"
                        color: Theme.text
                        font.pixelSize: 16
                        font.bold: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: root.player?.trackArtist ?? ""
                        color: Theme.subtle
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: root.player?.trackAlbum ?? ""
                        color: Theme.muted
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }

            // Seek bar with times
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.hasLength
                spacing: 4

                SeekBar {
                    id: seekBar
                    Layout.fillWidth: true
                    player: root.player
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: root.formatTime(seekBar.displayPosition)
                        color: Theme.muted
                        font.pixelSize: 10
                        font.features: { "tnum": 1 }
                    }

                    Text {
                        text: "-" + root.formatTime((root.player?.length ?? 0) - seekBar.displayPosition)
                        color: Theme.muted
                        font.pixelSize: 10
                        font.features: { "tnum": 1 }
                    }
                }
            }

            // Controls
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 14

                IconButton {
                    visible: root.player?.shuffleSupported ?? false
                    implicitWidth: 32
                    implicitHeight: 32
                    icon: root.player?.shuffle ? Icons.shuffle : Icons.shuffleOff
                    iconSize: 16
                    iconColor: root.player?.shuffle ? Theme.accent : Theme.muted
                    tooltip: root.player?.shuffle ? "Shuffle on" : "Shuffle off"
                    onClicked: root.player.shuffle = !root.player.shuffle
                }

                IconButton {
                    implicitWidth: 38
                    implicitHeight: 38
                    enabled: root.player?.canGoPrevious ?? false
                    opacity: enabled ? 1 : 0.4
                    icon: Icons.skipPrevious
                    iconSize: 22
                    onClicked: root.service.previous()
                }

                // Play / pause
                Rectangle {
                    implicitWidth: 52
                    implicitHeight: 52
                    radius: width / 2
                    color: playMouse.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
                    scale: playMouse.pressed ? 0.92 : 1
                    opacity: root.player?.canTogglePlaying ? 1 : 0.4

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 90 } }

                    Text {
                        anchors.centerIn: parent
                        text: root.playing ? Icons.pause : Icons.play
                        color: Theme.accentText
                        font.pixelSize: 26
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.service.togglePlaying()
                    }
                }

                IconButton {
                    implicitWidth: 38
                    implicitHeight: 38
                    enabled: root.player?.canGoNext ?? false
                    opacity: enabled ? 1 : 0.4
                    icon: Icons.skipNext
                    iconSize: 22
                    onClicked: root.service.next()
                }

                IconButton {
                    visible: root.player?.loopSupported ?? false
                    implicitWidth: 32
                    implicitHeight: 32
                    icon: {
                        switch (root.player?.loopState) {
                        case MprisLoopState.Track:
                            return Icons.repeatOnce;
                        case MprisLoopState.Playlist:
                            return Icons.repeat;
                        default:
                            return Icons.repeatOff;
                        }
                    }
                    iconSize: 16
                    iconColor: root.player?.loopState === MprisLoopState.None ? Theme.muted : Theme.accent
                    tooltip: root.player?.loopState === MprisLoopState.Track ? "Repeat track" : root.player?.loopState === MprisLoopState.Playlist ? "Repeat all" : "Repeat off"
                    // Off → all → one → off
                    onClicked: {
                        const state = root.player.loopState;
                        root.player.loopState = state === MprisLoopState.None ? MprisLoopState.Playlist : state === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
                    }
                }
            }
        }

        // Nothing to show
        Column {
            anchors.centerIn: parent
            visible: root.player === null
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Icons.music
                color: Theme.border
                font.pixelSize: 30
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Nothing playing"
                color: Theme.muted
                font.pixelSize: 11
            }
        }

        // ==========================================
        // COMPACT (media-key popup)
        // ==========================================

        ColumnLayout {
            id: compactLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            visible: root.compact && root.player !== null
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                AlbumArt {
                    size: 52
                    source: root.artUrl
                    playing: root.playing
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.player?.trackTitle || "Unknown title"
                        color: Theme.text
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.player?.trackArtist || root.player?.identity || ""
                        color: Theme.subtle
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                Text {
                    text: root.playing ? Icons.play : Icons.pause
                    color: Theme.accent
                    font.pixelSize: 20
                }
            }

            SeekBar {
                Layout.fillWidth: true
                visible: root.hasLength
                player: root.player
                interactive: false
            }
        }
    }

    // ==========================================
    // PIECES
    // ==========================================

    // Rounded album art with a music-note fallback; breathes slightly while playing.
    component AlbumArt: ClippingRectangle {
        id: art

        property int size: 64
        property string source: ""
        property bool playing: false

        implicitWidth: size
        implicitHeight: size
        radius: Math.round(size / 7)
        color: Theme.surface
        border.width: 1
        border.color: Theme.border
        scale: playing ? 1 : 0.94

        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }

        Image {
            id: artImage
            anchors.fill: parent
            source: art.source
            sourceSize.width: art.size * 2
            sourceSize.height: art.size * 2
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: !artImage.visible
            text: Icons.music
            color: Theme.accent
            font.pixelSize: art.size * 0.4
        }
    }

    // Progress bar that glides between position ticks; drag or click to seek.
    component SeekBar: Item {
        id: bar

        property var player: null
        property bool interactive: true

        readonly property real length: player?.length ?? 0
        readonly property bool canSeek: interactive && (player?.canSeek ?? false)
        property bool dragging: false
        property real dragPosition: 0
        readonly property real displayPosition: dragging ? dragPosition : Math.min(length, player?.position ?? 0)
        readonly property real fraction: length > 0 ? displayPosition / length : 0

        implicitHeight: 14

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: seekMouse.containsMouse || bar.dragging ? 6 : 4
            radius: height / 2
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.15)

            Behavior on height { NumberAnimation { duration: 100 } }

            Rectangle {
                width: parent.width * bar.fraction
                height: parent.height
                radius: parent.radius
                color: Theme.accent

                // Glide through the 1s gaps between position updates.
                Behavior on width {
                    enabled: !bar.dragging && (bar.player?.isPlaying ?? false)
                    NumberAnimation { duration: 1000 }
                }
            }
        }

        Rectangle {
            x: track.width * bar.fraction - width / 2
            anchors.verticalCenter: parent.verticalCenter
            visible: bar.canSeek && (seekMouse.containsMouse || bar.dragging)
            width: 12
            height: 12
            radius: 6
            color: Theme.text
            border.width: 3
            border.color: Theme.accent
        }

        MouseArea {
            id: seekMouse

            anchors.fill: parent
            enabled: bar.canSeek
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function positionAt(x) {
                return Math.max(0, Math.min(1, x / width)) * bar.length;
            }

            onPressed: mouse => {
                bar.dragPosition = positionAt(mouse.x);
                bar.dragging = true;
            }
            onPositionChanged: mouse => {
                if (pressed)
                    bar.dragPosition = positionAt(mouse.x);
            }
            onReleased: {
                bar.player.position = bar.dragPosition;
                bar.dragging = false;
            }
            onCanceled: bar.dragging = false
        }
    }
}
