-- Slow motion: cinematic, drawn-out ease. Ported from dusklinux/dusky.
hl.curve("slowmo", { type = "bezier", points = { { 0.85, 0 }, { 0.15, 1 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 15, bezier = "slowmo", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 15, bezier = "slowmo", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 20, bezier = "slowmo" })
hl.animation({ leaf = "fade", enabled = true, speed = 20, bezier = "slowmo" })
hl.animation({ leaf = "layers", enabled = true, speed = 12, bezier = "slowmo", style = "slide" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 20, bezier = "slowmo", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 20, bezier = "slowmo", style = "slidevert" })
