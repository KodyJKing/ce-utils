local module = {}

function module.map(array, fn)
    local result = {}
    for i, v in ipairs(array) do
        table.insert(result, fn(v))
    end
    return result
end

function module.filter(array, test)
    local result = {}
    for i, v in ipairs(array) do
        if test(v) then
            table.insert(result, v)
        end
    end
    return result
end

function module.reduce(array, initial, reducer)
    local result = {}
    local current = initial
    for i, v in ipairs(array) do
        current = reducer(current, v)
        table.insert(result, current)
    end
    return result
end

return module
