pragma Singleton

import QtQuick

QtObject {
    readonly property color background: "#000000"
    readonly property color popupBackground: "#000000"
    readonly property color surface: "#313244"
    readonly property color border: "#45475a"
    readonly property color text: "#cdd6f4"
    readonly property color muted: "#9399b2"
    readonly property color subtle: "#a6adc8"
    readonly property color accent: "#cba6f7"
    readonly property color success: "#a6e3a1"
    readonly property color warning: "#f9e2af"
    readonly property color error: "#f38ba8"
    readonly property color shadow: "#cc000000"

    readonly property int popupRadius: 14
    readonly property int popupBorderWidth: 1
    readonly property int popupPadding: 14
}
