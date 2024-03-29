local module = {}
local common = require("autorun.ceutils_lib.common")

------------------
-- Misc Helpers --
------------------

local toHex = common.toHex
local formPath = common.formPath

------------
-- Module --
------------

function module.applyExtension()
    local mv = getMemoryViewForm()

    local caption = "Dissect call stack"
    local mi = common.findItemWithCaption(mv.debuggerpopup, caption)
    if not mi then
        mi = createMenuItem(mv.Menu)
        mi.Caption = caption
        mi.Shortcut = 'Ctrl+Shift+K'
        mi.ImageIndex = 64 -- Stack Debug Icon
        -- Insert at the end of section 2.
        common.insertMenuItemInSection(mv.debuggerpopup, 3, -1, mi)
    end
    mi.OnClick = module.createSession
end

function module.createSession()
    local session = {
        onClose = {},
        dialog = createFormFromFile(formPath .. "DissectCallStack.FRM"),
        structForm = nil,
        resultPointers = {},
    }

    function session.addCleanup(callback)
        table.insert(session.onClose, callback)
    end

    function session.cleanup()
        for i, callback in ipairs(session.onClose) do
            callback()
        end
        return false
    end

    function session.close()
        session.dialog.close()
    end

    function session.start()
        if session.started then return end
        session.started = true
        session.dialog.findComponentByName("Start").Enabled = false
        session.dialog.findComponentByName("Inputs").Enabled = false

        session.maxCalls = tonumber(session.dialog.findComponentByName("MaxCalls").Text)
        session.snapshotSize = tonumber(session.dialog.findComponentByName("SnapshotSize").Text)
        session.useStackPointer = session.dialog.findComponentByName("UseStackPointer").Checked

        local foundLabel = session.dialog.findComponentByName("Found")

        debug_setBreakpoint(session.address, function()
            -- print("Saving snapshot...")
            local ptr
            if session.useStackPointer then
                ptr = common.getStackPointer()
            else
                ptr = common.getBasePointer()
            end
            local resultPtr = copyMemory(ptr, session.snapshotSize)
            table.insert(session.resultPointers, resultPtr)

            local found = #session.resultPointers
            foundLabel.Caption = tostring(found)

            if session.structForm == nil then
                session.structForm = createStructureForm(toHex(resultPtr))
            else
                common.addStructAddress(session.structForm, resultPtr)
            end

            if found >= session.maxCalls then
                session.stop()
            end
        end)
    end

    session.addCleanup(function()
        for i, ptr in ipairs(session.resultPointers) do
            -- print("Deallocating", toHex(ptr))
            deAlloc(ptr)
        end
    end)

    function session.stop()
        if session.stopped then return end
        session.stopped = true
        session.dialog.findComponentByName("Stop").Enabled = false

        debug_removeBreakpoint(session.address)
    end

    session.addCleanup(session.stop)

    session.addCleanup(function()
        if session.structForm ~= nil then
            session.structForm.close()
        end
    end)
    -- session.addCleanup(function() print("Cleaned up!") end)

    local mv = getMemoryViewForm()
    local a = mv.DisassemblerView.SelectedAddress
    local b = mv.DisassemblerView.SelectedAddress2 or a
    session.address = math.min(a, b)

    session.dialog.findComponentByName("Start").OnClick = session.start
    session.dialog.findComponentByName("Close").OnClick = session.close
    session.dialog.findComponentByName("Stop").OnClick = session.stop
    session.dialog.visible = true

    session.dialog.OnClose = function()
        session.cleanup()
        session.dialog.OnClose = nil
        session.dialog.close()
    end
end

module.applyExtension()
