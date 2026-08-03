DexChat = DexChat or {}

local function truncateUtf8(value, maxCharacters)
    if utf8.len(value) and utf8.len(value) <= maxCharacters then
        return value
    end

    local characterCount = 0
    local lastByte = 0

    for bytePosition in utf8.codes(value) do
        characterCount = characterCount + 1
        if characterCount > maxCharacters then break end
        lastByte = bytePosition
    end

    if lastByte == 0 then return '' end

    local nextByte = utf8.offset(value, 2, lastByte)
    return value:sub(1, nextByte and (nextByte - 1) or #value)
end

---@param value any
---@param maxLength number
---@return string|nil, string|nil
function DexChat.Sanitize(value, maxLength)
    if type(value) ~= 'string' then
        return nil, 'not_string'
    end

    if #value > (Config.Security.MaxRawBytes or 1024) then
        return nil, 'too_many_bytes'
    end

    value = value:gsub('%z', '')
    value = value:gsub('[\r\n\t]', ' ')
    value = value:gsub('[%c]', '')

    if Config.Security.CollapseWhitespace then
        value = value:gsub('%s+', ' ')
    end

    value = value:match('^%s*(.-)%s*$') or ''

    if value == '' then
        return nil, 'empty'
    end

    local ok = pcall(utf8.len, value)
    if not ok or utf8.len(value) == nil then
        return nil, 'invalid_utf8'
    end

    value = truncateUtf8(value, math.max(1, tonumber(maxLength) or 250))

    if value == '' then
        return nil, 'empty'
    end

    return value, nil
end
