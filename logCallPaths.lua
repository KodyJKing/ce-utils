local json = require("ceutils_lib.json")

package.loaded["ceutils_lib.common"] = nil
local common = require("ceutils_lib.common")

if common.dev then
    package.loaded["ceutils_lib.createRegionMap"] = nil
    package.loaded["ceutils_lib.functional"] = nil
end

local createRegionMap = require("ceutils_lib.createRegionMap")
local functional = require("ceutils_lib.functional")

--------------------------------------------------------------

local toHex = common.toHex

function pad(x)
    return common.padLeft(toHex(x), 8, "0")
end

--------------------------------------------------------------

function getPrecedingCall(address)
    local maxOffset = 64

    for offset = 1, maxOffset do
        local address2 = address - offset

        local dString = disassemble(address2)
        local extra, opcode, bytes, _address = splitDisassembledString(dString)

        if string.find(opcode, "^call") then

            bytes, _ = string.gsub(bytes, " ", "")
            local numBytes = math.ceil(#bytes / 2)

            if numBytes == offset then
                -- Instruction is a call and doesn't leave any gaps.
                return address2
            end

        end

    end

    return nil

end

local _regionMapGoodUntil = 0
local _cachedRegionMap = nil
local _REGION_MAP_MAX_AGE = 1000 * 60 * 5
--
function getRegionMap()
    if true or _cachedRegionMap == nil or GetTickCount() > _regionMapGoodUntil then
        _cachedRegionMap = createRegionMap()
        _regionMapGoodUntil = GetTickCount() + _REGION_MAP_MAX_AGE
    end
    return _cachedRegionMap
end

--------------------------------------------------------------

function createCallChainLogForm(address)

    local form = createFormFromFile(common.formPath .. "LogCallChains.FRM")

    if address then
        form.findComponentByName("Address").Text = address
    end

end

function getCallChain(regionMap, stackLimit)

    local ptrSize = common.getPointerSize()
    local base = common.getStackPointer()

    local chain = {}

    for offset = 0, stackLimit, ptrSize do
        local address = base + offset
        local value = readPointer(address)
        local isValidReturn = value and
            regionMap.isExecutable(value)
        if isValidReturn then
            local callAddress = getPrecedingCall(value)
            if callAddress then
                table.insert(chain, callAddress)
            end
        end
    end

    return chain

end

function printCallPaths(address, options)
    options = options or {}
    local callLimit = options.callLimit or 10
    local stackLimit = options.stackLimit or 4096

    local regionMap = getRegionMap()
    local calls = 0

    local callChainSet = {}

    debug_setBreakpoint(address, function()

        calls = calls + 1
        local removedBreakpoint = false
        if calls >= callLimit then
            removedBreakpoint = true
            debug_removeBreakpoint(address)
        end

        local path = getCallChain(regionMap, stackLimit)

        local callChain = table.concat(functional.map(path, pad), " <- ")
        if not callChainSet[callChain] then
            callChainSet[callChain] = true
            print(callChain)
            print("")
        end

        if removedBreakpoint then
            print("Removed breakpoint.")
        end

    end)

end

-- printCallPaths(0x004EF49F)
