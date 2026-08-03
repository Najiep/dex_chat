DexChat = DexChat or {}

function DexChat.Debug(message, ...)
    if not Config.Debug then return end
    print(('[dex_chat:debug] ' .. message):format(...))
end

function DexChat.Locale(key, replacements)
    local selected = Locales[Config.Locale] or Locales.en or {}
    local fallback = Locales.en or {}
    local value = selected[key] or fallback[key] or key

    for name, replacement in pairs(replacements or {}) do
        value = value:gsub('{' .. name .. '}', tostring(replacement))
    end

    return value
end

function DexChat.CopyTable(input)
    if type(input) ~= 'table' then return input end
    local output = {}
    for key, value in pairs(input) do
        output[key] = type(value) == 'table' and DexChat.CopyTable(value) or value
    end
    return output
end

function DexChat.TableContains(input, expected)
    if type(input) ~= 'table' then return false end
    for _, value in pairs(input) do
        if value == expected then return true end
    end
    return false
end

function DexChat.IsValidHexColor(value)
    return type(value) == 'string' and value:match('^#%x%x%x%x%x%x$') ~= nil
end

function DexChat.Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function DexChat.EscapePattern(value)
    return tostring(value):gsub('([^%w])', '%%%1')
end

function DexChat.NormalizeCommand(value)
    value = tostring(value or ''):lower():gsub('^/', '')
    if not value:match('^[%w_%-]+$') then return nil end
    return value
end

function DexChat.ApplyTemplate(template, values)
    local output = tostring(template or '{message}')
    for key, value in pairs(values or {}) do
        output = output:gsub('{' .. key .. '}', tostring(value))
    end
    return output
end

function DexChat.CountTable(input)
    local count = 0
    for _ in pairs(input or {}) do count = count + 1 end
    return count
end
