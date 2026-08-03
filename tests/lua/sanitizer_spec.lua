-- Run with a Lua 5.4-compatible interpreter from the resource root.
dofile('config/shared.lua')
dofile('config/security.lua')
dofile('shared/constants.lua')
dofile('shared/utils.lua')
dofile('shared/sanitizer.lua')

local cases = {
    { '  hello   world  ', 250, 'hello world' },
    { 'hello\nworld', 250, 'hello world' },
    { 'Kamusta mga kaibigan', 250, 'Kamusta mga kaibigan' },
    { '<script>alert(1)</script>', 250, '<script>alert(1)</script>' }
}

for _, case in ipairs(cases) do
    local value, reason = DexChat.Sanitize(case[1], case[2])
    assert(value == case[3], ('unexpected sanitizer result: %s (%s)'):format(tostring(value), tostring(reason)))
end

local empty, reason = DexChat.Sanitize('   ', 20)
assert(empty == nil and reason == 'empty')

local truncated = DexChat.Sanitize(string.rep('a', 300), 12)
assert(truncated == string.rep('a', 12))

print('dex_chat sanitizer tests passed')
