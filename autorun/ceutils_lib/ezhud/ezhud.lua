local common = require("autorun.ceutils_lib.common")
local json = require("autorun.ceutils_lib.json")

local Vector = common.reloadPackage("autorun.ceutils_lib.Vector")

ezhud = {
    Overlay = common.reloadPackage("autorun.ceutils_lib.ezhud.Overlay"),
    HUD = common.reloadPackage("autorun.ceutils_lib.ezhud.HUD"),
}

local hud = ezhud.HUD.create()

hud.begin()
hud.line(
    Vector.vector(1, -10, 0),
    Vector.vector(1, 10, 0),
    2, 0x00FF00
)
-- hud.text(
--     Vector.vector(1, 0, 0),
--     "Fart", 8, 0x00FF00
-- )
local c = hud.canvas
c.Font.Size = 32
c.textOut(1, 1, "Foo")

sleep(3000)
hud.destroy()
