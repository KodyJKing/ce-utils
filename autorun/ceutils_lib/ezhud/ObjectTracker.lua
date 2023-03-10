local common = require("autorun.ceutils_lib.common")
local json = require("autorun.ceutils_lib.json")

local Vector = common.reloadPackage("autorun.ceutils_lib.Vector")

local module = {}

local function getProperty(object, property)
    local value = object[property]
    local propType = type(value)
    if propType == "function" then
        return value(object)
    end
    return value
end

function module.create()
    local tracker = {}

    local objects = {}
    tracker.objects = objects

    function tracker.addObject(key, duration)
        local object = objects[key]
        if not object then
            object = { key = key }
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

    local render_posProj = Vector.vector3(0, 0, 0)
    function tracker.render(hud)
        local entries = {}

        local selectedObject
        local selectedObjectDist = 1e+9
        local maxSelectDist = 50

        local cam = hud.camera
        tracker.foreach(function(object)
            local pos = getProperty(object, "pos")
            local depth = Vector.heightAbovePlane(pos, cam.pos, cam.forward)

            if depth < 0 then return end

            hud.project3DFunction(pos, render_posProj)
            local x = render_posProj.x
            local y = render_posProj.y
            local dx = x - hud.form.Width / 2
            local dy = y - hud.form.Height / 2
            local centerDistSq = math.sqrt(dx * dx + dy * dy)

            if centerDistSq < selectedObjectDist and centerDistSq < maxSelectDist then
                selectedObject = object
                selectedObjectDist = centerDistSq
            end

            local entry = { object = object, depth = depth, x = x, y = y }
            table.insert(entries, entry)
        end)

        table.sort(entries, function(a, b) return a.depth > b.depth end)

        for i, entry in ipairs(entries) do
            local object = entry.object
            local color = getProperty(object, "color") or 0x00FF00
            local address = getProperty(object, "address")

            local selected = object == selectedObject
            if selected then
                color = 0x00FFFF
            end

            hud.overlay.text(entry.x, entry.y, tostring(address), 16, color, 0, 0)
        end
    end

    return tracker
end

return module
