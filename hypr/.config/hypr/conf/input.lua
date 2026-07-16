-- ══════════════════════════════════════════
--   Ashen — Input
-- ══════════════════════════════════════════

hl.config({
    input = {
        -- Shipped default is plain "us": it is the safest bet for whoever clones
        -- this, and nobody inherits a layout they cannot type on. Add your own
        -- from Settings > System > Keyboard Layout (max 4 -- XKB has 4 groups).
        -- Whichever is first wins at login; Settings rewrites this list with the
        -- pick first, so the choice survives a reload/reboot.
        kb_layout = "us",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
            tap_to_click = true,
            scroll_factor = 0.5,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
