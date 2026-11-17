import Quickshell
import Quickshell.Widgets
import QtQuick
import "../styles"

// A notification's image or app icon in a rounded tile, with a bell as fallback.
ClippingRectangle {
    id: root

    property var notification: null
    property bool critical: false
    property int size: 40

    // Inline image (avatars, screenshots) wins; then the app icon, desktop entry and app name.
    // Theme icon names are checked so a missing icon falls through instead of
    // rendering the checkerboard "missing" texture.
    function resolveIcon(icon) {
        if (!icon)
            return "";
        if (icon.startsWith("image://icon/"))
            icon = icon.slice("image://icon/".length);
        else if (icon.startsWith("/"))
            return "file://" + icon;
        else if (icon.includes("://"))
            return icon;
        return Quickshell.iconPath(icon, true);
    }

    readonly property string source: {
        const n = notification;
        if (!n)
            return "";
        return resolveIcon(n.image) || resolveIcon(n.appIcon) || resolveIcon(n.desktopEntry) || resolveIcon(n.appName.toLowerCase());
    }

    implicitWidth: size
    implicitHeight: size
    radius: size / 4
    color: Theme.surface

    Image {
        id: image
        anchors.fill: parent
        source: root.source
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready
    }

    Text {
        anchors.centerIn: parent
        visible: !image.visible
        text: Icons.bell
        color: root.critical ? Theme.error : Theme.accent
        font.pixelSize: root.size / 2
    }
}
