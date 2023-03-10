local module = {}

--------------------------------------------------------
-- Get working directory and check for dev repository --
--------------------------------------------------------

function module.cwd() return io.popen "cd":read '*l' end

if not module.initialized then
    local pathsep
    if getOperatingSystem() == 0 then
        pathsep = [[\]]
    else
        pathsep = [[/]]
    end

    local _cwd = module.cwd()
    local dev = not not string.find(_cwd, "ce%-utils")
    -- if dev then print("Running CE-Utils in dev mode.") end

    local rootPath
    if dev then
        rootPath = module.cwd() .. pathsep
    else
        -- rootPath = getAutoRunPath() .. pathsep
        rootPath = getCheatEngineDir()
    end

    module.formPath = rootPath .. "autorun" .. pathsep .. "ceutils_lib" .. pathsep .. 'forms' .. pathsep
    module.rootPath = rootPath
    module.dev = dev

    -- print("Root Path =", rootPath)
    -- print("Form Path =", formPath)
    -- print("")

    module.initialized = true
end

----------------------------------------------------------

function module.reloadPackage(path)
    package.loaded[path] = nil
    return require(path)
end

----------------------------------------------------------

function module.toHex(n) return string.format("%x", n):upper() end

function module.printHex(n) print(module.toHex(n)) end

function module.padLeft(str, len, char)
    char = char or ' '
    return string.rep(char, len - #str) .. str
end

function module.padRight(str, len, char)
    char = char or ' '
    return str .. string.rep(char, len - #str)
end

----------------------------------------------------------

local function getItem(menu, i)
    if menu.ClassName == "TMenuItem" then
        return menu.Item[i]
    end
    return menu.Items[i]
end

local function insertItem(menu, i, mi)
    if menu.ClassName == "TMenuItem" then
        return menu.insert(i, mi)
    end
    return menu.Items.insert(i, mi)
end

local function getCount(menu)
    if menu.ClassName == "TMenuItem" then
        return menu.Count
    end
    return menu.Items.Count
end

function module.findSection(menu, n)
    local i = 0
    local count = 0
    while true do
        if count == n then return i end
        -- Items with caption "-" are treated as dividers.
        if getItem(menu, i).Caption == "-" then
            count = count + 1
        end
        i = i + 1
    end
end

function module.insertMenuItemInSection(menu, sectionIndex, offset, menuItem)
    insertItem(menu, module.findSection(menu, sectionIndex) + offset, menuItem)
end

function module.findItemWithCaption(menu, caption)
    for i = 0, getCount(menu) - 1 do
        local item = getItem(menu, i)
        if item.Caption == caption then
            return item, i
        end
    end
end

function module.findFormByCaption(caption)
    for i = 0, getFormCount() - 1 do
        local form = getForm(i)
        if form.Caption == caption then
            return form
        end
    end
    return nil
end

function module.listForms()
    for i = 0, getFormCount() - 1 do
        print(getForm(i).Caption)
    end
end

function module.printComponentTree(comp, prefix, dent, visited)
    visited = visited or {}
    prefix = prefix or ""
    dent = dent or ""

    for i, v in ipairs(visited) do
        if v == comp then
            return
        end
    end
    table.insert(visited, comp)

    local caption = comp.Caption
    if caption then
        caption = "(" .. caption .. ")"
    else
        caption = ""
    end

    print(dent .. prefix .. comp.ClassName .. ": " .. comp.Name .. " " .. caption)

    local nextDent = dent .. "    "
    local isMenu = false
        or comp.ClassName == "TMenu"
        or comp.ClassName == "TPopupMenu"
        or comp.ClassName == "TMainMenu"
    local isMenuItem = comp.ClassName == "TMenuItem"

    if isMenu then
        for i = 0, comp.Items.Count - 1 do
            module.printComponentTree(
                comp.Items[i], "[" .. i .. "] ",
                nextDent, visited)
        end
    elseif isMenuItem then
        for i = 0, comp.Count - 1 do
            module.printComponentTree(
                comp.Item[i], "[" .. i .. "] ",
                nextDent, visited)
        end
    end

    for i = 0, comp.getComponentCount() - 1 do
        module.printComponentTree(
            comp.getComponent(i), "",
            nextDent, visited)
    end
end

function module.addStructAddress(structForm, address)
    local column = structForm.addColumn()
    column.AddressText = module.toHex(address)
end

----------------------------------------------------------

function module.getBasePointer()
    if targetIs64Bit() then return RBP end
    return EBP
end

function module.getStackPointer()
    if targetIs64Bit() then return RSP end
    return ESP
end

function module.getPointerSize()
    if targetIs64Bit() then return 8 end
    return 4
end

function module.readLong(memStream)
    if targetIs64Bit() then return memStream.readQword() end
    return memStream.readDword()
end

function module.writeLong(memStream, num)
    if targetIs64Bit() then memStream.writeQword(num) end
    memStream.writeDword(num)
end

module.getLongSize = module.getPointerSize

----------------------------------------------------------

return module
