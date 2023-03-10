local common = require("autorun.ceutils_lib.common")
local json = require("autorun.ceutils_lib.json")

local Overlay = {}

-------------
-- Helpers --
-------------

local function clientToScreen(hwnd, point)
    local m = createMemoryStream()
    m.size = 2 * 4
    m.writeDword(point.x)
    m.writeDword(point.y)
    local result
    if executeCodeLocalEx("ClientToScreen", hwnd, m.Memory) then
        m.Position = 0
        result = {
            x = m.readDword(),
            y = m.readDword()
        }
    end
    m.destroy()
    return result
end

local function getClientRect(hwnd)
    local m = createMemoryStream()
    m.size = 4 * 4
    local result
    if executeCodeLocalEx("GetClientRect", hwnd, m.Memory) then
        m.Position = 0
        result = {
            left = m.readDword(),
            top = m.readDword(),
            right = m.readDword(),
            bottom = m.readDword()
        }
    end
    m.destroy()
    return result
end

function Overlay.getWindowRect(hwnd, outRect)
    local clientRect = getClientRect(hwnd)
    if clientRect then
        local upperLeft = clientToScreen(hwnd, { x = clientRect.left, y = clientRect.top })
        local lowerRight = clientToScreen(hwnd, { x = clientRect.right, y = clientRect.bottom })
        if upperLeft and lowerRight then
            outRect = outRect or {}
            outRect.left = upperLeft.x
            outRect.top = upperLeft.y
            outRect.right = lowerRight.x
            outRect.bottom = lowerRight.y
            return outRect
        end
    end
    -- print("Couldn't get window rect.")
    return outRect
end

function getWindowArea(hwnd)
    local rect = getClientRect(hwnd)
    if not rect then return 0 end
    return (rect.right - rect.left) * (rect.bottom - rect.top)
end

function Overlay.getMainWindow()
    local pid = getOpenedProcessID()
    local windowList = getWindowlist()
    local captions = windowList[pid]
    if not captions then
        return nil
    end

    local bestHwnd = nil
    local bestArea = 0
    for i, caption in pairs(captions) do
        if caption ~= "Default IME" then
            local hwnd = findWindow(nil, caption)
            if hwnd and getWindowProcessID(hwnd) == pid then
                local area = getWindowArea(hwnd)
                if area > bestArea then
                    bestHwnd = hwnd
                    bestArea = area
                end
            end
        end
    end

    return bestHwnd
end

-- A transparent, borderless window.
local function getOverlayForm()
    local f = createForm(false)
    f.BorderStyle = "bsNone"
    f.Color = 0xFF
    f.setLayeredAttributes(0xFF, 255, 3)
    f.FormStyle = "fsSystemStayOnTop"
    f.visible = true
    return f
end

----------
-- Main --
----------

function Overlay.create(hwndOrCaptionOrClassnameOrNil)
    local overlay = {}

    ---------------------------------------------------

    local hwnd
    local argType = type(hwndOrCaptionOrClassnameOrNil)
    if argType == "nil" then
        hwnd = Overlay.getMainWindow()
    elseif argType == "number" then
        hwnd = hwndOrCaptionOrClassnameOrNil
    elseif argType == "string" then
        local captionOrClassname = hwndOrCaptionOrClassnameOrNil
        hwnd = findWindow(nil, captionOrClassname)
        if not hwnd then
            hwnd = findWindow(captionOrClassname, nil)
        end
    else
        print("Invalid argument for Overlay window.")
    end

    ---------------------------------------------------

    local form = getOverlayForm()
    -- local backBuffer = createBitmap(100, 100)
    -- local canvas = backBuffer.Canvas
    local canvas = form.Canvas

    overlay.hwnd = hwnd
    overlay.form = form
    -- overlay.backBuffer = backBuffer
    overlay.canvas = canvas
    overlay.pen = canvas.Pen
    overlay.targetWindowVisible = false

    -- local font = backBuffer.Canvas.Font
    local font = canvas.Font
    font.Name = "Consolas"
    font.Size = 16
    font.Color = 0xFFFFFF
    font.Style = "fsBold"
    font.Quality = "fqNonAntialiased"

    ---------------------------------------------------

    function overlay.setOpacity(byteOpacity)
        overlay.form.setLayeredAttributes(0xFF, byteOpacity, 3)
    end

    local screenRect
    function overlay.updatePosition()
        screenRect = Overlay.getWindowRect(hwnd, screenRect)
        local rect = screenRect
        overlay.targetWindowVisible = rect ~= nil
        if rect then
            form.Left = rect.left
            form.Top = rect.top
            form.Width = rect.right - rect.left
            form.Height = rect.bottom - rect.top

            -- backBuffer.Width = form.Width
            -- backBuffer.Height = form.Height
        end
    end

    function overlay.begin()
        overlay.updatePosition()
        overlay.canvas.Brush.Color = 0x0000FF
        overlay.canvas.fillRect(0, 0, form.Width, form.Height)
    end

    function overlay.present()
        -- overlay.form.Canvas.copyRect(
        --     0, 0, form.Width, form.Height,
        --     overlay.backBuffer.Canvas,
        --     0, 0, form.Width, form.Height
        -- )
    end

    function overlay.destroy()
        form.destroy()
        -- backBuffer.destroy()
    end

    local timer
    function overlay.renderLoop(fps, renderFunc)
        form.OnPaint = renderFunc
        timer = createTimer(form, false)
        timer.Interval = 1000 / fps
        timer.OnTimer = function() form.repaint() end
        timer.Enabled = true
    end

    function overlay.text(x, y, text, size, color, alignX, alignY)
        alignX = alignX or 0
        alignY = alignY or 0
        font.Size = size
        font.Color = color

        local w = canvas.getTextWidth(text)
        local h = canvas.getTextHeight(text)

        local _x = math.floor(x - w / 2 * (1 - alignX))
        local _y = math.floor(y - h / 2 * (1 - alignY))
        canvas.textOut(_x, _y, text)

        return _x, _y, w, h
    end

    ---------------------------------------------------

    overlay.updatePosition()
    overlay.setOpacity(64)

    return overlay
end

return Overlay
