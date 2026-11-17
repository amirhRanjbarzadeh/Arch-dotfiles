import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// Screen tools that used to be keybind scripts:
//   - region recording with wf-recorder (the bar shows a stop button while it runs)
//   - night light through hyprsunset (its own schedule lives in hypr/hyprsunset.conf)
//   - mirroring the laptop panel onto an external monitor, or extending to it
Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string recordingDir: home + "/Videos/Screencasts"

    function notify(title, body, icon) {
        Quickshell.execDetached(["notify-send", "-a", "Screen", "-i", icon, title, body ?? ""]);
    }

    // ==========================================
    // RECORDING
    // ==========================================

    // True once the region is picked and wf-recorder is writing (not while slurp is open).
    property bool recording: false
    property string recordingFile: ""
    property int recordingSeconds: 0

    // Pick a region and start; while recording, stop and save.
    function toggleRecording() {
        if (recording)
            recorder.signal(2); // SIGINT, like Ctrl+C: wf-recorder finishes the file properly
        else if (!recorder.running)
            recorder.running = true;
    }

    Process {
        id: recorder

        // The shell becomes wf-recorder (exec), so the signal above reaches it directly.
        // The file path is printed first: that line means recording has started.
        command: ["sh", "-c", `
            g=$(slurp) || exit 0    # Esc in slurp cancels
            mkdir -p "$1"
            f="$1/$(date +%F_%H-%M-%S).mp4"
            printf '%s\\n' "$f"
            exec wf-recorder -g "$g" -f "$f" >/dev/null 2>&1`, "sh", root.recordingDir]

        stdout: SplitParser {
            onRead: line => {
                root.recordingFile = line;
                root.recordingSeconds = 0;
                root.recording = true;
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (root.recording)
                root.notify("Recording saved", root.recordingFile, "video-x-generic");
            else if (exitCode === 127)
                root.notify("Can't record", "Install slurp and wf-recorder", "dialog-error");
            root.recording = false;
            root.recordingFile = "";
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.recordingSeconds++
    }

    // ==========================================
    // NIGHT LIGHT
    // ==========================================

    readonly property int warmTemperature: 4000
    // hyprsunset's neutral default; anything below counts as on.
    readonly property int normalTemperature: 6000

    property bool nightLightAvailable: false
    property bool nightLight: false

    function refreshNightLight() {
        if (!nightLightProc.running)
            nightLightProc.exec(["sh", "-c", `
                command -v hyprsunset >/dev/null || { echo missing; exit; }
                hyprctl hyprsunset temperature 2>/dev/null`]);
    }

    function toggleNightLight(announce) {
        const on = !nightLight;
        // hyprctl needs hyprsunset running; start it (it then follows hyprsunset.conf).
        nightLightProc.exec(["sh", "-c", `
            command -v hyprsunset >/dev/null || { echo missing; exit; }
            pgrep -x hyprsunset >/dev/null || { setsid -f hyprsunset >/dev/null 2>&1; sleep 0.5; }
            hyprctl hyprsunset temperature "$1" >/dev/null
            hyprctl hyprsunset temperature`, "sh", String(on ? warmTemperature : normalTemperature)]);
        if (announce)
            notify(on ? "Night light on" : "Night light off", "", on ? "weather-clear-night" : "weather-clear");
    }

    Process {
        id: nightLightProc

        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                root.nightLightAvailable = out !== "missing";
                const temperature = parseInt(out);
                // Not running (or not answering) means no filter: off.
                root.nightLight = !isNaN(temperature) && temperature < root.normalTemperature;
            }
        }
    }

    // hyprsunset's schedule can flip it on its own (evenings), so check now and then.
    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshNightLight()
    }

    // ==========================================
    // MIRRORING
    // ==========================================

    // The laptop panel (eDP-*) and the first other monitor, if one is connected.
    property string internalMonitor: ""
    property string externalMonitor: ""
    property bool mirrored: false
    readonly property bool canMirror: internalMonitor !== "" && externalMonitor !== ""

    function refreshMonitors() {
        if (!monitorProc.running)
            monitorProc.exec(["sh", "-c", `hyprctl monitors all -j | jq -r '
                (map(select(.name | startswith("eDP")))[0].name // "") as $int
                | (map(select(.name | startswith("eDP") | not))[0] // null) as $ext
                | if $int == "" or $ext == null then "" else "\\($int) \\($ext.name) \\($ext.mirrorOf)" end'`]);
    }

    // Mirror at the panel's 1080p so both show the same picture; extend with the
    // same rule as hypr/monitors.lua. (The Lua config has no `hyprctl keyword`; eval it.)
    function toggleMirror(announce) {
        if (!canMirror)
            return;
        const rule = mirrored
            ? `hl.monitor({ output = "${externalMonitor}", mode = "preferred", position = "auto-up", scale = "auto" })`
            : `hl.monitor({ output = "${externalMonitor}", mode = "1920x1080@60hz", position = "auto", scale = "1", mirror = "${internalMonitor}" })`;
        if (announce)
            notify(mirrored ? "Extending display" : "Mirroring display", externalMonitor, "video-display");
        mirrorProc.exec(["hyprctl", "eval", rule]);
    }

    Process {
        id: monitorProc

        stdout: StdioCollector {
            onStreamFinished: {
                const [internal, external, mirrorOf] = text.trim().split(" ");
                root.internalMonitor = internal ?? "";
                root.externalMonitor = external ?? "";
                root.mirrored = !!mirrorOf && mirrorOf !== "none";
            }
        }
    }

    Process {
        id: mirrorProc
        onExited: root.refreshMonitors()
    }

    // Plugging, unplugging and reconfiguring monitors all come through as events.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name.startsWith("monitor") || event.name === "configreloaded")
                root.refreshMonitors();
        }
    }

    Component.onCompleted: refreshMonitors()
}
