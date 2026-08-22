-- Exaggerated: maximum wobble, theatrical. Ported from dusklinux/dusky.
hl.curve("boing", { type = "bezier", points = { { 0.4, 0.8 }, { 0.2, 1.7 } } })
hl.curve("slingshot", { type = "bezier", points = { { 0.4, -0.4 }, { 0, 1.2 } } })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 8, bezier = "boing", style = "popin 10%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 8, bezier = "boing", style = "popin 80%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 8, bezier = "boing", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "boing" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "boing" })
hl.animation({ leaf = "layers", enabled = true, speed = 10, bezier = "boing", style = "slide" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 10, bezier = "boing", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 10, bezier = "boing", style = "slidevert" })
