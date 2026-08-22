-- Air: floaty, soft, slide-fade. Ported from dusklinux/dusky (vertical_air).
hl.curve("soft", { type = "bezier", points = { { 0.3, 0.3 }, { 0.2, 1 } } })
hl.curve("softIn", { type = "bezier", points = { { 0.4, 0 }, { 1, 1 } } })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 8, bezier = "soft", style = "slidefade 15%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 8, bezier = "softIn", style = "slidefade 15%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 8, bezier = "soft", style = "slidefade 15%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "soft" })
hl.animation({ leaf = "fade", enabled = true, speed = 10, bezier = "soft" })
hl.animation({ leaf = "layers", enabled = true, speed = 6, bezier = "soft", style = "slidefade 10%" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 10, bezier = "soft", style = "slidefade 40%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 10, bezier = "soft", style = "slidefadevert 40%" })
