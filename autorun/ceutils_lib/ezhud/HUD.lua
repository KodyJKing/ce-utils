local common = require("autorun.ceutils_lib.common")
local Vector = common.reloadPackage("autorun.ceutils_lib.Vector")
local Overlay = common.reloadPackage("autorun.ceutils_lib.ezhud.Overlay")

local vec = Vector.vector

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
    hud.form = overlay.form
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

        if hud.overlay.targetWindowVisible then
            local cam = hud.camera
            local form = hud.overlay.form
            project3DFunction = Vector.project3DFunction(
                cam.pos, cam.forward, cam.up,
                cam.verticalFov,
                form.Width, form.Height
            )
        end
    end

    local line_aProj = vec(0, 0, 0)
    local line_bProj = vec(0, 0, 0)
    local line_clippedA = vec(0, 0, 0)
    local line_clippedB = vec(0, 0, 0)
    local line_planePoint = vec(0, 0, 0)
    function hud.line(a, b, width, color)
        if not project3DFunction then return end

        overlay.pen.width = width
        overlay.pen.color = color

        line_clippedA = Vector.copy3(a, line_clippedA)
        line_clippedB = Vector.copy3(b, line_clippedB)

        local cam = hud.camera
        local visible = Vector.clipLine(
            line_clippedA, line_clippedB,
            Vector.add3Scaled(cam.pos, cam.forward, 0.01, line_planePoint),
            cam.forward
        )

        if not visible then return end

        line_aProj = project3DFunction(line_clippedA, line_aProj)
        line_bProj = project3DFunction(line_clippedB, line_bProj)

        c.Line(
            line_aProj.x, line_aProj.y,
            line_bProj.x, line_bProj.y
        )
    end

    local text_posProj = vec(0, 0, 0)
    function hud.text(pos, text, size, color, alignX, alignY, offsetX, offsetY)
        alignX = alignX or 0
        alignY = alignY or 0
        offsetX = offsetX or 0
        offsetY = offsetY or 0
        c.Font.Size = size
        c.Font.Color = color

        text_posProj = project3DFunction(pos, text_posProj)

        if text_posProj.z < 0 then
            return 0, 0
        end

        local w = c.getTextWidth(text) / 2
        local h = c.getTextHeight(text) / 2

        local x = math.floor(text_posProj.x - w / 2 * (1 - alignX) + offsetX)
        local y = math.floor(text_posProj.y - h * (1 - alignY) + offsetY)
        c.textOut(x, y, text)

        return w, h
    end

    function hud.destroy()
        hud.overlay.destroy()
    end

    return hud
end

return HUD
