-- ══════════════════════════════════════════
--   Ashen — Keybinds
-- ══════════════════════════════════════════

local mod = "SUPER"

-- Wallpaper, notificaciones, centro de configuracion
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("qs ipc -c ashen call wallpaper open"))
hl.bind(mod .. " + N",         hl.dsp.exec_cmd("qs ipc -c ashen call notifications toggle"))
hl.bind(mod .. " + I",         hl.dsp.exec_cmd("qs ipc -c ashen call settings toggle"))
hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("sh -c 'qs ipc -c ashen call clipboard toggle'"), { locked = true })
hl.bind("SUPER + comma", hl.dsp.exec_cmd("sh -c 'qs ipc -c ashen call emojis toggle'"), { locked = true })
hl.bind("SUPER + period", hl.dsp.exec_cmd("sh -c 'qs ipc -c ashen call glyph toggle'"), { locked = true })


-- Mover/redimensionar ventanas flotantes con el mouse (SUPER + arrastrar)
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


-- Apps
hl.bind(mod .. " + T",     hl.dsp.exec_cmd("kitty --single-instance --listen-on=unix:/tmp/kitty-ashen.sock"))
hl.bind(mod .. " + E",     hl.dsp.exec_cmd("nemo"))
hl.bind(mod .. " + W",     hl.dsp.exec_cmd("brave"))
hl.bind(mod .. " + C",     hl.dsp.exec_cmd("codium"))
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd("qs ipc -c ashen call launcher toggle"), { release = true })

-- Ventanas
hl.bind(mod .. " + Q",       hl.dsp.window.close())
hl.bind(mod .. " + F",       hl.dsp.window.fullscreen())
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P",       hl.dsp.window.pseudo())

-- Foco
hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left"  }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up"    }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down"  }))

-- Workspaces y mover ventanas
for i = 1, 9 do
    hl.bind(mod .. " + " .. i,           hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + ALT + " .. i,     hl.dsp.window.move({ workspace = i }))
end

-- Workspace 10
hl.bind(mod .. " + 0",       hl.dsp.focus({ workspace = 10 }))
hl.bind(mod .. " + ALT + 0", hl.dsp.window.move({ workspace = 10 }))
	
hl.bind(mod .. " + ALT + left",  hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(mod .. " + ALT + right", hl.dsp.window.move({ workspace = "e+1" }))

-- Special Workspaces
hl.bind(mod .. " + M", hl.dsp.workspace.toggle_special("music"))
hl.bind(mod .. " + D", hl.dsp.workspace.toggle_special("discord"))

-- Sistema
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("sh -c 'DEFAULT_TARGET_DIR=/home/adolf-arch/Pictures/Screenshots grimblast copysave area && qs ipc -c ashen call notifications screenshot'"))
hl.bind(mod .. " + L",         hl.dsp.exec_cmd("qs ipc -c ashen call lockscreen lock"))

-- Audio y brillo
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("sh -c 'wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 1.0 && qs ipc -c ashen call osd volume'"),  { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("sh -c 'wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && qs ipc -c ashen call osd volume'"),  { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("sh -c 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && qs ipc -c ashen call osd volume'"), { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("sh -c 'brightnessctl set 5%+ && qs ipc -c ashen call osd brightness'"),     { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("sh -c 'brightnessctl set 5%- && qs ipc -c ashen call osd brightness'"),     { locked = true, repeating = true })
