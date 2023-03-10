local common = require("autorun.ceutils_lib.common")
local json = require("autorun.ceutils_lib.json")
local Vector = common.reloadPackage("autorun.ceutils_lib.Vector")

local toHex = common.toHex

local module = {}

local function getProperty(object, property)
    local value = object[property]
    local propType = type(value)
    if propType == "function" then
        return value(object)
    end
    return value
end

local defaultGetPos_posVec
local function defaultGetPos(object)
    if object.address and object.posOffset then
        return Vector.readVec3(object.address + object.posOffset, defaultGetPos_posVec)
    end
    if object.x then
        return Vector.vector3(object.x, object.y, object.z, defaultGetPos_posVec)
    end
end

function module.create()
    local tracker = {}

    local objects = {}
    tracker.objects = objects

    function tracker.addObject(key, duration)
        local object = objects[key]
        if not object then
            object = { key = key, pos = defaultGetPos }
            objects[key] = object
        end
        object.endTick = getTickCount() + duration
        return object
    end

    function tracker.foreach(fn)
        local tick = getTickCount()
        for key, object in pairs(objects) do
            if object.endTick > tick then
                fn(object)
            else
                objects[key] = nil
            end
        end
    end

    local selectedObject
    local selectedObjectDist
    local maxSelectDist = 100
    local renderDistance = 20
    --
    local render_posProj = Vector.vector3(0, 0, 0)
    function tracker.render(hud)
        -- First sort by depth and cull objects outside viewport or render distance.
        -- Also select the object nearest the center of the screen for highlighting.
        local cam = hud.camera
        local entries = {}
        selectedObjectDist = 1e+9
        selectedObject = nil
        tracker.foreach(function(object)
            local pos = getProperty(object, "pos")
            local depth = Vector.heightAbovePlane(pos, cam.pos, cam.forward)

            if depth < 0 then return end
            if Vector.distance3(pos, cam.pos) > renderDistance then return end

            hud.project3DFunction(pos, render_posProj)
            local x = render_posProj.x
            local y = render_posProj.y

            local screenWidth = hud.form.Width
            local screenHeight = hud.form.Height
            if x < 0 or x > screenWidth or y < 0 or y > screenHeight then
                return
            end

            local dx = x - screenWidth / 2
            local dy = y - screenHeight / 2
            local centerDistSq = math.sqrt(dx * dx + dy * dy)

            if centerDistSq < selectedObjectDist and centerDistSq < maxSelectDist then
                selectedObject = object
                selectedObjectDist = centerDistSq
            end

            local entry = { object = object, depth = depth, x = x, y = y }
            table.insert(entries, entry)
        end)
        table.sort(entries, function(a, b) return a.depth > b.depth end)

        -- Then render the sorted and culled object list.
        for i, entry in ipairs(entries) do
            local object = entry.object
            local color = getProperty(object, "color") or 0xFFFFFF
            local address = getProperty(object, "address")
            local fontSize = 6

            local selected = object == selectedObject
            if selected then
                color = 0x00FFFF
                fontSize = 16
            end

            local hex = toHex(object.address)
            hud.overlay.text(entry.x, entry.y, hex, fontSize, color, 0, 0)
        end
    end

    local function hasSelectedAddress() return selectedObject and selectedObject.address end

    local printHotkey = createHotkey(function()
        if not hasSelectedAddress() then return end
        local hex = toHex(selectedObject.address)
        writeToClipboard(hex)
        print(hex)
    end, string.byte("P"))

    local structForm
    local dissectHotkey = createHotkey(function()
        if not hasSelectedAddress() then return end
        local address = selectedObject.address
        if not structForm then
            structForm = createStructureForm(toHex(address))
            structForm.OnClose = function()
                structForm.OnClose = nil
                structForm.close()
                structForm = nil
            end
        else
            common.addStructAddress(structForm, address)
        end
    end, string.byte("O"))

    function tracker.destroy()
        printHotkey.destroy()
        dissectHotkey.destroy()
    end

    return tracker
end

return module
