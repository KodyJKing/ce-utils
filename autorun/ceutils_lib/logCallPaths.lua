-- local json = require("autorun.ceutils_lib.json")

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
    return common.padLeft(toHex(x), common.getPointerSize() * 2, "0")
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

    for i = 1, numColumns - 1 do
        rect = listItem.displayRectSubItem(i, 0)
        if x > rect.Left and x < rect.Right then
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
    local selectedAddressString = nil

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

        listView.beginUpdate()
        if record.count == 1 then
            callChainRecords[lines] = record
            record.item = listView.Items.Add()
            record.item.SubItems.text = lines
        end
        record.item.Caption = tostring(record.count)
        listView.endUpdate()
    end

    function hardRefreshListView()
        listView.beginUpdate()
        for i = 0, listView.Items.Count - 1 do
            local item = listView.Items[i]
            item.SubItems.text = item.SubItems.text
        end
        listView.endUpdate()
    end

    function refreshSubItems(text, oldText)
        listView.beginUpdate()
        for i = 0, listView.Items.Count - 1 do
            local subItems = listView.Items[i].SubItems
            for j = 0, subItems.Count - 1 do
                local curText = subItems.getString(j)
                if curText == text or curText == oldText then
                    subItems.setString(j, curText)
                end
            end
        end
        listView.endUpdate()
    end

    -----------

    form.findComponentByName("ToggleBreakpoint").OnClick = toggleAttach
    form.OnClose = function()
        detatch()
        form.Destroy()
    end

    listView.OnClick = function(...)
        local old_selectedAddressString = selectedAddressString
        selectedAddressString = nil

        local numColumns = 2 + NUM_CALLER_COLUMNS
        local item, colIndex = getSubItemUnderMouse(listView, numColumns)

        if item ~= nil and colIndex > 0 then
            selectedAddressString = item.SubItems[colIndex - 1]
            local address = tonumber("0x" .. selectedAddressString)

            local memForm = getMemoryViewForm()
            memForm.visible = true
            memForm.DisassemblerView.selectedAddress = address
        end

        refreshSubItems(selectedAddressString, old_selectedAddressString)
    end

    listView.OnCustomDrawSubItem = function(sender, item, subItem, state)
        local count = item.SubItems.Count
        local index = subItem - 1
        if index >= 0 and index < count then
            local text = item.SubItems.getString(index)
            if text == selectedAddressString then
                listView.Canvas.Font.Color = 0x4040ff
            end
        end
        return true
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
