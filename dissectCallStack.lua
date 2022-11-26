local dissectCallStack = {}

local function cwd()
    return io.popen "cd":read '*l'
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
    root = getAutoRunPath() .. 'ceutils' .. pathsep
end
local formPath = root .. pathsep .. 'forms' .. pathsep
-- print(root)

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

local function applyExtension()
    local mv = getMemoryViewForm()
    local mi = createMenuItem(mv.Menu)
    mi.Caption = "Dissect call stack"
    mi.Shortcut = 'Ctrl+Shift+K'
    mi.ImageIndex = 64
    mi.OnClick = function() print("Not implemented!") end
    insertInSection(mv.debuggerpopup, 3, -1, mi)
end

local frm = createFormFromFile(formPath .. "DissectCallStack.FRM")
frm.visible = true
