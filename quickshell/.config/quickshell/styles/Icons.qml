pragma Singleton

import QtQuick

// Nerd Font (Material Design) glyphs, by name, so views don't embed raw codepoints.
QtObject {
    function glyph(code) {
        return String.fromCodePoint(code);
    }

    // Wi-Fi
    readonly property string wifiOff: glyph(0xF092D)
    readonly property string wifiOutline: glyph(0xF092F)
    readonly property var wifiLevels: [glyph(0xF091F), glyph(0xF0922), glyph(0xF0925), glyph(0xF0928)]
    readonly property string lock: glyph(0xF033E)

    // Audio
    readonly property string volumeMute: glyph(0xF0581)
    readonly property string volumeLow: glyph(0xF057F)
    readonly property string volumeMedium: glyph(0xF0580)
    readonly property string volumeHigh: glyph(0xF057E)

    // Brightness: low, medium, high
    readonly property var brightnessLevels: [glyph(0xF00DE), glyph(0xF00DF), glyph(0xF00E0)]

    // Bluetooth
    readonly property string bluetooth: glyph(0xF00AF)
    readonly property string bluetoothConnected: glyph(0xF00B1)
    readonly property string bluetoothOff: glyph(0xF00B2)
    readonly property string link: glyph(0xF0337)
    readonly property string linkOff: glyph(0xF0338)

    // Battery: 10% … 90% steps, then full
    readonly property var batteryLevels: [glyph(0xF007A), glyph(0xF007B), glyph(0xF007C), glyph(0xF007D), glyph(0xF007E), glyph(0xF007F), glyph(0xF0080), glyph(0xF0081), glyph(0xF0082), glyph(0xF0079)]
    readonly property string batteryCharging: glyph(0xF0084)
    readonly property string batteryAlert: glyph(0xF0083)

    // Power menu
    readonly property string arch: glyph(0xF303)
    readonly property string power: glyph(0xF0425)
    readonly property string logout: glyph(0xF0343)
    readonly property string sleep: glyph(0xF04B2)
    readonly property string restart: glyph(0xF0709)

    // Misc
    readonly property string chevronDown: glyph(0xF0140)
    readonly property string refresh: glyph(0xF0450)
    readonly property string check: glyph(0xF012C)
    readonly property string close: glyph(0xF0156)
    readonly property string bell: glyph(0xF009A)
}
