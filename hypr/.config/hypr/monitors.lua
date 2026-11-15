-- See https://wiki.hypr.land/configuring/core/monitors/
hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@60hz",
    position = "auto",
    scale    = "1",
})
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto-up",
    scale    = "auto",
})

for i = 1, 4 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "eDP-1", default = (i == 1) })
end
for i = 5, 8 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "HDMI-A-2", default = (i == 5) })
end