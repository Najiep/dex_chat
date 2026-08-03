-- Run with a Lua 5.4-compatible interpreter from the resource root.
dofile('config/shared.lua')
dofile('config/themes.lua')
dofile('config/channels.lua')
dofile('config/organizations.lua')
dofile('config/security.lua')
dofile('config/logging.lua')
dofile('locales/en.lua')
dofile('locales/tl.lua')
dofile('shared/constants.lua')
dofile('shared/utils.lua')

assert(type(Config.Channels) == 'table', 'Config.Channels is required')
assert(type(Config.Themes) == 'table', 'Config.Themes is required')
assert(type(Config.MessageThemes) == 'table', 'Config.MessageThemes is required')
assert(Config.Channels.normal and Config.Channels.normal.enabled ~= false, 'normal channel must be enabled')
assert(Config.Themes[Config.UI.Theme], 'default UI theme does not exist')

local commands = {}
local function register(command, owner)
    if not command then return end
    command = DexChat.NormalizeCommand(command)
    assert(command, ('invalid command in %s'):format(owner))
    assert(not Config.Security.ReservedCommands[command], ('reserved command /%s used by %s'):format(command, owner))
    assert(not commands[command], ('duplicate command /%s used by %s and %s'):format(command, commands[command], owner))
    commands[command] = owner
end

for key, channel in pairs(Config.Channels) do
    if channel.enabled ~= false then
        assert(Config.MessageThemes[channel.theme or 'normal'], ('missing message theme for channel %s'):format(key))
        if key ~= 'normal' then
            register(channel.command, 'channel:' .. key)
            for _, alias in ipairs(channel.aliases or {}) do register(alias, 'channel:' .. key) end
        end
        assert((tonumber(channel.maxLength) or 0) > 0, ('invalid maxLength for channel %s'):format(key))
        assert((tonumber(channel.cooldown) or 0) >= 0, ('invalid cooldown for channel %s'):format(key))
    end
end

for key, organization in pairs(Config.Organizations or {}) do
    if organization.enabled then
        assert(organization.type == 'job' or organization.type == 'gang', ('invalid organization type for %s'):format(key))
        register(organization.command, 'organization:' .. key)
        for _, alias in ipairs(organization.aliases or {}) do register(alias, 'organization:' .. key) end
        local banner = organization.banner or {}
        for _, colorKey in ipairs({ 'primary', 'secondary', 'border', 'text' }) do
            if banner[colorKey] then
                assert(DexChat.IsValidHexColor(banner[colorKey]), ('invalid %s color for %s'):format(colorKey, key))
            end
        end
    end
end

if Config.PrivateMessages.Enabled then
    register(Config.PrivateMessages.Command, 'private')
    for _, alias in ipairs(Config.PrivateMessages.Aliases or {}) do register(alias, 'private') end
    register(Config.PrivateMessages.ReplyCommand, 'private-reply')
    for _, alias in ipairs(Config.PrivateMessages.ReplyAliases or {}) do register(alias, 'private-reply') end
end

assert(Locales.en and Locales.tl, 'English and Tagalog locales are required')
assert(DexChat.MessageSchema >= 2, 'v2 message schema expected')

print(('dex_chat config tests passed (%d registered commands)'):format(DexChat.CountTable(commands)))
