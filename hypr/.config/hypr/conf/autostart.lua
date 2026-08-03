-- ══════════════════════════════════════════
--   Ashen — Autostart
-- ══════════════════════════════════════════

local function start(cmd)
    hl.on("hyprland.start", function()
        hl.exec_cmd(cmd)
    end)
end

start("awww-daemon")
-- Brings back the last wallpaper: awww for images/gif, mpvpaper for video
-- From the checkout when there is one, otherwise from PATH (packaged install)
start("sh -c 'S=\"$HOME/ashen/scripts/ashen-wallpaper-restore.sh\"; [ -x \"$S\" ] || S=ashen-wallpaper-restore.sh; exec \"$S\"'")
start("quickshell -c ashen")
-- Ashen generates ~/.config/ashen/hypridle.conf from Settings; the shipped
-- one is only the fallback for the very first boot.
start("sh -c 'CFG=\"$HOME/.config/ashen/hypridle.conf\"; [ -f \"$CFG\" ] || CFG=\"$HOME/.config/hypr/hypridle.conf\"; exec hypridle -c \"$CFG\"'")
start("wl-paste --type text --watch cliphist store")
start("wl-paste --type image --watch cliphist store")
