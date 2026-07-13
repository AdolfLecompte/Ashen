-- ══════════════════════════════════════════
--   Ashen — Autostart
-- ══════════════════════════════════════════

local function start(cmd)
    hl.on("hyprland.start", function()
        hl.exec_cmd(cmd)
    end)
end

start("awww-daemon")
start("quickshell -c ashen")
start("hypridle")
start("wl-paste --type text --watch cliphist store")
start("wl-paste --type image --watch cliphist store")
start("nm-applet --indicator")
start("blueman-applet")
start("/usr/lib/plasma-browser-integration/plasma-browser-integration-host")
