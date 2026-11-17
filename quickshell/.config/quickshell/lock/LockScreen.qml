pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import QtQuick

// Session lock. Locking snapshots each screen first, so the lock surface can
// start from the desktop and blur it away; unlocking plays that in reverse.
// Lock with `qs ipc call lock lock` (hypridle's lock_cmd does this).
Scope {
    id: root

    property var media // MediaService
    property var network // NetworkService
    property var notifications // NotificationService

    readonly property bool locked: sessionLock.locked
    // Snapshot being taken, the session isn't locked yet.
    property bool preparing: false
    // Password accepted: surfaces play the exit animation, then the session unlocks.
    property bool unlocking: false
    // Bumped every lock so snapshot images reload instead of using the cache.
    property int lockSerial: 0

    // Password typed so far (shared by every screen) and auth state.
    property string buffer: ""
    readonly property bool checking: pam.active
    property string message: ""
    property bool messageIsError: false
    // Bumped on every failed attempt; surfaces shake on change.
    property int failCount: 0
    property bool capsLock: false
    // No input for a while: only the clock stays, the card fades away.
    property bool idle: false

    readonly property string snapshotDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-lock"
    property string wallpaper: ""
    property string userName: Quickshell.env("USER") || "user"
    property string realName: ""
    property string hostName: ""
    readonly property string displayName: realName !== "" ? realName : userName
    readonly property string avatar: Quickshell.env("HOME") + "/.face"

    // How long the surfaces take to fade out on unlock; keep in sync with LockSurface.
    readonly property int exitDuration: 650

    function snapshotPath(screenName) {
        return "file://" + snapshotDir + "/" + screenName + ".ppm";
    }

    function lock() {
        if (sessionLock.locked || preparing)
            return;
        preparing = true;
        const outputs = Quickshell.screens.map(screen => screen.name);
        snapshotProcess.command = ["sh", "-c", 'dir="$1"; shift; mkdir -p -m 700 "$dir"; for o in "$@"; do grim -t ppm -o "$o" "$dir/$o.ppm" & done; wait', "sh", snapshotDir].concat(outputs);
        snapshotProcess.running = true;
        // Never let a stuck grim keep the session unlocked.
        snapshotTimeout.restart();
    }

    function engage() {
        if (!preparing)
            return;
        snapshotTimeout.stop();
        preparing = false;
        buffer = "";
        message = "";
        messageIsError = false;
        unlocking = false;
        idle = false;
        lockSerial++;
        sessionLock.locked = true;
        refreshCapsLock();
        idleTimer.restart();
    }

    function submit() {
        if (buffer === "" || pam.active || unlocking)
            return;
        message = "";
        messageIsError = false;
        if (!pam.start())
            fail("Couldn't start authentication");
    }

    function fail(text) {
        buffer = "";
        message = text;
        messageIsError = true;
        failCount++;
        wake();
    }

    function succeed() {
        buffer = "";
        message = "";
        unlocking = true;
        idleTimer.stop();
        unlockTimer.restart();
    }

    function wake() {
        idle = false;
        if (locked && !unlocking)
            idleTimer.restart();
    }

    function type(text) {
        if (pam.active || unlocking)
            return;
        buffer += text;
        if (messageIsError)
            message = "";
    }

    function backspace(all) {
        if (pam.active || unlocking)
            return;
        buffer = all ? "" : buffer.slice(0, -1);
    }

    function refreshCapsLock() {
        capsProcess.running = true;
    }

    PamContext {
        id: pam

        configDirectory: Quickshell.shellPath("lock/pam")
        config: "password.conf"
        user: root.userName

        onPamMessage: {
            if (responseRequired)
                respond(root.buffer);
            else if (message !== "") {
                root.message = message;
                root.messageIsError = messageIsError;
            }
        }

        onCompleted: result => {
            if (result === PamResult.Success)
                root.succeed();
            else if (result === PamResult.MaxTries)
                root.fail("Too many attempts, try again later");
            else
                root.fail("Wrong password");
        }

        onError: () => root.fail("Authentication error")
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            id: surface

            color: "black"

            LockSurface {
                anchors.fill: parent
                lock: root
                screenName: surface.screen?.name ?? ""
            }
        }
    }

    Process {
        id: snapshotProcess
        onExited: root.engage()
    }

    Timer {
        id: snapshotTimeout
        interval: 1500
        onTriggered: root.engage()
    }

    Timer {
        id: unlockTimer
        interval: root.exitDuration
        onTriggered: {
            sessionLock.locked = false;
            root.unlocking = false;
            cleanupProcess.running = true;
        }
    }

    Timer {
        id: idleTimer
        interval: 12000
        onTriggered: {
            if (root.buffer === "" && !root.checking && !root.unlocking)
                root.idle = true;
        }
    }

    // Snapshots of the desktop shouldn't outlive the lock.
    Process {
        id: cleanupProcess
        command: ["rm", "-rf", root.snapshotDir]
    }

    // Caps Lock state of the main keyboard (Qt doesn't expose it).
    Process {
        id: capsProcess
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards ?? [];
                    const main = keyboards.find(k => k.main) ?? keyboards[0];
                    root.capsLock = main?.capsLock ?? false;
                } catch (e) {
                    root.capsLock = false;
                }
            }
        }
    }

    // Full name from the passwd entry, for the greeting.
    Process {
        running: true
        command: ["getent", "passwd", root.userName]
        stdout: StdioCollector {
            onStreamFinished: root.realName = (text.split(":")[4] ?? "").split(",")[0].trim()
        }
    }

    FileView {
        path: "/etc/hostname"
        onLoaded: root.hostName = text().trim()
    }

    // Same wallpaper as hyprpaper; used when there's no snapshot.
    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/hyprpaper.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const match = text().match(/^\s*path\s*=\s*(.+?)\s*$/m);
            root.wallpaper = match ? match[1].replace(/^~/, Quickshell.env("HOME")) : "";
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        function isLocked(): bool {
            return root.locked;
        }
    }
}
