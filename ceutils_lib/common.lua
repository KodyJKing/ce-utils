--------------------------------------------------------
-- Get working directory and check for dev repository --
--------------------------------------------------------

local function cwd() return io.popen "cd":read '*l' end

local pathsep
if getOperatingSystem() == 0 then
    pathsep = [[\]]
else
    pathsep = [[/]]
end

local _cwd = cwd()
local dev = not string.find(_cwd, "autorun")
if dev then print("Running CE-Utils in dev mode.") end
local rootPath
if dev then
    rootPath = cwd() .. pathsep
else
    rootPath = getAutoRunPath() .. pathsep
end
local formPath = rootPath .. pathsep .. 'forms' .. pathsep

----------------------------------------------------------

local function toHex(n) return string.format("%x", n):upper() end

local function printHex(n) print(toHex(n)) end

local function padLeft(str, len, char)
    char = char or ' '
    return string.rep(char, len - #str) .. str
end

local function padRight(str, len, char)
    char = char or ' '
    return str .. string.rep(char, len - #str)
end

----------------------------------------------------------

local function getBasePointer()
    if targetIs64Bit() then return RBP end
    return EBP
end

local function getStackPointer()
    if targetIs64Bit() then return RSP end
    return ESP
end

local function getPointerSize()
    if targetIs64Bit() then return 8 end
    return 4
end

return {
    dev = dev,
    toHex = toHex,
    printHex = printHex,
    getBasePointer = getBasePointer,
    getStackPointer = getStackPointer,
    getPointerSize = getPointerSize,
    padLeft = padLeft,
    padRight = padRight,
    cwd = cwd,
    formPath = formPath,
    rootPath = rootPath
}