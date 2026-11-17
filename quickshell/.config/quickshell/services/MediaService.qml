pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// Media players over MPRIS. `player` is the one the bar shows and the media keys
// control: the one you picked in the media panel, else whatever is playing, else
// whatever played last.
Item {
    id: root

    readonly property var players: Mpris.players.values
    // Chosen in the media panel; cleared when that player goes away.
    property var pinned: null
    property var lastPlaying: null

    readonly property var player: {
        if (pinned && players.includes(pinned))
            return pinned;
        return players.find(p => p.isPlaying) ?? (lastPlaying && players.includes(lastPlaying) ? lastPlaying : null) ?? players[0] ?? null;
    }
    readonly property bool playing: player?.isPlaying ?? false

    // Emitted when the shown player moves to another track.
    signal trackChanged

    function pin(p) {
        pinned = p;
    }

    function togglePlaying() {
        if (player?.canTogglePlaying)
            player.togglePlaying();
    }

    function next() {
        if (player?.canGoNext)
            player.next();
    }

    function previous() {
        if (!player?.canGoPrevious)
            return;
        // Like most players: past a few seconds, "previous" restarts the track.
        if (player.canSeek && player.positionSupported && player.position > 5)
            player.position = 0;
        else
            player.previous();
    }

    // Remember the last player that played so it stays shown after pausing.
    Instantiator {
        model: Mpris.players

        delegate: Connections {
            required property var modelData
            target: modelData

            function onIsPlayingChanged() {
                if (modelData.isPlaying)
                    root.lastPlaying = modelData;
            }
        }
    }

    Connections {
        target: root.player

        function onPostTrackChanged() {
            root.trackChanged();
        }
    }

    // MPRIS doesn't push position updates; poll while something is playing.
    Timer {
        interval: 1000
        repeat: true
        running: root.playing
        onTriggered: root.player.positionChanged()
    }
}
