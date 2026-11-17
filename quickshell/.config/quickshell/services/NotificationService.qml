import Quickshell.Services.Notifications
import QtQuick

// Owns the org.freedesktop.Notifications D-Bus name (replaces dunst/swaync).
//
// Every notification lives in two places:
//   queue    waiting to pop up in the island (oldest first; the island shows `current`)
//   history  everything still open, newest first, for the history panel
//
// A popup that times out or is closed with Escape only leaves the queue; it stays
// in history (and open for the sending app) until you dismiss it there.
QtObject {
    id: root

    // How many notifications history keeps; older ones are dismissed.
    property int historyLimit: 50

    property var queue: []
    readonly property var current: queue.length > 0 ? queue[0] : null

    // [{ notification, time }], newest first.
    property var history: []
    // Arrived since the history panel was last opened.
    property int unreadCount: 0

    // Emitted when a notification already in the queue is replaced with new content.
    signal updated(var notification)

    // Stop popping this notification up, but keep it in history.
    function hide(notification) {
        if (!notification)
            return;
        // Transient notifications aren't meant to be kept around.
        if (notification.transient) {
            notification.expire();
            return;
        }
        queue = queue.filter(n => n !== notification);
    }

    // The history panel is showing everything: clear the unread badge and drop
    // queued popups (transient ones stay, since history doesn't list them for long).
    function markSeen() {
        const transientOnly = queue.filter(n => n.transient);
        if (transientOnly.length !== queue.length)
            queue = transientOnly;
        unreadCount = 0;
    }

    function clearHistory() {
        // Copy first: each dismiss removes its entry from `history`.
        for (const entry of history.slice())
            entry.notification.dismiss();
        unreadCount = 0;
    }

    // Timeout in ms for the island, or 0 to stay until closed.
    function timeoutFor(notification) {
        if (!notification || notification.urgency === NotificationUrgency.Critical)
            return 0;
        // expireTimeout is in seconds; <= 0 means "server default".
        return notification.expireTimeout > 0 ? Math.max(2000, notification.expireTimeout * 1000) : 5000;
    }

    function track(notification, time) {
        notification.closed.connect(() => root.forget(notification));
        history = [{ notification, time }].concat(history);

        // Dismissing drops the entry from history via forget().
        for (const entry of history.slice(historyLimit))
            entry.notification.dismiss();
    }

    function forget(notification) {
        queue = queue.filter(n => n !== notification);
        history = history.filter(entry => entry.notification !== notification);
        unreadCount = Math.min(unreadCount, history.length);
    }

    property NotificationServer server: NotificationServer {
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;

            // Apps can replace a notification in place (e.g. progress updates).
            if (root.history.some(entry => entry.notification === notification)) {
                if (root.queue.includes(notification))
                    root.updated(notification);
                return;
            }

            root.track(notification, new Date());
            // Count first: queueChanged may clear it straight away (history open).
            root.unreadCount += 1;
            root.queue = root.queue.concat([notification]);
        }
    }

    // Notifications survive a config reload (keepOnReload), but this list doesn't:
    // rebuild it from the server. Arrival times are lost, so they show as "now".
    Component.onCompleted: {
        const now = new Date();
        for (const notification of server.trackedNotifications.values)
            track(notification, now);
    }
}
