local inputOpen = false
local loaded = false
local hideState = tonumber(GetResourceKvpString('dex_chat:hideState')) or 0
local suggestions = {}
local modes = {}

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function setInput(open)
    inputOpen = open
    SetNuiFocus(open, open)
    SetNuiFocusKeepInput(false)
    send(open and 'OPEN_INPUT' or 'CLOSE_INPUT', {
        maxLength = Config.Input.MaxLength,
        suggestions = suggestions,
        modes = modes
    })
end

local function normalizeCompatibilityMessage(message)
    if type(message) == 'string' then
        return {
            schema = DexChat.MessageSchema,
            kind = DexChat.MessageKind.CHAT,
            text = message,
            timestamp = os.time(),
            duration = Config.Messages.DefaultDuration,
            sender = { name = '' },
            presentation = { variant = 'normal' }
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
        timestamp = os.time(),
        duration = Config.Messages.DefaultDuration,
        channel = message.mode,
        sender = { name = author },
        presentation = {
            variant = 'normal',
            color = message.color
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
        timestamp = os.time(),
        duration = Config.Messages.DefaultDuration,
        sender = { name = 'SERVER' },
        presentation = { variant = 'system' }
    })
end)

RegisterNetEvent('dex_chat:notify', function(data)
    addMessage({
        schema = DexChat.MessageSchema,
        kind = DexChat.MessageKind.SYSTEM,
        text = tostring(data and data.message or ''),
        timestamp = os.time(),
        duration = 6000,
        sender = { name = data and data.type == 'error' and 'ERROR' or 'INFO' },
        presentation = { variant = data and data.type == 'error' and 'error' or 'system' }
    })
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
    -- Templates are recorded for API compatibility but never rendered as raw HTML.
    send('ADD_TEMPLATE', { id = id, html = html })
end)

RegisterNetEvent('chat:clear', function()
    send('CLEAR_MESSAGES')
end)

RegisterCommand('dexchat_open', function()
    if hideState == 2 or inputOpen then return end
    setInput(true)
end, false)

RegisterKeyMapping('dexchat_open', 'Open Dex Chat', 'keyboard', Config.Input.DefaultKey)

RegisterCommand('toggleChat', function()
    hideState = (hideState + 1) % 3
    SetResourceKvp('dex_chat:hideState', tostring(hideState))
    send('SET_HIDE_STATE', hideState)
end, false)

RegisterNUICallback('loaded', function(_, callback)
    loaded = true
    send('CONFIGURE', {
        historyLimit = Config.Messages.ClientHistoryLimit,
        showTimestamps = Config.Messages.ShowTimestamps,
        hideState = hideState
    })
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
    setInput(false)
    callback({ ok = true })
end)

CreateThread(function()
    SetTextChatEnabled(false)
    SetNuiFocus(false, false)

    while not loaded do Wait(250) end
    send('SET_HIDE_STATE', hideState)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)
