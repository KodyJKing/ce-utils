local common = require("autorun.ceutils_lib.common")
local functional = require("autorun.ceutils_lib.functional")

local toHex = common.toHex

local codelistForm = common.findFormByCaption("Code list/Pause")

if codelistForm == nil then
    print("Could not initialize code context export feature because codelist form could not be found.")
    return
end

local lvCodelist = codelistForm.findComponentByName("lvCodelist")

local function printInstructionContext(address, printLine)
    local lineRadius = 10
    local bytesPerLine = 10

    local byteRadius = lineRadius * bytesPerLine

    local function getByteText(address, n)
        local bytes = readBytes(address, n, true)
        local textBytes = functional.map(bytes, function(byte) return common.padLeft(toHex(byte), 2, "0") end)
        return table.concat(textBytes, " ")
    end

    local function printLines(base, n)
        local head = base
        for i = 1, n do
            printLine(getByteText(head, bytesPerLine))
            head = head + bytesPerLine
        end
    end

    printLines(address - byteRadius, lineRadius)

    local dString = disassemble(address)
    local extra, opcode, bytes, _address = splitDisassembledString(dString)
    _bytes, _ = string.gsub(bytes, " ", "")
    local numBytes = math.ceil(#_bytes / 2)

    -- printLine(dString)
    printLine("")
    printLine(">>> " .. bytes)
    printLine("")

    printLines(address + numBytes, lineRadius)
    printLine("")
end

local function printCodeEntry(item, printLine)
    local symbolicAddress = item.Caption
    local address = getAddress(symbolicAddress)
    local name = item.SubItems[0]
    printLine(name .. "\n@" .. symbolicAddress .. "\n")
    printInstructionContext(address, function(line) printLine("    " .. line) end)
end

print("")

local function printCodelistContext(printLine)
    local items = lvCodelist.Items
    for i = 0, items.Count - 1 do
        local item = items[i]
        printCodeEntry(item, printLine)
    end
end

local function printCodelistContextToFile()
    local dialog = createOpenDialog()
    dialog.Title = "Save Code List Context"
    dialog.DefaultExt = "codectx"
    dialog.execute()

    local filename = dialog.FileName
    local file = io.open(filename, "w")

    if file == nil then
        print("Could not create code context file.")
        return
    end

    local function printLine(line) file:write(line .. "\n") end

    printCodelistContext(printLine)

    file:close()
end

local function applyExtension()
    local mainForm = getMainForm()
    local fileMenu = mainForm.findComponentByName("File1")
    local caption = "Export context for saved instructions"
    local mi = common.findItemWithCaption(fileMenu, caption)
    if not mi then
        mi = createMenuItem(fileMenu)
        mi.Caption = caption
        common.insertMenuItemInSection(fileMenu, 2, 1, mi)
    end
    mi.OnClick = printCodelistContextToFile
end

applyExtension()
