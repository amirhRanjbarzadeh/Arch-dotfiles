-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/configuring/layouts/dwindle-layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/configuring/layouts/master-layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/configuring/layouts/scrolling-layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
hl.layer_rule({
    name  = "swaync-blur",
    match = { namespace = "^swaync-(notification-window|control-center)$" },
    blur = true,
    ignore_alpha = 0.5,
})

-- The control center is one layer surface, so Hyprland animates it (not swaync's CSS).
hl.layer_rule({
    name  = "swaync-slide",
    match = { namespace = "^swaync-control-center$" },
    animation = "slide right",
})
-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name  = "firefox-pip",
    match = { class = "^firefox_firefox$", title = "Picture-in-Picture" },
    float = true,
    pin   = true,
    size  = "480 270",
    move  = "monitor_w-500 monitor_h-290"
})

hl.layer_rule({
    name  = "waybar-slide",
    match = { namespace = "^waybar$" },
    animation = "slide top",
})

hl.window_rule({
    name  = "float-bar-popups",
    match = { class = "^(org\\.pulseaudio\\.pavucontrol|blueman-manager|org\\.gnome\\.Settings)$" },

    float = true,
    size  = "700 500",
})

hl.window_rule({
    name  = "gsimplecal-popup",
    match = { class = "^gsimplecal$" },

    float = true,
    move  = "10 45",
})

hl.window_rule({
    name  = "quickshell-floating",
    match = { class = "^org.quickshell$" },

    float = true,
})
