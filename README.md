# dotfiles

My Arch + Hyprland desktop: a [Quickshell](https://quickshell.org) bar built around a single
"island" that morphs into each panel, a matching lock screen and SDDM login screen, and one
wallpaper picker that themes all of it.

## Install

```sh
git clone <this repo> ~/src/dotfiles
cd ~/src/dotfiles
./install.sh            # packages, oh-my-zsh, folders, services, then stow
./install.sh --sddm     # same, plus the login screen
```

`install.sh` is safe to re-run. It installs from the official repos only (no AUR helper
needed). If a real config file is in the way, it stops before linking anything and lists the
files to move. `--skip-packages` skips pacman.

Afterwards, put images in `~/Pictures/Wallpapers` and press <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>W</kbd>.

## What's in it

| Folder | Linked to | What it is |
| --- | --- | --- |
| `hypr/` | `~/.config/hypr` | Hyprland (Lua config), hypridle, hyprlock, hyprpaper, hyprsunset |
| `quickshell/` | `~/.config/quickshell` | The bar, lock screen and their services |
| `kitty/` | `~/.config/kitty` | Terminal |
| `zsh/` | `~/.zshrc`, `~/.p10k.zsh` | oh-my-zsh + powerlevel10k, fzf, zoxide, eza |
| `qt/` | `~/.config/qt5ct`, `qt6ct` | Qt apps (Dolphin, VLC): Breeze style, breeze-dark icons, wallpaper colors |
| `gtk/` | `~/.config/gtk-3.0`, `gtk-4.0` | GTK apps (pavucontrol, Firefox's UI): adw-gtk3 dark, wallpaper colors |
| `nvim/` | `~/.config/nvim` | [LazyVim](https://lazyvim.org), Catppuccin, QML support for the Quickshell config |
| `sddm/` | *not stowed* | Login theme; `sddm/install.sh` builds and installs it system-wide |

### The bar

Everything opens in the island at the top of the screen:

- **Status:** workspaces, clock (click for a calendar), Wi-Fi, Bluetooth, volume (scroll to change), battery, a red recording timer while recording (click to stop), and a coffee cup while caffeine is on (click to turn off). Scroll down on the bar for the system tray.
- **Panels:** Wi-Fi, Bluetooth, controls (volume, brightness, night light, caffeine, display mirroring, screen recording), notification history, media player, app launcher, clipboard history, wallpaper picker, power menu.
- **Popups:** notifications, plus volume/brightness/now-playing popups when you press the media keys.

Scripts and keybinds drive it through IPC: `qs ipc show` lists the commands, for example
`qs ipc call bar toggle wifi`.

### Wallpaper theming

Picking a wallpaper extracts its main colors and applies them everywhere at once:

- the bar and lock screen (`~/.local/state/wallpaper/theme.json`)
- Hyprland's window borders (`hypr/wallpaper-colors.lua`, generated)
- kitty, live in open terminals (`kitty/wallpaper-theme.conf`, generated)
- Qt, KDE and GTK apps like Dolphin, VLC and pavucontrol (`wallpaper-colors.*` in `qt/` and
  `gtk/`, plus `~/.config/kdeglobals`, all generated); apps already open pick it up when reopened
- the SDDM login screen, once `--sddm` has installed it

The generated files are gitignored. Until you pick a wallpaper, everything uses the static
Catppuccin colors.

### Locking

<kbd>Super</kbd>+<kbd>L</kbd>, idling and suspending all lock through hypridle. hypridle uses the
Quickshell lock screen, and falls back to hyprlock if the bar isn't running, so the screen still
locks even if the shell has crashed.

## Keybinds

<kbd>Super</kbd> is the main modifier.

| Keys | Action |
| --- | --- |
| `Super` `Return` / `B` / `E` / `C` | Terminal / browser / file manager / editor |
| `Super` `D` | App launcher |
| `Super` `W` | Close window |
| `Super` `V` / `F` / `Shift` `F` | Float / fullscreen / maximize |
| `Super` `J`, `Super` `Shift` `P` | Toggle split, pseudo-tile |
| `Super` `←↑→↓` (+`Shift`) | Focus (move) window |
| `Super` `1`–`0` (+`Shift`) | Go to (move window to) workspace |
| `Super` `Ctrl` `←→` (+`Shift`) | Previous/next workspace (move window there) |
| `Super` `S`, `Super` `Alt` `S` | Scratchpad: show, move window to |
| `Super` `L` | Lock |
| `Super` `Escape` | Power menu |
| `Super` `M` | Log out |
| `Super` `N` / `Ctrl` `N` | Notification history / clear it |
| `Super` `Shift` `V` | Clipboard history |
| `Super` `Shift` `W` | Wallpaper picker |
| `Super` `Ctrl` `B` | Hide/show the bar |
| `Super` `R` | Restart the bar |
| `Super` `Shift` `A` / `S` | Screenshot: full screen / region (saved and copied) |
| `Super` `Shift` `E` | Region screenshot, annotate in swappy |
| `Super` `Shift` `R` | Record a region; again to stop |
| `Super` `Shift` `N` | Night light |
| `Super` `Shift` `I` | Caffeine: keep the screen on (no dim, lock or idle suspend) |
| `Super` `Shift` `C` | Color picker (hex to clipboard) |
| `Super` `P` | Mirror/extend the external monitor |

## Machine-specific bits

A few settings are specific to my laptop. Change them on a different machine:

- `hypr/monitors.lua`: the panel is `eDP-1` at 1080p60, and workspaces 5–8 go to `HDMI-A-2`.
- `hypr/hypridle.conf`: dims an `asus::kbd_backlight`.
- `hypr/autostart.lua`: starts v2rayN from `~/Applications`.
- `sddm/Xsetup`: forces the login screen to 60 Hz because the panel flickers at 144 Hz.
