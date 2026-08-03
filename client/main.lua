local inputOpen = false
local settingsOpen = false
local loaded = false
local hideState = tonumber(GetResourceKvpString('dex_chat:hideState')) or 0
local suggestions = {}
local modes = {}
local permissions = { staff = false, showPlayerIds = false }
local typingPlayers = {}
local floatingMessages = {}

local defaultPreferences = {
    theme = Config.UI.Theme,
    scale = Config.UI.Scale,
    opacity = Config.UI.Opacity,
    compact = Config.UI.Compact,
    reducedMotion = Config.UI.ReducedMotion,
    blur = Config.UI.Blur,
    showTimestamps = Config.Messages.ShowTimestamps
}

local function loadPreferences()
    local raw = GetResourceKvpString('dex_chat:preferences')
    if not raw or raw == '' then return DexChat.CopyTable(defaultPreferences) end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then return DexChat.CopyTable(defaultPreferences) end

    local output = DexChat.CopyTable(defaultPreferences)
    for key, value in pairs(decoded) do output[key] = value end
    return output
end

local preferences = loadPreferences()

local function getClientTimestamp()
    if type(GetCloudTimeAsInt) == 'function' then
        local timestamp = GetCloudTimeAsInt()
        if type(timestamp) == 'number' and timestamp > 0 then return timestamp end
    end
    return nil
end

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function quickChannels()
    local channels = {}
    for key, channel in pairs(Config.Channels or {}) do
        if channel.enabled ~= false and channel.quick then
            channels[#channels + 1] = {
                key = key,
                label = channel.label or key:upper(),
                command = channel.command,
                theme = channel.theme or 'normal'
            }
        end
    end
    table.sort(channels, function(a, b)
        if a.key == 'normal' then return true end
        if b.key == 'normal' then return false end
        return a.label < b.label
    end)
    return channels
end

local function configureNui()
    if not loaded then return end
    send('CONFIGURE', {
        historyLimit = Config.Messages.ClientHistoryLimit,
        hideState = hideState,
        ui = Config.UI,
        themes = Config.Themes,
        messageThemes = Config.MessageThemes,
        preferences = preferences,
        quickChannels = quickChannels(),
        permissions = permissions,
        maxLength = Config.Input.MaxLength
    })
end

local function setTyping(value)
    if Config.TypingIndicator.Enabled then TriggerServerEvent('dex_chat:setTyping', value == true) end
end

local function setInput(open)
    inputOpen = open
    if open then settingsOpen = false end
    SetNuiFocus(open, open)
    SetNuiFocusKeepInput(false)
    setTyping(open)
    send(open and 'OPEN_INPUT' or 'CLOSE_INPUT', {
        maxLength = Config.Input.MaxLength,
        suggestions = suggestions,
        modes = modes
    })
end

local function setSettings(open)
    settingsOpen = open
    if open then inputOpen = false end
    SetNuiFocus(open, open)
    SetNuiFocusKeepInput(false)
    setTyping(false)
    send(open and 'OPEN_SETTINGS' or 'CLOSE_SETTINGS', {
        preferences = preferences,
        themes = Config.Themes
    })
end

local function normalizeCompatibilityMessage(message)
    if type(message) == 'string' then
        return {
            schema = DexChat.MessageSchema,
            kind = DexChat.MessageKind.CHAT,
            text = message,
            timestamp = getClientTimestamp(),
            duration = Config.Messages.DefaultDuration,
            sender = { name = '' },
            presentation = { variant = 'normal', themeId = 'normal' }
        }
    end

    message = message or {}
    if message.schema then return message end

    local args = message.args or {}
    local author = #args > 1 and tostring(args[1]) or ''
    local text = tostring(args[#args] or '')

    return {
        schema = DexChat.MessageSchema,
        kind = DexChat.MessageKind.CHAT,
        text = text,
        timestamp = getClientTimestamp(),
        duration = Config.Messages.DefaultDuration,
        channel = message.mode,
        sender = { name = author },
        presentation = {
            variant = 'normal',
            color = message.color,
            themeId = 'normal'
        }
    }
end

local function addMessage(message)
    send('ADD_MESSAGE', normalizeCompatibilityMessage(message))
end

RegisterNetEvent('dex_chat:addMessage', addMessage)
RegisterNetEvent('chat:addMessage', addMessage)
exports('addMessage', addMessage)

RegisterNetEvent('chatMessage', function(author, color, text)
    addMessage({ args = { author, text }, color = color, multiline = true })
end)

RegisterNetEvent('__cfx_internal:serverPrint', function(message)
    print(message)
    addMessage({
        schema = DexChat.MessageSchema,
        kind = DexChat.MessageKind.PRINT,
        text = message,
        timestamp = getClientTimestamp(),
        duration = Config.Messages.DefaultDuration,
        sender = { name = 'SERVER' },
        critical = true,
        presentation = { variant = 'system', themeId = 'system' }
    })
end)

RegisterNetEvent('dex_chat:notify', function(data)
    local isError = data and data.type == 'error'
    addMessage({
        schema = DexChat.MessageSchema,
        kind = DexChat.MessageKind.SYSTEM,
        text = tostring(data and data.message or ''),
        timestamp = getClientTimestamp(),
        duration = 6500,
        sender = { name = isError and 'ERROR' or 'INFO' },
        critical = isError,
        presentation = { variant = isError and 'error' or 'system', themeId = isError and 'error' or 'system' }
    })
end)

RegisterNetEvent('dex_chat:setPermissions', function(data)
    if type(data) ~= 'table' then return end
    permissions.staff = data.staff == true
    permissions.showPlayerIds = data.showPlayerIds == true
    configureNui()
end)

local function addSuggestion(name, help, params)
    if type(name) == 'table' then
        local item = name
        name, help, params = item.name, item.help, item.params
    end
    if not name then return end

    for index, existing in ipairs(suggestions) do
        if existing.name == name then
            suggestions[index] = { name = name, help = help or '', params = params or {} }
            send('SET_SUGGESTIONS', suggestions)
            return
        end
    end

    suggestions[#suggestions + 1] = { name = name, help = help or '', params = params or {} }
    send('SET_SUGGESTIONS', suggestions)
end

RegisterNetEvent('chat:addSuggestion', addSuggestion)
exports('addSuggestion', addSuggestion)

RegisterNetEvent('chat:addSuggestions', function(items)
    for _, item in ipairs(items or {}) do addSuggestion(item) end
end)

RegisterNetEvent('chat:removeSuggestion', function(name)
    for index = #suggestions, 1, -1 do
        if suggestions[index].name == name then table.remove(suggestions, index) end
    end
    send('SET_SUGGESTIONS', suggestions)
end)

RegisterNetEvent('chat:addMode', function(mode)
    if not mode or not mode.name then return end
    modes[mode.name] = mode
    send('SET_MODES', modes)
end)

RegisterNetEvent('chat:removeMode', function(name)
    if type(name) == 'table' then name = name.name end
    modes[name] = nil
    send('SET_MODES', modes)
end)

RegisterNetEvent('chat:addTemplate', function(id, html)
    -- Kept for stock API compatibility. The NUI never renders raw HTML.
    send('ADD_TEMPLATE', { id = id, html = html })
end)

RegisterNetEvent('chat:clear', function()
    send('CLEAR_MESSAGES')
end)

RegisterNetEvent('dex_chat:setTyping', function(serverId, value)
    if serverId == GetPlayerServerId(PlayerId()) then return end
    if value then typingPlayers[serverId] = true else typingPlayers[serverId] = nil end
end)

RegisterNetEvent('dex_chat:show3D', function(serverId, text, theme, duration)
    floatingMessages[serverId] = {
        text = tostring(text or ''),
        theme = theme or 'roleplay',
        expiresAt = GetGameTimer() + math.max(1500, tonumber(duration) or 7000)
    }
end)

RegisterCommand('dexchat_open', function()
    if hideState == 2 or inputOpen or settingsOpen then return end
    setInput(true)
end, false)
RegisterKeyMapping('dexchat_open', 'Open Dex Chat', 'keyboard', Config.Input.DefaultKey)

RegisterCommand('toggleChat', function()
    hideState = (hideState + 1) % 3
    SetResourceKvp('dex_chat:hideState', tostring(hideState))
    send('SET_HIDE_STATE', hideState)
end, false)

RegisterCommand(Config.Input.OpenSettingsCommand, function()
    if settingsOpen then setSettings(false) else setSettings(true) end
end, false)
RegisterKeyMapping(Config.Input.OpenSettingsCommand, 'Open Dex Chat Settings', 'keyboard', Config.Input.OpenSettingsKey)

RegisterNUICallback('loaded', function(_, callback)
    loaded = true
    configureNui()
    TriggerServerEvent('chat:init')
    callback({ ok = true })
end)

RegisterNUICallback('submit', function(data, callback)
    local message = type(data) == 'table' and tostring(data.message or '') or ''
    local mode = type(data) == 'table' and data.mode or nil
    setInput(false)

    if message ~= '' then
        if message:sub(1, 1) == '/' then
            ExecuteCommand(message:sub(2))
        else
            TriggerServerEvent('_chat:messageEntered', GetPlayerName(PlayerId()), { 255, 255, 255 }, message, mode)
        end
    end

    callback({ ok = true })
end)

RegisterNUICallback('close', function(_, callback)
    if inputOpen then setInput(false) end
    if settingsOpen then setSettings(false) end
    callback({ ok = true })
end)

RegisterNUICallback('saveSettings', function(data, callback)
    data = type(data) == 'table' and data or {}
    local theme = type(data.theme) == 'string' and data.theme or preferences.theme
    if not Config.Themes[theme] then theme = Config.UI.Theme end

    preferences = {
        theme = theme,
        scale = DexChat.Clamp(data.scale or preferences.scale, 0.75, 1.35),
        opacity = DexChat.Clamp(data.opacity or preferences.opacity, 0.45, 1.0),
        compact = data.compact == true,
        reducedMotion = data.reducedMotion == true,
        blur = data.blur ~= false,
        showTimestamps = data.showTimestamps ~= false
    }

    SetResourceKvp('dex_chat:preferences', json.encode(preferences))
    configureNui()
    callback({ ok = true, preferences = preferences })
end)

local function drawText3D(coords, text, scale)
    local visible, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not visible then return end

    SetTextScale(0.0, scale or 0.32)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 230)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

CreateThread(function()
    SetTextChatEnabled(false)
    SetNuiFocus(false, false)

    while not loaded do Wait(250) end
    send('SET_HIDE_STATE', hideState)

    while true do
        local active = false
        local timestamp = GetGameTimer()
        local localPed = PlayerPedId()
        local localCoords = GetEntityCoords(localPed)

        for serverId in pairs(typingPlayers) do
            local player = GetPlayerFromServerId(serverId)
            if player ~= -1 then
                local ped = GetPlayerPed(player)
                if ped ~= 0 then
                    local coords = GetEntityCoords(ped)
                    if #(localCoords - coords) <= Config.Proximity.TypingIndicatorDistance then
                        active = true
                        drawText3D(coords + vector3(0.0, 0.0, Config.TypingIndicator.HeightOffset), Config.TypingIndicator.Text, Config.TypingIndicator.Scale)
                    end
                end
            else
                typingPlayers[serverId] = nil
            end
        end

        for serverId, entry in pairs(floatingMessages) do
            if entry.expiresAt <= timestamp then
                floatingMessages[serverId] = nil
            else
                local player = GetPlayerFromServerId(serverId)
                if player ~= -1 then
                    local ped = GetPlayerPed(player)
                    if ped ~= 0 then
                        local coords = GetEntityCoords(ped)
                        if #(localCoords - coords) <= Config.Proximity.RoleplayDistance + 5.0 then
                            active = true
                            drawText3D(coords + vector3(0.0, 0.0, 1.22), entry.text, 0.30)
                        end
                    end
                end
            end
        end

        Wait(active and 0 or 350)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    setTyping(false)
    SetNuiFocus(false, false)
end)
