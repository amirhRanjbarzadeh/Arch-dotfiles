#!/usr/bin/env bash
# Builds the "island" SDDM theme and installs it system-wide.
#
# The theme reuses the quickshell lock screen's QML (theme, icons, clock,
# password field, card, buttons), and bundles the JetBrainsMono Nerd Font and
# the hyprpaper wallpaper, because the sddm user can't read your home directory.
# Re-run after changing any of those.
#
#   ./install.sh          build, then install with sudo and make it the active theme
#   ./install.sh --test   build and preview in a window (no root, nothing installed)
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
qs="$here/../quickshell/.config/quickshell"
name=island
dest=/usr/share/sddm/themes/$name

build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT

cp -r "$here/theme/." "$build/"
mkdir -p "$build/styles" "$build/components" "$build/lock" "$build/fonts"
cp "$qs/styles/"{Theme.qml,Icons.qml,qmldir} "$build/styles/"
cp "$qs/components/"{Card.qml,KeyHints.qml} "$build/components/"
cp "$qs/lock/"{LockClock.qml,PasswordField.qml,HoldButton.qml} "$build/lock/"

for font in JetBrainsMonoNerdFont-Regular.ttf JetBrainsMonoNerdFont-Bold.ttf; do
    src=$(fc-list -f '%{file}\n' | grep -m1 "/$font\$" || true)
    if [ -n "$src" ]; then
        cp "$src" "$build/fonts/"
    else
        echo "warning: $font not found; the clock and icons will fall back" >&2
    fi
done

# Same wallpaper as hyprpaper, so logging in lands on the picture you just saw.
wallpaper=$(sed -n 's/^\s*path\s*=\s*//p' "$HOME/.config/hypr/hyprpaper.conf" 2>/dev/null | head -n1)
wallpaper=${wallpaper/#\~/$HOME}
if [ -f "$wallpaper" ]; then
    ext=${wallpaper##*.}
    cp "$wallpaper" "$build/background.$ext"
    sed -i "s|^background=.*|background=background.$ext|" "$build/theme.conf"
else
    echo "warning: wallpaper not found in hyprpaper.conf; background stays black" >&2
fi

if [ "${1:-}" = "--test" ]; then
    sddm-greeter-qt6 --test-mode --theme "$build"
    exit
fi

if ! command -v xrandr >/dev/null; then
    echo "Installing xrandr (Xsetup uses it to run the login screen at 60 Hz)…"
    sudo pacman -S --needed --noconfirm xorg-xrandr
fi

chmod -R u=rwX,go=rX "$build"
sudo rm -rf "$dest"
sudo cp -r "$build" "$dest"
# Our own Xsetup, kept outside the sddm package so upgrades don't overwrite it.
sudo install -Dm755 "$here/Xsetup" /etc/sddm/Xsetup
printf '[Theme]\nCurrent=%s\n\n[X11]\nDisplayCommand=/etc/sddm/Xsetup\n' "$name" | sudo install -Dm644 /dev/stdin /etc/sddm.conf.d/theme.conf

# Avatar: SDDM reads faces from its own directory.
if [ -f "$HOME/.face" ]; then
    sudo install -Dm644 "$HOME/.face" "/usr/share/sddm/faces/$USER.face.icon"
fi

echo "Installed $dest, set it as the SDDM theme, and set the login screen to 60 Hz."
