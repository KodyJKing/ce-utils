local module = {}

function module.vector(x, y, z, w, outVec)
    z = z or 0
    w = w or 0
    if not outVec then
        return { x = x, y = y, z = z, w = w }
    end
    outVec.x = x
    outVec.y = y
    outVec.z = z
    outVec.w = w
    return outVec
end

----------------------
-- Basic operations --
----------------------

function module.dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w end

function module.dot3(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end

function module.dot3immediate(ax, ay, az, bx, by, bz) return ax * bx + ay * by + az * bz end

function module.add(a, b, outVec) return module.vector(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w, outVec) end

function module.sub(a, b, outVec) return module.vector(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w, outVec) end

function module.sub3(a, b, outVec) return module.vector(a.x - b.x, a.y - b.y, a.z - b.z, 0, outVec) end

function module.scale(a, b, outVec) return module.vector(a.x * b, a.y * b, a.z * b, a.w * b, outVec) end

function module.div(a, b, outVec) return module.vector(a.x / b, a.y / b, a.z / b, a.w / b, outVec) end

function module.length(a, b) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z + a.w * a.w) end

function module.length3(a, b) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end

function module.lengthSquared3(a, b) return a.x * a.x + a.y * a.y + a.z * a.z end

function module.unit3(a) return module.div(a, module.length3(a)) end

function module.cross(a, b, outVec)
    return module.vector(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x,
        0, outVec
    )
end

-------------
-- Strings --
-------------

function module.toString(a) return "(" .. a.x .. ", " .. a.y .. ", " .. a.z .. ", " .. a.w .. ")" end

function module.toString3(a) return "(" .. a.x .. ", " .. a.y .. ", " .. a.z .. ")" end

function module.print(a) print(module.toString(a)) end

function module.print3(a) print(module.toString3(a)) end

------------
-- Memory --
------------

function module.readVec3(address, outVec)
    return module.vector(
        readFloat(address + 0x00),
        readFloat(address + 0x04),
        readFloat(address + 0x08),
        0, outVec
    )
end

--------------------------------
-- Clipping and plane testing --
--------------------------------

function module.heightAbovePlane(point, planePoint, planeNormal)
    return module.dot3immediate(
        point.x - planePoint.x, point.y - planePoint.y, point.z - planePoint.z,
        planeNormal.x, planeNormal.y, planeNormal.z
    )
end

local clipLine_ab
function module.clipLine(a, b, planePoint, planeNormal)
    local ah = module.heightAbovePlane(a, planePoint, planeNormal)
    local bh = module.heightAbovePlane(b, planePoint, planeNormal)

    if ah < 0 and bh < 0 then return false end

    clipLine_ab = module.sub(b, a, clipLine_ab)
    local lenSq = module.lengthSquared3(clipLine_ab)
    local dot = module.dot(clipLine_ab, planeNormal)

    if ah < 0 then
        module.scale(clipLine_ab, dot / lenSq, a)
    else
        module.scale(clipLine_ab, dot / lenSq, b)
    end
end

----------------
-- Projection --
----------------

local camRight
local camUp
local toPoint
function module.project3DFunction(camPos, camForward, up, verticalFov, screenWidth, screenHeight)
    camRight = module.cross(camForward, up, camRight)
    camUp = module.cross(camRight, camForward, camUp)

    local frustumVerticalSlope = math.tan(verticalFov / 2)

    return function(point, outVec)
        toPoint = module.sub3(point, camPos, toPoint)

        -- Get coordinates in view space (with left handed coordinates)
        local x = module.dot3(toPoint, camRight)
        local y = module.dot3(toPoint, camUp)
        local z = module.dot3(toPoint, camForward)

        local frustumHeightAtDepth = z * frustumVerticalSlope
        local scale = screenHeight / frustumHeightAtDepth

        return module.vector(
            x * scale + screenWidth / 2,
            y * scale + screenHeight / 2,
            z, 0, outVec
        )
    end
end

function module.project3D(point, camPos, camForward, up, verticalFov, screenWidth, screenHeight, outVec)
    return module.project3DFunction(camPos, camForward, up, verticalFov, screenWidth, screenHeight)(point, outVec)
end

----------------
----------------

return module
