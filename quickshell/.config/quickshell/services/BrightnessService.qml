import Quickshell
import Quickshell.Io
import QtQuick

// Screen backlight. Reads sysfs (watched, so key presses and hypridle show up
// instantly) and writes through brightnessctl, which uses logind: no root needed.
Scope {
    id: root

    property string device: ""
    property int maxRaw: 0
    property int raw: 0

    readonly property bool available: device !== "" && maxRaw > 0
    readonly property real brightness: available ? raw / maxRaw : 0

    // Never go fully black from the slider.
    readonly property real minimum: 0.01

    function setBrightness(value) {
        if (!available)
            return;
        pendingPercent = Math.round(Math.max(minimum, Math.min(1, value)) * 100);
        if (!setter.running)
            flush();
    }

    // Detect the backlight and its range, e.g. "intel_backlight,backlight,10023,52%,19200".
    Process {
        running: true
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]

        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(",");
                if (fields.length < 5)
                    return;
                root.maxRaw = parseInt(fields[4]);
                root.raw = parseInt(fields[2]);
                root.device = fields[0];
            }
        }
    }

    FileView {
        path: root.device !== "" ? "/sys/class/backlight/" + root.device + "/brightness" : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const value = parseInt(text());
            if (!isNaN(value))
                root.raw = value;
        }
    }

    // A slider drag fires many updates: run one brightnessctl at a time and
    // always finish on the latest requested value.
    property int pendingPercent: -1

    function flush() {
        if (pendingPercent < 0)
            return;
        setter.command = ["brightnessctl", "-q", "-d", device, "set", pendingPercent + "%"];
        pendingPercent = -1;
        setter.running = true;
    }

    Process {
        id: setter
        onExited: root.flush()
    }
}
