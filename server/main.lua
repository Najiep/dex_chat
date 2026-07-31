local hooks = {}
local modes = {}
local commandOwners = {}
local playerCooldowns = {}
local organizationCooldowns = {}
local violations = {}
local mutedUntil = {}
local messageCounter = 0

local function now()
    return os.time()
end

local function nextMessageId()
    messageCounter = (messageCounter + 1) % 1000000
    return ('%s-%06d'):format(now(), messageCounter)
end

local function logMessage(category, source, message, organization)
    local playerName = source > 0 and Bridge.GetCharacterName(source) or 'console'
    local line = ('[%s] %s (%s): %s'):format(category, playerName, source, message)

    if Config.Logging.Console then
        print(('[dex_chat] %s'):format(line))
    end

    local discord = Config.Logging.Discord
    if not discord.Enabled or discord.Webhook == '' then return end

    local payload = {
        username = discord.Username or 'Dex Chat',
        avatar_url = discord.AvatarUrl or '',
        embeds = {{
            title = organization and organization.label or category,
            description = message,
            color = 5793266,
            fields = {
                { name = 'Sender', value = playerName, inline = true },
                { name = 'Server ID', value = tostring(source), inline = true },
                { name = 'Category', value = category, inline = true }
            },
            footer = { text = 'dex_chat' }
        }}
    }

    PerformHttpRequest(discord.Webhook, function() end, 'POST', json.encode(payload), {
        ['Content-Type'] = 'application/json'
    })
end

local function addViolation(source)
    local timestamp = now()
    local entry = violations[source]

    if not entry or timestamp - entry.startedAt > Config.Security.ViolationWindow then
        entry = { count = 0, startedAt = timestamp }
        violations[source] = entry
    end

    entry.count = entry.count + 1

    if entry.count >= Config.Security.MaxViolations then
        mutedUntil[source] = timestamp + Config.Security.TemporaryMuteSeconds
        violations[source] = nil
    end
end

local function checkMuted(source)
    local expiresAt = mutedUntil[source] or 0
    if expiresAt <= now() then
        mutedUntil[source] = nil
        return false, 0
    end
    return true, expiresAt - now()
end

local function checkCooldown(source, key, seconds)
    if source > 0 and IsPlayerAceAllowed(source, Config.Security.CooldownBypassAce) then
        return false, 0
    end

    local timestamp = now()
    local playerState = playerCooldowns[source] or {}
    playerCooldowns[source] = playerState
    local expiresAt = playerState[key] or 0

    if expiresAt > timestamp then
        addViolation(source)
        return true, expiresAt - timestamp
    end

    playerState[key] = timestamp + math.max(0, tonumber(seconds) or 0)
    return false, 0
end

local function getPlayersInBucket(bucket)
    local recipients = {}
    for _, player in ipairs(GetPlayers()) do
        local target = tonumber(player)
        if target and GetPlayerRoutingBucket(target) == bucket then
            recipients[#recipients + 1] = target
        end
    end
    return recipients
end

local function getPlayersInProximity(source, distance)
    local sourcePed = GetPlayerPed(source)
    if sourcePed == 0 then return { source } end

    local sourceCoords = GetEntityCoords(sourcePed)
    local sourceBucket = GetPlayerRoutingBucket(source)
    local recipients = {}

    for _, player in ipairs(GetPlayers()) do
        local target = tonumber(player)
        if target and (not Config.Routing.BucketIsolation or GetPlayerRoutingBucket(target) == sourceBucket) then
            local targetPed = GetPlayerPed(target)
            if targetPed ~= 0 then
                local targetCoords = GetEntityCoords(targetPed)
                if #(sourceCoords - targetCoords) <= distance then
                    recipients[#recipients + 1] = target
                end
            end
        end
    end

    return recipients
end

local function resolveRecipients(source, scope, organization)
    if scope == 'global' then return -1 end

    if scope == 'proximity' and source > 0 then
        return getPlayersInProximity(source, Config.Proximity.Distance)
    end

    if scope == 'organization' and organization then
        local recipients = {}
        local sourceBucket = source > 0 and GetPlayerRoutingBucket(source) or nil

        for _, player in ipairs(GetPlayers()) do
            local target = tonumber(player)
            if target and (not Config.Routing.BucketIsolation or not sourceBucket or GetPlayerRoutingBucket(target) == sourceBucket) then
                local membership = organization.type == 'job' and Bridge.GetJob(target) or Bridge.GetGang(target)
                if membership.name == organization.name then
                    recipients[#recipients + 1] = target
                end
            end
        end

        return recipients
    end

    if source > 0 and Config.Routing.BucketIsolation then
        return getPlayersInBucket(GetPlayerRoutingBucket(source))
    end

    return -1
end

local function emitMessage(targets, payload)
    if type(targets) == 'table' then
        for _, target in ipairs(targets) do
            TriggerClientEvent('dex_chat:addMessage', target, payload)
        end
        return
    end

    TriggerClientEvent('dex_chat:addMessage', targets, payload)
end

local function notify(source, key, values, messageType)
    Bridge.Notify(source, DexChat.Locale(key, values), messageType or 'error')
end

local function canonicalMessage(kind, source, text, extra)
    local payload = {
        schema = DexChat.MessageSchema,
        id = nextMessageId(),
        kind = kind,
        text = text,
        timestamp = now(),
        duration = Config.Messages.DefaultDuration,
        sender = {
            serverId = source,
            name = source > 0 and Bridge.GetCharacterName(source) or 'Console'
        }
    }

    for key, value in pairs(extra or {}) do
        payload[key] = value
    end

    return payload
end

local function runHooks(source, payload, context)
    local canceled = false
    local hookReference = {
        updateMessage = function(changes)
            if type(changes) ~= 'table' then return end
            for key, value in pairs(changes) do payload[key] = value end
        end,
        cancel = function() canceled = true end,
        setRouting = function(targets) context.targets = targets end,
        setSeObject = function(seObject)
            local players = {}
            for _, player in ipairs(GetPlayers()) do
                local target = tonumber(player)
                if target and IsPlayerAceAllowed(target, seObject) then
                    players[#players + 1] = target
                end
            end
            context.targets = players
        end
    }

    for _, hook in pairs(hooks) do
        if hook.callback then
            local ok, errorMessage = pcall(hook.callback, source, payload, hookReference)
            if not ok then
                print(('[dex_chat] Message hook failed (%s): %s'):format(hook.resource, errorMessage))
            end
        end
    end

    return canceled
end

local function routeNormalMessage(source, rawMessage, kind, settings)
    if source <= 0 then return end

    local muted, remainingMute = checkMuted(source)
    if muted then return notify(source, 'muted', { seconds = remainingMute }) end

    local text = DexChat.Sanitize(rawMessage, settings.MaxLength)
    if not text then return notify(source, 'empty_message') end

    local limited, remaining = checkCooldown(source, kind, settings.Cooldown)
    if limited then return notify(source, 'cooldown', { seconds = remaining }) end

    local senderName = Bridge.GetCharacterName(source)
    local payload = canonicalMessage(kind, source, text, {
        args = { senderName, text },
        channel = settings.Label,
        presentation = { variant = kind == DexChat.MessageKind.OOC and 'ooc' or 'normal' }
    })

    local context = { targets = resolveRecipients(source, settings.Scope) }
    if runHooks(source, payload, context) then return end

    TriggerEvent('chatMessage', source, senderName, text)
    if WasEventCanceled() then return end

    emitMessage(context.targets, payload)
    logMessage(kind, source, text)
end

local function validateOrganizationConfig()
    local registered = {}
    local valid = {}

    for name, organization in pairs(Config.Organizations or {}) do
        if organization.enabled then
            local command = tostring(organization.command or ''):lower()
            local organizationType = organization.type
            local invalidReason

            if not name:match('^[%w_%-]+$') then invalidReason = 'invalid organization name' end
            if organizationType ~= 'job' and organizationType ~= 'gang' then invalidReason = 'invalid organization type' end
            if not command:match('^[%w_%-]+$') then invalidReason = 'invalid command' end
            if Config.Security.ReservedCommands[command] then invalidReason = 'reserved command' end
            if registered[command] then invalidReason = 'duplicate command' end

            local banner = organization.banner or {}
            for _, key in ipairs({ 'primary', 'secondary', 'border', 'text' }) do
                if banner[key] and not DexChat.IsValidHexColor(banner[key]) then
                    invalidReason = ('invalid %s color'):format(key)
                end
            end

            if invalidReason then
                print(('[dex_chat] Disabled organization %s: %s'):format(name, invalidReason))
            else
                local compiled = DexChat.CopyTable(organization)
                compiled.name = name:lower()
                compiled.command = command
                valid[compiled.name] = compiled
                registered[command] = compiled.name

                for _, alias in ipairs(compiled.aliases or {}) do
                    alias = tostring(alias):lower()
                    if alias:match('^[%w_%-]+$') and not registered[alias] and not Config.Security.ReservedCommands[alias] then
                        registered[alias] = compiled.name
                    else
                        print(('[dex_chat] Ignored invalid/colliding alias %s for %s'):format(alias, compiled.name))
                    end
                end
            end
        end
    end

    return valid, registered
end

local organizations, commandMap = validateOrganizationConfig()

local function authorizeOrganization(source, organization)
    local player = Bridge.GetPlayer(source)
    if not player then return false, 'unavailable' end

    local membership = organization.type == 'job' and player.job or player.gang
    if not membership or membership.name ~= organization.name then
        return false, 'not_member', { organization = organization.label }
    end

    local authorization = organization.authorization or {}
    local grade = tonumber(membership.grade) or 0

    if authorization.allowedGrades and not DexChat.TableContains(authorization.allowedGrades, grade) then
        return false, 'grade_denied'
    end

    if grade < (tonumber(authorization.minimumGrade) or 0) then
        return false, 'grade_denied'
    end

    if authorization.bossOnly and not membership.isBoss then
        return false, 'grade_denied'
    end

    if authorization.requireDuty and not membership.onDuty then
        return false, 'duty_required'
    end

    return true, player, membership
end

local function handleOrganizationCommand(source, args, organization)
    if source <= 0 then return end

    local muted, remainingMute = checkMuted(source)
    if muted then return notify(source, 'muted', { seconds = remainingMute }) end

    local authorized, result, membership = authorizeOrganization(source, organization)
    if not authorized then
        return notify(source, result, membership)
    end

    local settings = organization.message or {}
    local text = DexChat.Sanitize(table.concat(args, ' '), settings.maxLength or Config.Input.MaxLength)
    if not text then
        return notify(source, 'usage', { command = organization.command })
    end

    local limited, remaining = checkCooldown(source, 'org:' .. organization.name, settings.cooldown or 15)
    if limited then return notify(source, 'cooldown', { seconds = remaining }) end

    local globalExpires = organizationCooldowns[organization.name] or 0
    if globalExpires > now() and not IsPlayerAceAllowed(source, Config.Security.CooldownBypassAce) then
        return notify(source, 'cooldown', { seconds = globalExpires - now() })
    end
    organizationCooldowns[organization.name] = now() + (settings.globalCooldown or 0)

    local senderName = settings.anonymous and 'Anonymous Member' or result.characterName
    local banner = organization.banner or {}

    local payload = canonicalMessage(DexChat.MessageKind.ORGANIZATION, source, text, {
        duration = banner.duration or Config.Messages.DefaultDuration,
        organization = {
            name = organization.name,
            type = organization.type,
            label = organization.label,
            shortLabel = organization.shortLabel,
            gradeLabel = membership.gradeLabel
        },
        sender = {
            serverId = source,
            name = senderName,
            gradeLabel = settings.anonymous and nil or membership.gradeLabel
        },
        args = { senderName, text },
        presentation = {
            variant = 'banner',
            title = banner.title or organization.label,
            logo = banner.logo or '',
            primary = banner.primary or '#2563EB',
            secondary = banner.secondary or '#0F172A',
            border = banner.border or '#60A5FA',
            text = banner.text or '#FFFFFF'
        }
    })

    local context = { targets = resolveRecipients(source, settings.scope or 'bucket', organization) }
    if runHooks(source, payload, context) then return end

    emitMessage(context.targets, payload)
    logMessage('organization', source, text, organization)
end

local function registerOrganizationCommands()
    for command, organizationName in pairs(commandMap) do
        local organization = organizations[organizationName]
        RegisterCommand(command, function(source, args)
            handleOrganizationCommand(source, args, organization)
        end, false)
        commandOwners[command] = organizationName
    end
end

registerOrganizationCommands()

if Config.OOC.Enabled then
    RegisterCommand(Config.OOC.Command, function(source, args)
        routeNormalMessage(source, table.concat(args, ' '), DexChat.MessageKind.OOC, Config.OOC)
    end, false)
end

RegisterCommand('clear', function(source)
    if source > 0 then TriggerClientEvent('chat:clear', source) end
end, false)

RegisterCommand('clearall', function(source)
    if source == 0 or IsPlayerAceAllowed(source, Config.Security.StaffAce) then
        TriggerClientEvent('chat:clear', -1)
    else
        notify(source, 'no_permission')
    end
end, false)

RegisterCommand('say', function(source, args, rawCommand)
    local text = rawCommand:sub(5)
    if source == 0 then
        local sanitized = DexChat.Sanitize(text, Config.Input.MaxLength)
        if sanitized then
            emitMessage(-1, canonicalMessage(DexChat.MessageKind.SYSTEM, 0, sanitized, {
                channel = 'CONSOLE',
                presentation = { variant = 'system' }
            }))
        end
    else
        routeNormalMessage(source, text, DexChat.MessageKind.CHAT, Config.NormalChat)
    end
end, false)

RegisterNetEvent('_chat:messageEntered', function(author, color, message, mode)
    local source = source
    if not Config.NormalChat.Enabled then return end

    if mode and modes[mode] and modes[mode].callback then
        if modes[mode].seObject and not IsPlayerAceAllowed(source, modes[mode].seObject) then
            return notify(source, 'no_permission')
        end

        local sanitized = DexChat.Sanitize(message, Config.NormalChat.MaxLength)
        if not sanitized then return notify(source, 'empty_message') end

        local payload = canonicalMessage(DexChat.MessageKind.CHAT, source, sanitized, {
            mode = mode,
            channel = modes[mode].displayName,
            presentation = { variant = 'normal', color = modes[mode].color }
        })
        local context = { targets = resolveRecipients(source, Config.NormalChat.Scope) }
        modes[mode].callback(source, payload, {
            updateMessage = function(changes)
                for key, value in pairs(changes or {}) do payload[key] = value end
            end,
            cancel = function() context.canceled = true end,
            setRouting = function(targets) context.targets = targets end
        })
        if not context.canceled then emitMessage(context.targets, payload) end
        return
    end

    routeNormalMessage(source, message, DexChat.MessageKind.CHAT, Config.NormalChat)
end)

RegisterNetEvent('chat:init', function()
    local source = source
    local suggestions = {}

    for name, mode in pairs(modes) do
        if not mode.seObject or IsPlayerAceAllowed(source, mode.seObject) then
            TriggerClientEvent('chat:addMode', source, {
                name = name,
                displayName = mode.displayName,
                color = mode.color,
                isChannel = mode.isChannel,
                isGlobal = mode.isGlobal
            })
        end
    end

    for command, organizationName in pairs(commandMap) do
        local organization = organizations[organizationName]
        suggestions[#suggestions + 1] = {
            name = '/' .. command,
            help = organization.label .. ' announcement',
            params = {{ name = 'message', help = 'Announcement message' }}
        }
    end

    if Config.OOC.Enabled then
        suggestions[#suggestions + 1] = {
            name = '/' .. Config.OOC.Command,
            help = 'Out-of-character chat',
            params = {{ name = 'message', help = 'OOC message' }}
        }
    end

    TriggerClientEvent('chat:addSuggestions', source, suggestions)
end)

RegisterNetEvent('__cfx_internal:commandFallback', function(command)
    local source = source
    if source > 0 then
        routeNormalMessage(source, '/' .. command, DexChat.MessageKind.CHAT, Config.NormalChat)
        CancelEvent()
    end
end)

RegisterNetEvent('playerJoining', function()
    if not Config.Messages.ShowJoinQuit or GetConvarInt('chat_showJoins', 1) == 0 then return end
    local source = source
    local payload = canonicalMessage(DexChat.MessageKind.SYSTEM, 0, ('%s joined the server.'):format(GetPlayerName(source) or 'A player'), {
        presentation = { variant = 'system' }
    })
    emitMessage(Config.Routing.BucketIsolation and getPlayersInBucket(GetPlayerRoutingBucket(source)) or -1, payload)
end)

AddEventHandler('playerDropped', function(reason)
    local source = source
    local playerName = GetPlayerName(source) or ('Player %s'):format(source)
    local bucket = GetPlayerRoutingBucket(source)

    playerCooldowns[source] = nil
    violations[source] = nil
    mutedUntil[source] = nil

    if not Config.Messages.ShowJoinQuit or GetConvarInt('chat_showQuits', 1) == 0 then return end
    local payload = canonicalMessage(DexChat.MessageKind.SYSTEM, 0, ('%s left the server.'):format(playerName), {
        presentation = { variant = 'system' }
    })
    emitMessage(Config.Routing.BucketIsolation and getPlayersInBucket(bucket) or -1, payload)
end)

RegisterNetEvent('chat:addMessage', function(target, message)
    if source ~= 0 then return end
    if message == nil then
        message = target
        target = -1
    end
    TriggerClientEvent('chat:addMessage', target or -1, message)
end)

exports('addMessage', function(target, message)
    if message == nil then
        message = target
        target = -1
    end
    if not message then return false end
    TriggerClientEvent('chat:addMessage', target or -1, message)
    return true
end)

exports('registerMessageHook', function(callback)
    if type(callback) ~= 'function' then return false end
    hooks[#hooks + 1] = {
        resource = GetInvokingResource() or 'unknown',
        callback = callback
    }
    return true
end)

exports('registerMode', function(modeData)
    if type(modeData) ~= 'table' or not modeData.name or not modeData.displayName or type(modeData.cb) ~= 'function' then
        return false
    end

    modes[modeData.name] = {
        displayName = modeData.displayName,
        color = modeData.color or '#FFFFFF',
        callback = modeData.cb,
        resource = GetInvokingResource() or 'unknown',
        seObject = modeData.seObject,
        isChannel = modeData.isChannel,
        isGlobal = modeData.isGlobal
    }

    local modePayload = {
        name = modeData.name,
        displayName = modeData.displayName,
        color = modeData.color or '#FFFFFF',
        isChannel = modeData.isChannel,
        isGlobal = modeData.isGlobal
    }

    if modeData.seObject then
        for _, player in ipairs(GetPlayers()) do
            local target = tonumber(player)
            if target and IsPlayerAceAllowed(target, modeData.seObject) then
                TriggerClientEvent('chat:addMode', target, modePayload)
            end
        end
    else
        TriggerClientEvent('chat:addMode', -1, modePayload)
    end

    return true
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then return end

    for index = #hooks, 1, -1 do
        if hooks[index].resource == resourceName then table.remove(hooks, index) end
    end

    for name, mode in pairs(modes) do
        if mode.resource == resourceName then
            modes[name] = nil
            TriggerClientEvent('chat:removeMode', -1, name)
        end
    end
end)

print(('[dex_chat] Ready: %d organizations, framework=%s, bucketIsolation=%s'):format(
    (function() local count = 0 for _ in pairs(organizations) do count = count + 1 end return count end)(),
    Bridge.GetFramework(),
    tostring(Config.Routing.BucketIsolation)
))
