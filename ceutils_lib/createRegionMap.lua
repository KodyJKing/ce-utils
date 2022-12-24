-----------
-- Debug --
-----------

local DEBUG = false

function print_debug(...)
    if DEBUG then
        print(...)
    end
end

local startTick = 0
local function timerStart()
    startTick = GetTickCount()
end

local function timerEnd(timername)
    local endTick = GetTickCount()
    local dt = endTick - startTick
    print_debug(timername, "finshed in", dt / 1000, "seconds.")
end

---------------------------------------------------------------

local PAGE_EXECUTE           = 0x10
local PAGE_EXECUTE_READ      = 0x20
local PAGE_EXECUTE_READWRITE = 0x40
local PAGE_EXECUTE_WRITECOPY = 0x80
local PAGE_NOACCESS          = 0x01
local PAGE_READONLY          = 0x02
local PAGE_READWRITE         = 0x04
local PAGE_WRITECOPY         = 0x08

local MEM_COMMIT  = 0x1000
local MEM_FREE    = 0x10000
local MEM_RESERVE = 0x2000

local function isExecutable(protect)
    return protect == PAGE_EXECUTE or
        protect == PAGE_EXECUTE_READ or
        protect == PAGE_EXECUTE_READWRITE or
        protect == PAGE_EXECUTE_WRITECOPY
end

---------------------------------------------------------------

local function createRegionMap(executableOnly, blocksize)
    -- MemoryRegion: {BaseAddress, AllocationBase, AllocationProtect, RegionSize, State, Protect, Type}

    function filter(region)
        return region.State == MEM_COMMIT and
            ((not executableOnly) or isExecutable(region.Protect))
    end

    timerStart()
    local regions = enumMemoryRegions()
    timerEnd("Enumerate-memory-regions")

    local map = { blockToRegions = {} }

    function blockIndex(address)
        return math.floor(address / blocksize)
    end

    function calcBlockSize()
        local netSize = 0
        local count = 0
        for i, region in ipairs(regions) do
            if filter(region) then
                netSize = netSize + region.RegionSize
                count = count + 1
            end
        end
        return math.floor(10 * netSize / count)
    end

    timerStart()
    blocksize = blocksize or calcBlockSize()
    print_debug("Total regions =", #regions)
    print_debug("Block size = ", blocksize)
    timerEnd("Calc-block-size")
    print_debug("Using blocksize", blocksize)

    timerStart()
    local totalBlocks = 0
    local maxRegionsInABlock = 0
    for i, region in ipairs(regions) do
        if filter(region) then
            local startIndex = blockIndex(region.BaseAddress)
            local endIndex = blockIndex(region.BaseAddress + region.RegionSize)

            for blockIndex = startIndex, endIndex do
                local regions = map.blockToRegions[blockIndex] or {}
                table.insert(regions, region)
                map.blockToRegions[blockIndex] = regions

                maxRegionsInABlock = math.max(maxRegionsInABlock, #regions)
                totalBlocks = totalBlocks + 1
            end
        end
    end
    timerEnd("Map-blocks-to-regions")
    print_debug("Total blocks =", totalBlocks)
    print_debug("Max regions in a block =", maxRegionsInABlock)

    function map.getRegion(address)
        local regions = map.blockToRegions[blockIndex(address)]
        if regions == nil then
            return nil
        end
        for i, region in ipairs(regions) do
            if region.BaseAddress < address and region.BaseAddress + region.RegionSize > address then
                return region
            end
        end
    end

    function map.isExecutable(address)
        local region = map.getRegion(address)
        return region ~= nil and isExecutable(region.Protect)
    end

    return map

end

return createRegionMap
