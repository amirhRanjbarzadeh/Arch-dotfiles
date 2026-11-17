pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import "../styles"

// Wallpapers in ~/Pictures/Wallpapers: lists them, extracts each one's five main
// colors (cached), and applies one everywhere at once:
//   - hyprpaper, live over IPC
//   - ~/.local/state/wallpaper/current, the symlink hyprpaper.conf loads at startup
//   - ~/.local/state/wallpaper/theme.json, which Theme follows (the whole shell recolors)
//   - ~/.config/hypr/wallpaper-colors.lua, Hyprland's border colors (then `hyprctl reload`)
//   - ~/.config/kitty/wallpaper-theme.conf, kitty's colors (open terminals reload on SIGUSR1)
//   - the SDDM login screen, via scripts/sync-login-screen.sh
QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string directory: home + "/Pictures/Wallpapers"
    readonly property string stateDir: home + "/.local/state/wallpaper"
    readonly property string hyprColorsFile: home + "/.config/hypr/wallpaper-colors.lua"
    readonly property string kittyThemeFile: home + "/.config/kitty/wallpaper-theme.conf"

    // [{ path, name, mtime }], sorted by name.
    property var wallpapers: []
    property bool loading: false
    // Path of the wallpaper in use (resolved from the state symlink).
    property string current: ""
    // path → { mtime, colors: [{ hex, share }] } (5 colors, most common first).
    property var palettes: ({})
    // Path being sampled right now, if any, and its modification time.
    property string extracting: ""
    property int extractingMtime: 0

    function refresh() {
        loading = true;
        listProc.running = true;
        currentProc.running = true;
    }

    function paletteOf(path) {
        const wallpaper = wallpapers.find(w => w.path === path);
        const entry = palettes[path];
        return entry && wallpaper && entry.mtime === wallpaper.mtime ? entry.colors : null;
    }

    // ==========================================
    // THEME FILE → Theme (the whole shell, lock screen included, recolors live)
    // ==========================================

    property FileView themeFile: FileView {
        path: root.stateDir + "/theme.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                Theme.dynamic = JSON.parse(text()).colors ?? {};
            } catch (e) {
                Theme.dynamic = {};
            }
        }
        onLoadFailed: Theme.dynamic = {}
    }

    // ==========================================
    // LISTING
    // ==========================================

    property Process listProc: Process {
        command: ["sh", "-c", `find -L "$1" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) -printf '%T@\\t%p\\n'`, "sh", root.directory]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wallpapers = text.split("\n").filter(line => line.includes("\t")).map(line => {
                    const tab = line.indexOf("\t");
                    const path = line.slice(tab + 1);
                    const file = path.slice(path.lastIndexOf("/") + 1);
                    return {
                        path,
                        mtime: Math.floor(Number(line.slice(0, tab))),
                        name: file.replace(/\.[^.]+$/, "")
                    };
                }).sort((a, b) => a.name.localeCompare(b.name, undefined, { numeric: true, sensitivity: "base" }));
                root.loading = false;
                root.extractNext();
            }
        }
    }

    property Process currentProc: Process {
        command: ["readlink", "-f", root.stateDir + "/current"]
        stdout: StdioCollector {
            onStreamFinished: root.current = text.trim()
        }
    }

    // ==========================================
    // PALETTES: ffmpeg shrinks the image to 64×36 raw RGB, then k-means in JS
    // ==========================================

    property FileView paletteCache: FileView {
        path: Quickshell.cachePath("wallpaper-palettes.json")
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                root.palettes = JSON.parse(text());
            } catch (e) {
                root.palettes = {};
            }
            root.cacheReady = true;
            root.extractNext();
        }
        // No cache yet (first run): start from scratch.
        onLoadFailed: {
            root.cacheReady = true;
            root.extractNext();
        }
    }
    property bool cacheReady: false

    // Sample one wallpaper at a time, in list order.
    function extractNext() {
        if (extracting !== "" || loading || !cacheReady)
            return;
        const next = wallpapers.find(w => !paletteOf(w.path));
        if (!next)
            return;
        extracting = next.path;
        extractingMtime = next.mtime;
        sampleProc.command = ["sh", "-c", `ffmpeg -v error -i "$1" -frames:v 1 -vf scale=64:36:flags=area -f rawvideo -pix_fmt rgb24 - | od -An -tu1 -v`, "sh", next.path];
        sampleProc.running = true;
    }

    property Process sampleProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const path = root.extracting;
                const bytes = text.trim().split(/\s+/).map(Number).filter(n => !isNaN(n));
                // Keep only wallpapers still in the folder (drops renamed/deleted ones).
                const next = {};
                for (const w of root.wallpapers) {
                    if (root.palettes[w.path])
                        next[w.path] = root.palettes[w.path];
                }
                // An unreadable image still gets an (empty) entry so it isn't retried forever.
                next[path] = { mtime: root.extractingMtime, colors: bytes.length >= 15 ? root.extractColors(bytes, 5) : [] };
                root.palettes = next;
                root.paletteCache.setText(JSON.stringify(next));
            }
        }
        onExited: {
            root.extracting = "";
            root.extractNext();
        }
    }

    function hex(r, g, b) {
        return "#" + [r, g, b].map(v => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, "0")).join("");
    }

    // k-means over a 4-bit-per-channel histogram, seeded by weighted farthest-point
    // picks so small but distinct colors (a sunset over a dark sky) still show up.
    function extractColors(bytes, k) {
        const bins = new Map();
        for (let i = 0; i + 2 < bytes.length; i += 3) {
            const key = (bytes[i] >> 4) << 8 | (bytes[i + 1] >> 4) << 4 | bytes[i + 2] >> 4;
            const bin = bins.get(key) ?? { r: 0, g: 0, b: 0, n: 0 };
            bin.r += bytes[i];
            bin.g += bytes[i + 1];
            bin.b += bytes[i + 2];
            bin.n++;
            bins.set(key, bin);
        }
        const points = [...bins.values()].map(b => ({ r: b.r / b.n, g: b.g / b.n, b: b.b / b.n, n: b.n }));
        const total = points.reduce((sum, p) => sum + p.n, 0);
        const dist = (a, b) => (a.r - b.r) ** 2 + (a.g - b.g) ** 2 + (a.b - b.b) ** 2;

        let centers = [points.reduce((best, p) => p.n > best.n ? p : best)];
        while (centers.length < Math.min(k, points.length)) {
            let best = null, bestScore = -1;
            for (const p of points) {
                const score = p.n * Math.min(...centers.map(c => dist(p, c)));
                if (score > bestScore) {
                    bestScore = score;
                    best = p;
                }
            }
            centers.push(best);
        }
        centers = centers.map(c => ({ r: c.r, g: c.g, b: c.b, n: 0 }));

        for (let iter = 0; iter < 12; iter++) {
            const sums = centers.map(() => ({ r: 0, g: 0, b: 0, n: 0 }));
            for (const p of points) {
                let nearest = 0;
                for (let c = 1; c < centers.length; c++) {
                    if (dist(p, centers[c]) < dist(p, centers[nearest]))
                        nearest = c;
                }
                const s = sums[nearest];
                s.r += p.r * p.n;
                s.g += p.g * p.n;
                s.b += p.b * p.n;
                s.n += p.n;
            }
            centers = centers.map((c, i) => sums[i].n > 0 ? { r: sums[i].r / sums[i].n, g: sums[i].g / sums[i].n, b: sums[i].b / sums[i].n, n: sums[i].n } : c);
        }

        return centers.filter(c => c.n > 0).sort((a, b) => b.n - a.n).map(c => ({ hex: hex(c.r, c.g, c.b), share: c.n / total }));
    }

    // ==========================================
    // THEME: wallpaper colors → shell and Hyprland colors
    // ==========================================

    function toHsl(hexColor) {
        const r = parseInt(hexColor.slice(1, 3), 16) / 255, g = parseInt(hexColor.slice(3, 5), 16) / 255, b = parseInt(hexColor.slice(5, 7), 16) / 255;
        const max = Math.max(r, g, b), min = Math.min(r, g, b), l = (max + min) / 2, d = max - min;
        if (d === 0)
            return { h: 0, s: 0, l };
        const s = d / (1 - Math.abs(2 * l - 1));
        let h = max === r ? ((g - b) / d) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
        return { h: ((h * 60) + 360) % 360, s, l };
    }

    function fromHsl(h, s, l) {
        const c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = l - c / 2;
        const [r, g, b] = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
        return hex((r + m) * 255, (g + m) * 255, (b + m) * 255);
    }

    // The bar stays black, so colors are lifted to pastel lightness to read well on
    // it. The accent is the most vivid common color; the secondary is the vivid one
    // furthest from it in hue. Grey wallpapers give a near-neutral theme.
    function deriveTheme(colors) {
        const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
        const hueGap = (a, b) => Math.min(Math.abs(a - b), 360 - Math.abs(a - b));
        const hsl = colors.map(c => Object.assign(toHsl(c.hex), { share: c.share }));
        const vividness = c => c.s * (1 - Math.abs(c.l - 0.5)) * Math.pow(c.share, 0.3);

        const ranked = [...hsl].sort((a, b) => vividness(b) - vividness(a));
        const main = ranked[0];
        const colorful = main.s > 0.12 && main.l > 0.06 && main.l < 0.96;
        const sat = colorful ? clamp(main.s, 0.45, 0.8) : 0.06;

        const other = ranked.slice(1).filter(c => c.s > 0.15 && c.l > 0.06).sort((a, b) => hueGap(main.h, b.h) * b.s - hueGap(main.h, a.h) * a.s)[0];
        const secondHue = other && hueGap(main.h, other.h) > 20 ? other.h : (main.h + 40) % 360;
        const secondSat = other ? clamp(other.s, 0.4, 0.8) : sat;
        const tint = colorful ? 1 : 0.3;

        return {
            accent: fromHsl(main.h, sat, 0.76),
            secondary: fromHsl(secondHue, colorful ? secondSat : 0.06, 0.72),
            accentText: fromHsl(main.h, 0.3 * tint, 0.08),
            surface: fromHsl(main.h, 0.18 * tint, 0.22),
            border: fromHsl(main.h, 0.16 * tint, 0.31),
            text: fromHsl(main.h, 0.5 * tint, 0.89),
            subtle: fromHsl(main.h, 0.28 * tint, 0.74),
            muted: fromHsl(main.h, 0.18 * tint, 0.62)
        };
    }

    // kitty colors from the same palette. The background and greys take the
    // wallpaper's hue; the eight ANSI colors keep their usual hues (so red still
    // means error) but lean a little toward the accent, in the shell's pastels.
    function kittyTheme(colors, theme) {
        const main = toHsl(theme.accent);
        const colorful = main.s > 0.2;
        const tint = colorful ? 1 : 0.3;
        const lean = (h, by) => {
            if (!colorful)
                return h;
            const gap = ((main.h - h + 540) % 360) - 180;
            return (h + Math.max(-by, Math.min(by, gap * 0.25)) + 360) % 360;
        };
        const ansi = (h, s, l) => fromHsl(lean(h, 12), s, l);
        // red, green, yellow, blue, magenta, cyan
        const hues = [355, 115, 40, 215, 300, 180];

        const bg = fromHsl(main.h, 0.22 * tint, 0.11);
        const lines = [
            "# Generated by the quickshell wallpaper picker; overrides the base theme in kitty.conf.",
            `foreground ${theme.text}`,
            `background ${bg}`,
            `selection_foreground ${bg}`,
            `selection_background ${theme.accent}`,
            `cursor ${theme.accent}`,
            `cursor_text_color ${bg}`,
            `url_color ${theme.secondary}`,
            `active_border_color ${theme.accent}`,
            `inactive_border_color ${theme.border}`,
            `bell_border_color ${ansi(40, 0.7, 0.75)}`,
            `active_tab_foreground ${theme.accentText}`,
            `active_tab_background ${theme.accent}`,
            `inactive_tab_foreground ${theme.subtle}`,
            `inactive_tab_background ${theme.surface}`,
            `tab_bar_background ${bg}`,
            `mark1_foreground ${bg}`,
            `mark1_background ${theme.accent}`,
            `mark2_foreground ${bg}`,
            `mark2_background ${theme.secondary}`,
            `mark3_foreground ${bg}`,
            `mark3_background ${ansi(180, 0.55, 0.7)}`,
            `color0 ${fromHsl(main.h, 0.16 * tint, 0.30)}`,
            `color8 ${fromHsl(main.h, 0.14 * tint, 0.42)}`,
            `color7 ${theme.subtle}`,
            `color15 ${theme.text}`
        ];
        hues.forEach((h, i) => {
            lines.push(`color${i + 1} ${ansi(h, 0.65, 0.72)}`);
            lines.push(`color${i + 9} ${ansi(h, 0.75, 0.80)}`);
        });
        return lines.join("\n") + "\n";
    }

    // ==========================================
    // APPLY
    // ==========================================

    function apply(path) {
        const colors = paletteOf(path);
        current = path;
        const args = [path, stateDir, hyprColorsFile, "", "", Quickshell.shellDir + "/scripts/sync-login-screen.sh", kittyThemeFile, ""];
        if (colors && colors.length > 0) {
            const theme = deriveTheme(colors);
            args[3] = JSON.stringify({ wallpaper: path, palette: colors.map(c => c.hex), colors: theme }, null, 2) + "\n";
            const bare = h => h.slice(1);
            args[4] = `-- Generated by the quickshell wallpaper picker from ${path}\nreturn { accent = "${bare(theme.accent)}", secondary = "${bare(theme.secondary)}", inactive = "${bare(theme.border)}" }\n`;
            args[7] = kittyTheme(colors, theme);
        }
        // An image without a palette (unreadable, or still sampling) keeps the current colors.
        Quickshell.execDetached(["sh", "-c", `
            img=$1 state=$2 hypr=$3 theme=$4 lua=$5 sync=$6 kitty=$7 kittyconf=$8
            mkdir -p "$state" && ln -sfn "$img" "$state/current"
            hyprctl hyprpaper wallpaper ",$img" >/dev/null 2>&1
            # hyprpaper can stop answering requests (it still says ok); if the
            # switch didn't take, or it isn't running, restart it: it starts on the symlink.
            if ! hyprctl hyprpaper listactive 2>/dev/null | grep -qF -- ": $img"; then
                pkill -x hyprpaper
                setsid -f hyprpaper >/dev/null 2>&1
            fi
            if [ -n "$theme" ]; then
                printf '%s' "$theme" > "$state/theme.json.tmp" && mv -f "$state/theme.json.tmp" "$state/theme.json"
                printf '%s' "$lua" > "$hypr.tmp" && mv -f "$hypr.tmp" "$hypr" && hyprctl reload >/dev/null
                # Every open kitty re-reads its config on SIGUSR1.
                printf '%s' "$kittyconf" > "$kitty.tmp" && mv -f "$kitty.tmp" "$kitty" && pkill -USR1 -x kitty
            fi
            # Login screen: same wallpaper and colors (no-op until sddm/install.sh has run).
            "$sync"`, "sh", ...args]);
    }

    Component.onCompleted: refresh()
}
