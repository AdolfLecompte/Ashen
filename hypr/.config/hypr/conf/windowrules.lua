-- ══════════════════════════════════════════
--   Ashen — Window Rules
-- ══════════════════════════════════════════

-- Special Workspaces
hl.window_rule({ match = { class = "brave-cinhimbnkkaeohfgghhklpknlkffjgod-Default" }, workspace = "special:music"   })
hl.window_rule({ match = { class = "discord"        }, workspace = "special:discord" })
hl.window_rule({ match = { class = "obsidian"        }, workspace = "special:notes" })

-- Floating
hl.window_rule({ match = { class = "pavucontrol"     }, float = true })

-- Opacity: global active/inactive_opacity from decoration.lua drives every
-- window, except browsers: their content is dense enough that the frosted
-- glass made it unreadable, so they get a bump.
-- brave.* also catches the PWAs (whatsapp, youtube music...), whose class is
-- brave-<app-id>-Default. Steam's UI is CEF-based and just as dense.
-- `override` is mandatory: without it Hyprland multiplies this value by the
-- global active/inactive_opacity instead of replacing it.
hl.window_rule({ match = { class = "^(brave.*|firefox|chromium|google-chrome|steam)$" }, opacity = "0.85 override 0.80 override" })

-- File managers and the portal's file chooser get the same bump, for the same
-- reason: they are a column of small text over whatever the wallpaper happens
-- to be, and at the global 0.70 a light wallpaper swallowed the file names.
hl.window_rule({ match = { class = "^(nemo|thunar|org.gnome.Nautilus|xdg-desktop-portal-gtk|zenity|file-roller)$" }, opacity = "0.96 override 0.92 override" })

-- Bar blur
hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:.*" }, ignore_alpha = 0.05 })
