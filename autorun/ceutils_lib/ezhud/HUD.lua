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

    local canvas = hud.canvas

    function hud.begin()
        hud.overlay.begin()

        local cam = hud.camera
        if cam.posAddress then Vector.readVec3(getAddress(cam.posAddress), cam.pos) end
        if cam.forwardAddress then Vector.readVec3(getAddress(cam.forwardAddress), cam.forward) end
        if cam.upAddress then Vector.readVec3(getAddress(cam.upAddress), cam.up) end
        if cam.verticalFovAddress then cam.verticalFov = readFloat(cam.verticalFovAddress) end

        if hud.overlay.targetWindowVisible then
            local form = hud.overlay.form
            hud.project3DFunction = Vector.project3DFunction(
                cam.pos, cam.forward, cam.up,
                cam.verticalFov,
                form.Width, form.Height
            )
        end
    end

    function hud.present()
        hud.overlay.present()
    end

    local line_aProj = vec(0, 0, 0)
    local line_bProj = vec(0, 0, 0)
    local line_clippedA = vec(0, 0, 0)
    local line_clippedB = vec(0, 0, 0)
    local line_planePoint = vec(0, 0, 0)
    function hud.line(a, b, width, color)
        if not hud.project3DFunction then return end

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

        line_aProj = hud.project3DFunction(line_clippedA, line_aProj)
        line_bProj = hud.project3DFunction(line_clippedB, line_bProj)

        canvas.Line(
            line_aProj.x, line_aProj.y,
            line_bProj.x, line_bProj.y
        )
    end

    local text_posProj = vec(0, 0, 0)
    function hud.text(pos, text, size, color, alignX, alignY, offsetX, offsetY)
        offsetX = offsetX or 0
        offsetY = offsetY or 0
        alignX = alignX or 0
        alignY = alignY or 0

        canvas.Font.Size = size
        canvas.Font.Color = color

        text_posProj = hud.project3DFunction(pos, text_posProj)

        if text_posProj.z < 0 then
            return 0, 0
        end

        return overlay.text(
            text_posProj.x + offsetX,
            text_posProj.y + offsetY,
            text,
            size, color, alignX, alignY
        )
    end

    function hud.destroy()
        hud.overlay.destroy()
    end

    return hud
end

return HUD
