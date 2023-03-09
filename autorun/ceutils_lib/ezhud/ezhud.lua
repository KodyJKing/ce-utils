local common = require("autorun.ceutils_lib.common")
local json = require("autorun.ceutils_lib.json")

local Vector = common.reloadPackage("autorun.ceutils_lib.Vector")

ezhud = {
    Overlay = common.reloadPackage("autorun.ceutils_lib.ezhud.Overlay"),
    HUD = common.reloadPackage("autorun.ceutils_lib.ezhud.HUD"),
}

local hud = ezhud.HUD.create()
local pen = hud.overlay.pen
local c = hud.overlay.canvas
pen.Color = 0x00FF00
pen.Width = 2

hud.begin()
hud.line(
    Vector.vector(1, -10, 0),
    Vector.vector(1, 10, 0)
)
sleep(3000)
hud.destroy()
