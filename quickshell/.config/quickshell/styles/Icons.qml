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
    readonly property string lockOpen: glyph(0xF033F)

    // Audio
    readonly property string volumeMute: glyph(0xF0581)
    readonly property string volumeLow: glyph(0xF057F)
    readonly property string volumeMedium: glyph(0xF0580)
    readonly property string volumeHigh: glyph(0xF057E)

    // Brightness: low, medium, high
    readonly property var brightnessLevels: [glyph(0xF00DE), glyph(0xF00DF), glyph(0xF00E0)]

    // Screen tools
    readonly property string record: glyph(0xF044A)
    readonly property string nightLight: glyph(0xF0594)
    readonly property string monitor: glyph(0xF0379)

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

    // Launcher
    readonly property string search: glyph(0xF0349)
    readonly property string apps: glyph(0xF003B)
    readonly property string terminal: glyph(0xF018D)
    readonly property string enterKey: glyph(0xF0311)

    // Clipboard
    readonly property string clipboard: glyph(0xF0192)
    readonly property string image: glyph(0xF02E9)
    readonly property string trash: glyph(0xF01B4)

    // Media
    readonly property string music: glyph(0xF075A)
    readonly property string play: glyph(0xF040A)
    readonly property string pause: glyph(0xF03E4)
    readonly property string skipNext: glyph(0xF04AD)
    readonly property string skipPrevious: glyph(0xF04AE)
    readonly property string shuffle: glyph(0xF049D)
    readonly property string shuffleOff: glyph(0xF049E)
    readonly property string repeat: glyph(0xF0456)
    readonly property string repeatOff: glyph(0xF0457)
    readonly property string repeatOnce: glyph(0xF0458)

    // Misc
    readonly property string chevronDown: glyph(0xF0140)
    readonly property string chevronLeft: glyph(0xF0141)
    readonly property string chevronRight: glyph(0xF0142)
    readonly property string calendar: glyph(0xF00ED)
    readonly property string refresh: glyph(0xF0450)
    readonly property string check: glyph(0xF012C)
    readonly property string close: glyph(0xF0156)
    readonly property string bell: glyph(0xF009A)
}
