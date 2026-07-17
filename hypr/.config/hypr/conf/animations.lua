-- ══════════════════════════════════════════
--   Ashen — Animations
-- ══════════════════════════════════════════

hl.config({
    animations = {
        enabled = true,
    },
})

-- Curves
hl.curve("ghost",       { type = "bezier", points = { {0.25, 0.1}, {0.25, 1.0} } })
hl.curve("ghostOut",    { type = "bezier", points = { {0.4, 0.0},  {0.2, 1.0}  } })
hl.curve("ghostSmooth", { type = "bezier", points = { {0.23, 1},   {0.32, 1}   } })
hl.curve("sweep",       { type = "bezier", points = { {0.0, 0.0},  {0.0, 1.0}  } })

-- Windows — sweep from corner
hl.animation({ leaf = "windows",    enabled = true, speed = 4.0,  bezier = "sweep",       style = "popin 60%" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 3.5,  bezier = "sweep",       style = "popin 60%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.0,  bezier = "ghostOut",    style = "popin 60%" })

-- Fade
hl.animation({ leaf = "fade",       enabled = true, speed = 4,    bezier = "ghost"    })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 3,    bezier = "ghostOut"  })

-- Normal workspaces — horizontal
hl.animation({ leaf = "workspaces",        enabled = true, speed = 4, bezier = "ghostSmooth", style = "slide" })

-- Special workspaces — vertical
hl.animation({ leaf = "specialWorkspace",  enabled = true, speed = 4, bezier = "ghostSmooth", style = "slidevert" })

-- Border
hl.animation({ leaf = "border",     enabled = true, speed = 6,    bezier = "ghost"    })
