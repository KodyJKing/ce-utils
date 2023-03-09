local common = require("autorun.ceutils_lib.common")
local json = require("autorun.ceutils_lib.json")

local Vector = common.reloadPackage("autorun.ceutils_lib.Vector")

local module = {}

local function getProperty(object, property)
    local value = object[property]
    local propType = type(value)
    if value == "function" then
        return value(object)
    end
    return value
end

function module.create(structureName)
    local tracker = {}

    local objects = {}
    tracker.objects = objects
    tracker.structureName = structureName

    function tracker.addObject(key, duration, address, caption, color, position)
        local object = objects[key]
        if not object then
            object = { key = key, address = address, caption = caption, color = color, position = position }
        else
            object.address = address
            object.caption = caption
            object.color = color
            object.position = position
        end
        object.endTick = getTickCount() + duration
        objects[key] = object
    end

    -- function tracker.clearExpired()
    --     local currentTick = getTickCount()
    --     for key, object in pairs(objects) do
    --         if object.endTick < currentTick then
    --             objects[key] = nil
    --         end
    --     end
    -- end

    function tracker.iter()
        local currentTick = getTickCount()
        local nextPair = pairs(objects)
        return function()
            while true do
                local key, object = nextPair(objects)
                if not key then return nil end
                if object.endTick > currentTick then
                    return object
                else
                    objects[key] = nil
                end
            end
        end
    end

    function render(hud)
        for object in tracker.iter() do
            local pos = getProperty(object, "position")
            local color = getProperty(object, "color") or 0x00FF00
            local caption = getProperty(object, "caption") or "undefined"
            hud.text(pos, caption, 8, color)
        end
    end

    return tracker
end

return module
