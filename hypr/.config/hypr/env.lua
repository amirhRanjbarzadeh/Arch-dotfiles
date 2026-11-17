
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Qt apps take their style, icons and wallpaper colors from qt5ct (Qt5: VLC) and
-- qt6ct (Qt6: Dolphin), configs in qt/, colors from quickshell/scripts/sync-app-theme.py.
-- qt6ct also answers to "qt5ct", so this one name covers both.
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
