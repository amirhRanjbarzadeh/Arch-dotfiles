#!/usr/bin/env bash
# Sets up these dotfiles on an Arch machine. Safe to re-run: every step skips
# what's already done.
#
#   ./install.sh                  packages, zsh extras, folders, services, stow
#   ./install.sh --skip-packages  everything but pacman
#   ./install.sh --sddm           also install the "island" login screen (sddm/install.sh)
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
skip_packages=false
with_sddm=false
for arg in "$@"; do
    case $arg in
        --skip-packages) skip_packages=true ;;
        --sddm) with_sddm=true ;;
        -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit ;;
        *) echo "unknown option: $arg (see --help)" >&2; exit 1 ;;
    esac
done

step() { printf '\n\033[1;35m==>\033[0m \033[1m%s\033[0m\n' "$*"; }

# ==========================================
# PACKAGES (all from the official repos)
# ==========================================

packages=(
    # Hyprland and its helpers
    hyprland hyprpaper hypridle hyprlock hyprsunset hyprpicker hyprpolkitagent hyprshutdown
    xdg-desktop-portal-hyprland
    # The bar (quickshell) and what its services talk to
    quickshell pipewire pipewire-pulse wireplumber networkmanager bluez bluez-utils upower
    brightnessctl libnotify ffmpeg jq python
    # Clipboard, screenshots, recording
    wl-clipboard cliphist grim slurp swappy wf-recorder
    # Terminal and shell
    kitty zsh fzf zoxide eza bat ttf-jetbrains-mono-nerd
    # Login screen (only used with --sddm)
    sddm xorg-xrandr
    # Apps the keybinds open (hypr/programs.lua)
    firefox dolphin
    # This script
    git stow
)

if ! $skip_packages; then
    step "Installing packages"
    sudo pacman -S --needed "${packages[@]}"
fi

# ==========================================
# ZSH: oh-my-zsh, powerlevel10k, plugins (.zshrc expects them here)
# ==========================================

step "Setting up oh-my-zsh"
omz=$HOME/.oh-my-zsh
custom=${ZSH_CUSTOM:-$omz/custom}

clone() { # url dest
    if [ -d "$2" ]; then
        echo "  have $(basename "$2")"
    else
        git clone --depth=1 "$1" "$2"
    fi
}

clone https://github.com/ohmyzsh/ohmyzsh.git "$omz"
clone https://github.com/romkatv/powerlevel10k.git "$custom/themes/powerlevel10k"
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    # Older setups keep them in oh-my-zsh's own plugins folder; that's fine too.
    if [ -d "$omz/plugins/$plugin" ]; then
        echo "  have $plugin"
    else
        clone "https://github.com/zsh-users/$plugin.git" "$custom/plugins/$plugin"
    fi
done

if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]; then
    echo "  making zsh your login shell"
    chsh -s "$(command -v zsh)"
fi

# ==========================================
# FOLDERS the shell and keybinds write to
# ==========================================

step "Creating folders"
# Wallpapers: the picker lists this folder. Screenshots and Screencasts: keybinds and the recorder.
mkdir -pv "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Screenshots" "$HOME/Videos/Screencasts"

# ==========================================
# SERVICES
# ==========================================

step "Enabling services"
for unit in NetworkManager bluetooth; do
    if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
        echo "  $unit already enabled"
    else
        sudo systemctl enable --now "$unit"
    fi
done

# ==========================================
# STOW: link each package's files into $HOME
# ==========================================

step "Linking dotfiles"
stow_packages=(hypr kitty quickshell zsh)
cd "$here"
# Dry run first: stow refuses to overwrite real files, and says which ones.
if ! conflicts=$(stow -n -t "$HOME" "${stow_packages[@]}" 2>&1); then
    echo "$conflicts" >&2
    echo >&2
    echo "Move those files out of the way (they're your current configs), then re-run." >&2
    exit 1
fi
stow -v -t "$HOME" "${stow_packages[@]}"

# ==========================================
# LOGIN SCREEN (optional)
# ==========================================

if $with_sddm; then
    step "Installing the login screen"
    "$here/sddm/install.sh"
    # Another display manager may own display-manager.service; swapping is your call.
    if ! systemctl is-enabled --quiet sddm 2>/dev/null; then
        if systemctl is-enabled --quiet display-manager 2>/dev/null; then
            echo "  another display manager is enabled; disable it, then: sudo systemctl enable sddm"
        else
            sudo systemctl enable sddm
        fi
    fi
fi

step "Done"
cat <<EOF
Next:
  - Put some images in ~/Pictures/Wallpapers, then SUPER+SHIFT+W to pick one
    (it themes the bar, borders, terminal and login screen).
  - Log out and start Hyprland$($with_sddm || echo ", or re-run with --sddm for the login screen").
EOF
