local common = require("autorun.ceutils_lib.common")
local Vector = common.reloadPackage("autorun.ceutils_lib.Vector")
local Overlay = common.reloadPackage("autorun.ceutils_lib.ezhud.Overlay")

local HUD = {}

function HUD.create(overlayOrOverlayArgs)
    local overlay
    local argType = type(overlayOrOverlayArgs)
    if argType == "number" or argType == "nil" or argType == "string" then
        overlay = Overlay.create(overlayOrOverlayArgs)
    else
        overlay = overlayOrOverlayArgs
    end

    local hud = {}

    hud.overlay = overlay
    hud.camera = {
        pos = Vector.vector(0, 0, 0),
        forward = Vector.vector(1, 0, 0),
        up = Vector.vector(0, 0, 1),
        verticalFov = math.pi / 2
    }


    local project3DFunction
    function hud.begin()
        hud.overlay.begin()

        local cam = hud.camera
        rect = hud.overlay.screenRect
        if rect then
            local screenWidth = rect.right - rect.left
            local screenHeight = rect.bottom - rect.top
            project3DFunction = Vector.project3DFunction(
                cam.pos, cam.forward, cam.up,
                cam.verticalFov,
                screenWidth, screenHeight
            )
        end
    end

    local line_ap, line_bp
    function hud.line(a, b)
        if not project3DFunction then return end

        line_ap = project3DFunction(a, line_ap)
        line_bp = project3DFunction(b, line_bp)

        overlay.canvas.Line(
            line_ap.x, line_ap.y,
            line_bp.x, line_bp.y
        )
    end

    function hud.destroy()
        hud.overlay.destroy()
    end

    return hud
end

return HUD
