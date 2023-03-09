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
    hud.canvas = overlay.canvas
    hud.pen = overlay.pen
    hud.camera = {
        pos = Vector.vector(0, 0, 0),
        forward = Vector.vector(1, 0, 0),
        up = Vector.vector(0, 0, 1),
        verticalFov = math.pi / 2
    }

    local c = hud.canvas

    local project3DFunction
    function hud.begin()
        hud.overlay.begin()

        if hud.overlay.screenRect then
            local cam = hud.camera
            local form = hud.overlay.form
            project3DFunction = Vector.project3DFunction(
                cam.pos, cam.forward, cam.up,
                cam.verticalFov,
                form.Width, form.Height
            )
        end
    end

    local line_ap, line_bp
    function hud.line(a, b, width, color)
        if not project3DFunction then return end

        if width then overlay.pen.width = width end
        if color then overlay.pen.color = color end

        line_ap = project3DFunction(a, line_ap)
        line_bp = project3DFunction(b, line_bp)

        if line_ap.z < 0 or line_bp.z < 0 then
            return
        end

        c.Line(
            line_ap.x, line_ap.y,
            line_bp.x, line_bp.y
        )
    end

    local text_posProj
    function hud.text(pos, text, size, color, alignX, alignY, offsetX, offsetY)
        if size then c.Font.Size = size end
        if color then c.Font.Color = color end
        alignX = alignX or 0
        alignY = alignY or 0
        offsetX = offsetX or 0
        offsetY = offsetY or 0

        text_posProj = project3DFunction(pos, text_posProj)

        if text_posProj.z < 0 then
            return 0, 0
        end

        local w = c.getTextWidth(text) / 2
        local h = c.getTextHeight(text) / 2

        print(text)

        local x = text_posProj.x - w / 2 * (1 - alignX) + offsetX
        local y = text_posProj.y - h / 2 * (1 - alignY) + offsetY
        print(x, y)
        c.textOut(x, y, text)

        return w, h
    end

    function hud.destroy()
        hud.overlay.destroy()
    end

    return hud
end

return HUD
