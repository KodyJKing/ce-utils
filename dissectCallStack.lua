local module = {}

------------------
-- Misc Helpers --
------------------

local function toHex(n) return string.format("%x", n):upper() end

local function printHex(n) print(toHex(n)) end

local function cwd() return io.popen "cd":read '*l' end

local function getFrameBase()
    if targetIs64Bit() then
        return RBP
    end
    return EBP
end

local pathsep
if getOperatingSystem() == 0 then
    pathsep = [[\]]
else
    pathsep = [[/]]
end

local dev = true
local root
if dev then
    root = cwd() .. pathsep
else
    -- root = getAutoRunPath() .. 'ceutils' .. pathsep
    root = getAutoRunPath() .. pathsep
end
local formPath = root .. pathsep .. 'forms' .. pathsep

--------------------
--- Form Helpers ---
--------------------

local function findSection(menu, n)
    local i = 0
    local count = 0
    while true do
        if count == n then return i end
        if menu.Items[i].Caption == "-" then
            count = count + 1
        end
        i = i + 1
    end
end

local function insertInSection(menu, sectionIndex, offset, menuItem)
    menu.Items.insert(findSection(menu, sectionIndex) + offset, menuItem)
end

------------
-- Module --
------------

function module.applyExtension()
    local mv = getMemoryViewForm()
    local mi = createMenuItem(mv.Menu)
    mi.Caption = "Dissect call stack"
    mi.Shortcut = 'Ctrl+Shift+K'
    mi.ImageIndex = 64
    mi.OnClick = module.createSession
    insertInSection(mv.debuggerpopup, 3, -1, mi)
end

function module.createSession()
    local session = {
        onClose = {},
        dialog = createFormFromFile(formPath .. "DissectCallStack.FRM"),
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

        -- print(session.address, session.maxCalls, session.snapshotSize)

        debug_setBreakpoint(session.address, function()
            print("Saving snapshot...")
            local bp = getFrameBase()
            local resultPtr = copyMemory(bp, session.snapshotSize)
            table.insert(session.resultPointers, resultPtr)
        end)
    end

    function session.stop()
        if session.stopped then return end
        session.stopped = true
        session.dialog.findComponentByName("Stop").Enabled = false

        debug_removeBreakpoint(session.address)
    end

    session.addCleanup(session.stop)
    session.addCleanup(function()
        for i, ptr in ipairs(session.resultPointers) do
            print("Deallocating", toHex(ptr))
            deAlloc(ptr)
        end
    end)
    session.addCleanup(function() print("Cleaned up!") end)

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
