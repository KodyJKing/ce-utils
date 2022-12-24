package.loaded["autorun.ceutils_lib.common"] = nil
local common = require("autorun.ceutils_lib.common")

if common.dev then
    package.loaded["autorun.ceutils_lib.createRegionMap"] = nil
    package.loaded["autorun.ceutils_lib.functional"] = nil
end

local createRegionMap = require("autorun.ceutils_lib.createRegionMap")
local functional = require("autorun.ceutils_lib.functional")

--------------------------------------------------------------

local toHex = common.toHex

function pad(x)
    return common.padLeft(toHex(x), 8, "0")
end

--------------------------------------------------------------

local function getPrecedingCall(address)
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
local function getRegionMap()
    if true or _cachedRegionMap == nil or GetTickCount() > _regionMapGoodUntil then
        _cachedRegionMap = createRegionMap()
        _regionMapGoodUntil = GetTickCount() + _REGION_MAP_MAX_AGE
    end
    return _cachedRegionMap
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

local function getSubItemUnderMouse(listView, numColumns)
    local sx, sy = getMousePos()
    local x, y = listView.screenToClient(sx, sy)

    local listItem = listView.getItemAt(x, y)
    if not listItem then return end

    local columns = listView.Columns
    for i = 0, numColumns - 1 do
        x = x - columns[i].Width
        if x < 0 then
            return listItem, i
        end
    end
    return nil
end

--------------------------------------------------------------

-- createCallChainLogForm(0x004EF49F)
function createCallChainLogForm(initialAddress)

    local regionMap = getRegionMap()

    -- Form components --
    local form = createFormFromFile(common.formPath .. "LogCallChains.FRM")
    local addressInput = form.findComponentByName("Address")
    local callLimitInput = form.findComponentByName("CallLimit")
    local stackLimitInput = form.findComponentByName("StackLimit")
    local listView = form.findComponentByName("List")
    local optionsGroup = form.findComponentByName("Options")

    -- Add caller columns
    local NUM_CALLER_COLUMNS = 10
    for i = 1, NUM_CALLER_COLUMNS do
        local column = listView.Columns.add()
        column.Caption = "Caller " .. i
        column.AutoSize = true
    end
    ---------------------

    if initialAddress then
        addressInput.Text = toHex(initialAddress)
    end

    -- State --

    local attatchedAddress = nil
    local callChainRecords = {}

    function getBreakAddress() return tonumber("0x" .. addressInput.Text) end

    function getCallLimit() return tonumber(callLimitInput.Text) end

    function getStackLimit() return tonumber(stackLimitInput.Text) end

    -----------

    function attach()
        if attatchedAddress then return end
        attatchedAddress = getBreakAddress()
        optionsGroup.enabled = false

        -- print("Attaching to", toHex(attatchedAddress))

        local callLimit = getCallLimit()
        local stackLimit = getStackLimit()

        local calls = 0
        debug_setBreakpoint(
            attatchedAddress,
            function()
                addCallChain(getCallChain(regionMap, stackLimit))
                calls = calls + 1
                if calls >= callLimit then detatch() end
            end
        )
    end

    function detatch()
        -- print("Detaching")
        debug_removeBreakpoint(attatchedAddress)
        optionsGroup.enabled = true
        attatchedAddress = nil
    end

    function toggleAttach()
        if attatchedAddress then
            detatch()
        else
            attach()
        end
    end

    -----------

    function addCallChain(chain)
        local lines = pad(attatchedAddress) .. "\n" .. table.concat(functional.map(chain, pad), "\n")

        local record = callChainRecords[lines] or { count = 0 }
        record.count = record.count + 1

        if record.count == 1 then
            callChainRecords[lines] = record
            record.item = listView.Items.Add()
            record.item.SubItems.text = lines
        end
        record.item.Caption = tostring(record.count)
    end

    -----------

    form.findComponentByName("ToggleBreakpoint").OnClick = toggleAttach
    form.OnClose = function()
        detatch()
        form.Destroy()
    end

    listView.OnClick = function(...)
        local numColumns = 2 + NUM_CALLER_COLUMNS
        local item, colIndex = getSubItemUnderMouse(listView, numColumns)

        if item == nil or colIndex <= 0 then return end

        local addressString = item.SubItems[colIndex - 1]
        local address = tonumber("0x" .. addressString)

        local memForm = getMemoryViewForm()
        memForm.visible = true
        memForm.DisassemblerView.selectedAddress = address
    end

    -----------

    form.visible = true

end

local function applyExtension()
    local mv = getMemoryViewForm()

    local caption = "Find out what calls lead here"
    local mi = common.findItemWithCaption(mv.debuggerpopup, caption)
    if not mi then
        mi = createMenuItem(mv.Menu)
        mi.Caption = caption
        -- Insert at the end of section 2.
        common.insertMenuItemInSection(mv.debuggerpopup, 3, -1, mi)
    end

    mi.Shortcut = 'Ctrl+Shift+C'
    mi.ImageIndex = 33 -- Stack Debug Icon

    mi.OnClick = function()
        local a = mv.DisassemblerView.SelectedAddress
        local b = mv.DisassemblerView.SelectedAddress2 or a
        local address = math.min(a, b)
        createCallChainLogForm(address)
    end
end

applyExtension()
