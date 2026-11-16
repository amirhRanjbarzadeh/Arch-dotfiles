import Quickshell.Services.Notifications
import QtQuick

// Owns the org.freedesktop.Notifications D-Bus name (replaces dunst/swaync)
// and keeps a queue of notifications waiting to be shown in the island.
QtObject {
    id: root

    // Oldest first; the island shows `current`.
    property var queue: []
    readonly property var current: queue.length > 0 ? queue[0] : null

    // Emitted when a notification already in the queue is replaced with new content.
    signal updated(var notification)

    function remove(notification) {
        queue = queue.filter(n => n !== notification);
    }

    // Timeout in ms for the island, or 0 to stay until closed.
    function timeoutFor(notification) {
        if (!notification || notification.urgency === NotificationUrgency.Critical)
            return 0;
        // expireTimeout is in seconds; <= 0 means "server default".
        return notification.expireTimeout > 0 ? Math.max(2000, notification.expireTimeout * 1000) : 5000;
    }

    property NotificationServer server: NotificationServer {
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: false

        onNotification: notification => {
            notification.tracked = true;

            // Apps can replace a notification in place (e.g. progress updates).
            if (root.queue.includes(notification)) {
                root.updated(notification);
                return;
            }

            notification.closed.connect(() => root.remove(notification));
            root.queue = root.queue.concat([notification]);
        }
    }
}
