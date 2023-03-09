local common = require("autorun.ceutils_lib.common")
local json = require("autorun.ceutils_lib.json")

local Overlay = {}

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

function Overlay.create(hwndOrCaptionOrClassnameOrNil)
    local overlay = {}

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

    local f = getOverlayForm()

    overlay.hwnd = hwnd
    overlay.form = f
    overlay.canvas = f.Canvas
    overlay.pen = f.Canvas.Pen
    overlay.screenRect = Overlay.getWindowRect(hwnd)

    function overlay.updatePosition()
        local rect = overlay.screenRect
        if rect then
            f.Left = rect.left
            f.Top = rect.top
            f.Width = rect.right - rect.left
            f.Height = rect.bottom - rect.top
        end
    end

    function overlay.begin()
        Overlay.getWindowRect(hwnd, overlay.screenRect)
        overlay.updatePosition()
        overlay.canvas.Clear()
    end

    overlay.destroy = function()
        f.destroy()
    end

    overlay.updatePosition()

    return overlay
end

return Overlay
