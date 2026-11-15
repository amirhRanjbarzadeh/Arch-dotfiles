import Quickshell.Services.Pipewire
import QtQml

QtObject {
    readonly property var sink: Pipewire.defaultAudioSink
}
