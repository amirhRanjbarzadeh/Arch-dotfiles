pragma Singleton

import QtQuick

// Plain QtQuick (no Quickshell imports): the SDDM login theme bundles this file too.
QtObject {
    // ==========================================
    // WALLPAPER THEME
    // ==========================================

    // Colors derived from the chosen wallpaper ({ accent, surface, … } as "#rrggbb"),
    // set by the host: WallpaperService in the shell (from theme.json), Main.qml on
    // the login screen (from theme.conf.user). Anything missing uses the static palette.
    property var dynamic: ({})

    function pick(key, fallback) {
        return dynamic[key] ?? fallback;
    }

    // ==========================================
    // COLORS
    // ==========================================

    readonly property color background: "#000000"
    readonly property color popupBackground: "#000000"
    readonly property color surface: pick("surface", "#313244")
    readonly property color border: pick("border", "#45475a")
    readonly property color text: pick("text", "#cdd6f4")
    readonly property color muted: pick("muted", "#9399b2")
    readonly property color subtle: pick("subtle", "#a6adc8")
    readonly property color accent: pick("accent", "#cba6f7")
    readonly property color accentText: pick("accentText", "#11111b")
    // Second highlight color from the wallpaper (also Hyprland's border gradient).
    readonly property color secondary: pick("secondary", "#89b4fa")
    // Status colors stay fixed so they keep their meaning on any wallpaper.
    readonly property color success: "#a6e3a1"
    readonly property color warning: "#f9e2af"
    readonly property color error: "#f38ba8"
    readonly property color shadow: "#cc000000"

    // Bar geometry
    readonly property int barWidth: 520
    readonly property int barHeight: 34
    readonly property int barTopMargin: 6
    // Edge buttons' distance from the screen sides (matches Hyprland's gaps_out).
    readonly property int edgeMargin: 10

    // Popups / cards
    readonly property int popupRadius: 14
    readonly property int popupBorderWidth: 1
    readonly property int popupPadding: 14
    readonly property int itemRadius: 8

    // Motion
    readonly property int animDuration: 260
}
