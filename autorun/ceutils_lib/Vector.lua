local module = {}

function module.vector(x, y, z, w, outVec)
    z = z or 0
    w = w or 0
    if not outVec then
        -- print("Vector allocated")
        return { x = x, y = y, z = z, w = w }
    end
    outVec.x = x
    outVec.y = y
    outVec.z = z
    outVec.w = w
    return outVec
end

function module.vector3(x, y, z, outVec)
    return module.vector(x, y, z, 0, outVec)
end

function module.copy3(from, to)
    return module.vector3(from.x, from.y, from.z, to)
end

----------------------
-- Basic operations --
----------------------

function module.dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w end

function module.dot3(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end

function module.dot3immediate(ax, ay, az, bx, by, bz) return ax * bx + ay * by + az * bz end

function module.add(a, b, outVec) return module.vector(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w, outVec) end

function module.add3Scaled(a, b, s, outVec) return module.vector3(a.x + b.x * s, a.y + b.y * s, a.z + b.z * s, outVec) end

function module.sub(a, b, outVec) return module.vector(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w, outVec) end

function module.sub3(a, b, outVec) return module.vector(a.x - b.x, a.y - b.y, a.z - b.z, 0, outVec) end

function module.scale(a, b, outVec) return module.vector(a.x * b, a.y * b, a.z * b, a.w * b, outVec) end

function module.div(a, b, outVec) return module.vector(a.x / b, a.y / b, a.z / b, a.w / b, outVec) end

function module.length(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z + a.w * a.w) end

function module.length3(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end

function module.lengthSquared3(a, b) return a.x * a.x + a.y * a.y + a.z * a.z end

function module.distance3(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y
    local dz = b.z - a.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function module.unit3(a) return module.div(a, module.length3(a)) end

function module.cross(a, b, outVec)
    return module.vector(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x,
        0, outVec
    )
end

function module.normalize3(a)
    local invLen = 1 / module.length3(a)
    a.x = a.x * invLen
    a.y = a.y * invLen
    a.z = a.z * invLen
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
    local size = 3 * 4
    local mem = allocateMemory(size)
    copyMemory(address, size, mem)
    local result = module.vector3(
        readFloat(mem + 0x00),
        readFloat(mem + 0x04),
        readFloat(mem + 0x08),
        outVec
    )
    deAlloc(mem)
    return result
end

--------------------------------
-- Clipping and plane testing --
--------------------------------

function module.heightAbovePlane(point, planePoint, planeNormal)
    return module.dot3immediate(
        point.x - planePoint.x,
        point.y - planePoint.y,
        point.z - planePoint.z,
        planeNormal.x, planeNormal.y, planeNormal.z
    )
end

local clipLine_ab = module.vector(0, 0, 0)
local clipLine_abt = module.vector(0, 0, 0)
function module.clipLine(a, b, planePoint, planeNormal)
    local ah = module.heightAbovePlane(a, planePoint, planeNormal)
    local bh = module.heightAbovePlane(b, planePoint, planeNormal)

    if ah < 0 and bh < 0 then return false end
    if ah > 0 and bh > 0 then return true end

    clipLine_ab = module.sub3(b, a, clipLine_ab)
    local an = module.dot3(a, planeNormal)
    local pn = module.dot3(planePoint, planeNormal)
    local abn = module.dot3(clipLine_ab, planeNormal)

    local t = (pn - an) / abn

    local pointToClip
    if ah < 0 then pointToClip = a else pointToClip = b end
    module.add(a, module.scale(clipLine_ab, t, clipLine_abt), pointToClip)

    return true
end

----------------
-- Projection --
----------------

local camRight = module.vector(0, 0, 0)
local camUp = module.vector(0, 0, 0)
local toPoint = module.vector(0, 0, 0)
function module.project3DFunction(camPos, camForward, up, verticalFov, screenWidth, screenHeight)
    camRight = module.cross(camForward, up, camRight)
    camUp = module.cross(camRight, camForward, camUp)

    module.normalize3(camRight)
    module.normalize3(camUp)

    local frustumVerticalSlope = math.tan(verticalFov / 2)

    local halfScreenWidth = screenWidth / 2
    local halfScreenHeight = screenHeight / 2

    return function(point, outVec)
        toPoint = module.sub3(point, camPos, toPoint)

        -- Get coordinates in view space (with left handed coordinates)
        local x = module.dot3(toPoint, camRight)
        local y = module.dot3(toPoint, camUp)
        local z = module.dot3(toPoint, camForward)

        local frustumHeightAtDepth = z * frustumVerticalSlope
        local scale = screenHeight / frustumHeightAtDepth

        return module.vector(
            halfScreenWidth + x * scale,
            halfScreenHeight - y * scale,
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
