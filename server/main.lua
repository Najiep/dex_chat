local hooks = {}
local modes = {}
local registeredCommands = {}
local compiledChannels = {}
local compiledOrganizations = {}
local playerStates = {}
local organizationCooldowns = {}
local lastPrivatePeer = {}
local typingStates = {}
local logQueue = {}
local messageCounter = 0

local function now()
    return os.time()
end

local function nowMs()
    return GetGameTimer()
end

local function hasAce(source, ace)
    return source > 0 and type(ace) == 'string' and ace ~= '' and IsPlayerAceAllowed(source, ace)
end

local function nextMessageId()
    messageCounter = (messageCounter + 1) % 1000000
    return ('%s-%06d'):format(now(), messageCounter)
end

local function stateFor(source)
    local state = playerStates[source]
    if state then return state end

    state = {
        cooldowns = {},
        recent = {},
        lastText = nil,
        lastTextAt = 0,
        violationCount = 0,
        violationStartedAt = 0,
        temporaryMutedUntil = 0,
        staffMutedUntil = 0,
        muteReason = nil
    }
    playerStates[source] = state
    return state
end

local function notify(source, key, values, messageType)
    if source <= 0 then return end
    Bridge.Notify(source, DexChat.Locale(key, values), messageType or 'error')
end

local function enqueueDiscord(payload)
    logQueue[#logQueue + 1] = payload
    if #logQueue > 200 then table.remove(logQueue, 1) end
end

local function logMessage(category, source, message, metadata)
    metadata = metadata or {}
    local playerName = source > 0 and Bridge.GetCharacterName(source) or 'Console'
    local identifier = source > 0 and Bridge.GetIdentifier(source) or 'console'
    local line = ('[%s] %s (%s): %s'):format(category, playerName, source, message)

    if Config.Logging.Console then
        print(('[dex_chat] %s'):format(line))
    end

    local discord = Config.Logging.Discord or {}
    local categories = discord.Categories or {}
    if not discord.Enabled or discord.Webhook == '' or categories[category] == false then return end

    local fields = {
        { name = 'Sender', value = playerName, inline = true },
        { name = 'Server ID', value = tostring(source), inline = true },
        { name = 'Category', value = category, inline = true }
    }

    if Config.Logging.IncludeIdentifiers and identifier then
        fields[#fields + 1] = { name = 'Identifier', value = tostring(identifier), inline = false }
    end
    if metadata.target then
        fields[#fields + 1] = { name = 'Target', value = tostring(metadata.target), inline = true }
    end
    if metadata.channel then
        fields[#fields + 1] = { name = 'Channel', value = tostring(metadata.channel), inline = true }
    end

    enqueueDiscord({
        username = discord.Username or 'Dex Chat',
        avatar_url = discord.AvatarUrl or '',
        embeds = {{
            title = metadata.title or category:upper(),
            description = tostring(message),
            color = metadata.color or 5793266,
            fields = fields,
            footer = { text = ('dex_chat v%s'):format(DexChat.Version) }
        }}
    })
end

CreateThread(function()
    while true do
        if #logQueue == 0 then
            Wait(500)
        else
            local discord = Config.Logging.Discord or {}
            local payload = table.remove(logQueue, 1)
            if discord.Enabled and discord.Webhook and discord.Webhook ~= '' then
                PerformHttpRequest(discord.Webhook, function(status)
                    if Config.Debug and (status < 200 or status >= 300) then
                        print(('[dex_chat] Discord log failed with HTTP %s'):format(status))
                    end
                end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
            end
            Wait(math.max(250, tonumber(discord.MinimumIntervalMs) or 750))
        end
    end
end)

local function addViolation(source, reason)
    if source <= 0 then return end
    local state = stateFor(source)
    local timestamp = now()

    if timestamp - state.violationStartedAt > (Config.Security.ViolationWindow or 60) then
        state.violationStartedAt = timestamp
        state.violationCount = 0
    end

    state.violationCount = state.violationCount + 1
    if state.violationCount >= (Config.Security.MaxViolations or 8) then
        state.temporaryMutedUntil = timestamp + (Config.Security.TemporaryMuteSeconds or 30)
        state.muteReason = reason or 'automatic anti-spam mute'
        state.violationCount = 0
        state.violationStartedAt = timestamp
        logMessage('moderation', source, state.muteReason, { title = 'Temporary mute' })
    end
end

local function checkMuted(source)
    local state = stateFor(source)
    local expiresAt = math.max(state.temporaryMutedUntil or 0, state.staffMutedUntil or 0)
    if expiresAt <= now() then
        if state.temporaryMutedUntil <= now() then state.temporaryMutedUntil = 0 end
        if state.staffMutedUntil <= now() then state.staffMutedUntil = 0 end
        if state.temporaryMutedUntil == 0 and state.staffMutedUntil == 0 then state.muteReason = nil end
        return false, 0
    end
    return true, expiresAt - now(), state.muteReason
end

local function checkCooldown(source, key, seconds)
    if hasAce(source, Config.Security.CooldownBypassAce) then return false, 0 end
    local state = stateFor(source)
    local timestamp = nowMs()
    local expiresAt = state.cooldowns[key] or 0

    if expiresAt > timestamp then
        addViolation(source, 'cooldown abuse')
        return true, math.ceil((expiresAt - timestamp) / 1000)
    end

    state.cooldowns[key] = timestamp + math.max(0, tonumber(seconds) or 0) * 1000
    return false, 0
end

local function checkBurst(source)
    local burst = Config.Security.Burst or {}
    if not burst.Enabled or hasAce(source, Config.Security.CooldownBypassAce) then return false end

    local state = stateFor(source)
    local timestamp = nowMs()
    local cutoff = timestamp - math.max(1, tonumber(burst.WindowSeconds) or 10) * 1000
    local recent = {}

    for _, value in ipairs(state.recent) do
        if value >= cutoff then recent[#recent + 1] = value end
    end
    recent[#recent + 1] = timestamp
    state.recent = recent

    if #recent > math.max(1, tonumber(burst.MaxMessages) or 6) then
        addViolation(source, 'burst spam')
        return true
    end
    return false
end

local function checkDuplicate(source, text)
    local duplicate = Config.Security.Duplicate or {}
    if not duplicate.Enabled or hasAce(source, Config.Security.CooldownBypassAce) then return false end

    local state = stateFor(source)
    local normalized = text:lower()
    local timestamp = nowMs()
    local duplicateWindow = math.max(1, tonumber(duplicate.WindowSeconds) or 8) * 1000

    if state.lastText == normalized and timestamp - state.lastTextAt <= duplicateWindow then
        addViolation(source, 'duplicate spam')
        return true
    end

    state.lastText = normalized
    state.lastTextAt = timestamp
    return false
end

local function urlAllowed(text)
    local filter = Config.Security.Filter or {}
    local lower = text:lower()
    local containsUrl = lower:find('https?://') or lower:find('www%.') or lower:find('discord%.gg/')
    if not containsUrl then return true end
    if not filter.BlockUrls then return true end

    for _, domain in ipairs(filter.AllowedDomains or {}) do
        if lower:find(tostring(domain):lower(), 1, true) then return true end
    end
    return false
end

local function passesFilter(source, text)
    local filter = Config.Security.Filter or {}
    if not filter.Enabled or filter.Mode == 'disabled' or hasAce(source, Config.Security.FilterBypassAce) then
        return true
    end

    local lower = text:lower()
    for _, word in ipairs(filter.BlacklistedWords or {}) do
        word = tostring(word):lower()
        if word ~= '' and lower:find(word, 1, true) then
            return false, 'blocked_word'
        end
    end

    if not urlAllowed(text) then return false, 'blocked_url' end

    local mentions = 0
    for _ in text:gmatch('@[%w_%-]+') do mentions = mentions + 1 end
    if mentions > math.max(0, tonumber(filter.MaxMentions) or 5) then
        return false, 'too_many_mentions'
    end

    return true
end

local function moderate(source, rawMessage, maxLength, rateKey, cooldown)
    local muted, remaining, reason = checkMuted(source)
    if muted then
        notify(source, 'muted_reason', { seconds = remaining, reason = reason or 'moderation' })
        return nil
    end

    local text, sanitizeReason = DexChat.Sanitize(rawMessage, maxLength)
    if not text then
        addViolation(source, sanitizeReason)
        notify(source, sanitizeReason == 'too_many_bytes' and 'message_too_long' or 'empty_message')
        return nil
    end

    if checkBurst(source) then
        notify(source, 'spam_detected')
        return nil
    end

    local limited, cooldownRemaining = checkCooldown(source, rateKey, cooldown)
    if limited then
        notify(source, 'cooldown', { seconds = cooldownRemaining })
        return nil
    end

    if checkDuplicate(source, text) then
        notify(source, 'duplicate_message')
        return nil
    end

    local allowed, filterReason = passesFilter(source, text)
    if not allowed then
        addViolation(source, filterReason)
        notify(source, filterReason)
        return nil
    end

    return text
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
        if target and (not Config.Routing.Enabled or not Config.Routing.BucketIsolation or GetPlayerRoutingBucket(target) == sourceBucket) then
            local targetPed = GetPlayerPed(target)
            if targetPed ~= 0 and #(sourceCoords - GetEntityCoords(targetPed)) <= distance then
                recipients[#recipients + 1] = target
            end
        end
    end

    return recipients
end

local function getOrganizationPlayers(source, organizationType, organizationName)
    local recipients = {}
    local sourceBucket = source > 0 and GetPlayerRoutingBucket(source) or nil

    for _, player in ipairs(GetPlayers()) do
        local target = tonumber(player)
        if target and (not Config.Routing.Enabled or not Config.Routing.BucketIsolation or not sourceBucket or GetPlayerRoutingBucket(target) == sourceBucket) then
            local membership = organizationType == 'gang' and Bridge.GetGang(target) or Bridge.GetJob(target)
            if membership.name == organizationName then recipients[#recipients + 1] = target end
        end
    end

    return recipients
end

local function getStaffPlayers(permission)
    local recipients = {}
    for _, player in ipairs(GetPlayers()) do
        local target = tonumber(player)
        if target and hasAce(target, permission or Config.Security.StaffAce) then
            recipients[#recipients + 1] = target
        end
    end
    return recipients
end

local function resolveRecipients(source, scope, options)
    options = options or {}
    if scope == DexChat.Scope.GLOBAL or scope == 'global' then return -1 end

    if scope == DexChat.Scope.DIRECT or scope == 'direct' then
        return options.targets or {}
    end

    if scope == DexChat.Scope.STAFF or scope == 'staff' then
        return getStaffPlayers(options.permission)
    end

    if scope == DexChat.Scope.ORGANIZATION or scope == 'organization' then
        return getOrganizationPlayers(source, options.organizationType, options.organizationName)
    end

    if scope == DexChat.Scope.PROXIMITY or scope == 'proximity' then
        return source > 0 and getPlayersInProximity(source, options.distance or Config.Proximity.Distance) or -1
    end

    if source > 0 and Config.Routing.Enabled and Config.Routing.BucketIsolation then
        return getPlayersInBucket(GetPlayerRoutingBucket(source))
    end

    return -1
end

local function emitMessage(targets, payload)
    if type(targets) == 'table' then
        for _, target in ipairs(targets) do
            TriggerClientEvent('dex_chat:addMessage', target, payload)
        end
    else
        TriggerClientEvent('dex_chat:addMessage', targets, payload)
    end
end

local function emitEvent(eventName, targets, ...)
    if type(targets) == 'table' then
        for _, target in ipairs(targets) do TriggerClientEvent(eventName, target, ...) end
    else
        TriggerClientEvent(eventName, targets, ...)
    end
end

local function buildPresentation(themeId, overrides)
    local presentation = DexChat.CopyTable(Config.MessageThemes[themeId] or Config.MessageThemes.normal or {})
    presentation.themeId = themeId or 'normal'
    for key, value in pairs(overrides or {}) do presentation[key] = value end
    return presentation
end

local function canonicalMessage(kind, source, text, extra)
    local payload = {
        schema = DexChat.MessageSchema,
        id = nextMessageId(),
        kind = kind,
        text = text,
        timestamp = now(),
        duration = Config.Messages.DefaultDuration,
        critical = false,
        sender = {
            serverId = source,
            name = source > 0 and Bridge.GetCharacterName(source) or 'Console'
        },
        presentation = buildPresentation('normal')
    }

    for key, value in pairs(extra or {}) do payload[key] = value end
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
        setSeObject = function(seObject) context.targets = getStaffPlayers(seObject) end
    }

    for _, hook in ipairs(hooks) do
        local ok, errorMessage = pcall(hook.callback, source, payload, hookReference)
        if not ok then
            print(('[dex_chat] Message hook failed (%s): %s'):format(hook.resource, errorMessage))
        end
    end

    return canceled
end

local function commandAvailable(command, owner)
    command = DexChat.NormalizeCommand(command)
    if not command then return nil end
    if Config.Security.ReservedCommands[command] then
        print(('[dex_chat] Ignored reserved command /%s from %s'):format(command, owner))
        return nil
    end
    if registeredCommands[command] then
        print(('[dex_chat] Ignored duplicate command /%s from %s; owned by %s'):format(command, owner, registeredCommands[command]))
        return nil
    end
    registeredCommands[command] = owner
    return command
end

local function compileChannels()
    for key, channel in pairs(Config.Channels or {}) do
        if channel.enabled ~= false then
            local compiled = DexChat.CopyTable(channel)
            compiled.key = key
            compiled.kind = compiled.kind or DexChat.MessageKind.CHAT
            compiled.scope = compiled.scope or Config.Routing.DefaultScope
            compiled.maxLength = tonumber(compiled.maxLength) or Config.Input.MaxLength
            compiled.cooldown = tonumber(compiled.cooldown) or 1
            compiled.theme = Config.MessageThemes[compiled.theme] and compiled.theme or 'normal'

            if key == 'normal' then
                compiledChannels[key] = compiled
            else
                local command = commandAvailable(compiled.command, 'channel:' .. key)
                if command then
                    compiled.command = command
                    compiled.commands = { command }
                    for _, alias in ipairs(compiled.aliases or {}) do
                        local validAlias = commandAvailable(alias, 'channel:' .. key)
                        if validAlias then compiled.commands[#compiled.commands + 1] = validAlias end
                    end
                    compiledChannels[key] = compiled
                end
            end
        end
    end
end

local function compileOrganizations()
    for name, organization in pairs(Config.Organizations or {}) do
        if organization.enabled then
            local compiled = DexChat.CopyTable(organization)
            compiled.name = tostring(name):lower()
            local command = commandAvailable(compiled.command, 'organization:' .. name)

            if (compiled.type == 'job' or compiled.type == 'gang') and command then
                compiled.command = command
                compiled.commands = { command }
                for _, alias in ipairs(compiled.aliases or {}) do
                    local validAlias = commandAvailable(alias, 'organization:' .. name)
                    if validAlias then compiled.commands[#compiled.commands + 1] = validAlias end
                end
                compiledOrganizations[compiled.name] = compiled
            else
                print(('[dex_chat] Disabled invalid organization %s'):format(name))
            end
        end
    end
end

compileChannels()
compileOrganizations()

local function authorizeDynamicOrganization(source, channel)
    local membership = channel.organizationType == 'gang' and Bridge.GetGang(source) or Bridge.GetJob(source)
    if not membership or membership.name == 'none' then return nil, 'organization_unavailable' end
    if channel.requireDuty and not membership.onDuty then return nil, 'duty_required' end
    return membership
end

local function authorizeOrganization(source, organization)
    local player = Bridge.GetPlayer(source)
    if not player then return false, 'unavailable' end

    local membership = organization.type == 'gang' and player.gang or player.job
    if not membership or membership.name ~= organization.name then
        return false, 'not_member', { organization = organization.label }
    end

    local authorization = organization.authorization or {}
    local grade = tonumber(membership.grade) or 0
    if authorization.allowedGrades and not DexChat.TableContains(authorization.allowedGrades, grade) then return false, 'grade_denied' end
    if grade < (tonumber(authorization.minimumGrade) or 0) then return false, 'grade_denied' end
    if authorization.bossOnly and not membership.isBoss then return false, 'grade_denied' end
    if authorization.requireDuty and not membership.onDuty then return false, 'duty_required' end

    return true, player, membership
end

local function routeChannel(source, channel, rawMessage)
    if source <= 0 then return end
    if channel.permission and not hasAce(source, channel.permission) then return notify(source, 'no_permission') end

    local membership
    if channel.scope == 'organization' then
        local reason
        membership, reason = authorizeDynamicOrganization(source, channel)
        if not membership then return notify(source, reason) end
    end

    if channel.allowedJobs then
        local job = Bridge.GetJob(source)
        if not DexChat.TableContains(channel.allowedJobs, job.name) then return notify(source, 'job_denied') end
    end

    local text = moderate(source, rawMessage, channel.maxLength, 'channel:' .. channel.key, channel.cooldown)
    if not text then return end

    local playerName = Bridge.GetCharacterName(source)
    local theme = channel.theme
    local formatted = DexChat.ApplyTemplate(channel.format or '{message}', {
        name = playerName,
        message = text
    })

    local randomResult
    if channel.randomResult then
        randomResult = math.random(1, 2) == 1
        theme = randomResult and 'success' or 'failure'
        formatted = ('%s — %s'):format(formatted, DexChat.Locale(randomResult and 'try_success' or 'try_failure'))
    end

    local options = {
        distance = channel.distance,
        permission = channel.permission,
        organizationType = channel.organizationType,
        organizationName = membership and membership.name
    }
    local targets = resolveRecipients(source, channel.scope, options)
    local payload = canonicalMessage(channel.kind, source, formatted, {
        channel = channel.label,
        scope = channel.scope,
        critical = channel.critical == true,
        organization = membership and {
            type = channel.organizationType,
            name = membership.name,
            label = membership.label,
            gradeLabel = membership.gradeLabel
        } or nil,
        sender = {
            serverId = source,
            name = playerName,
            gradeLabel = membership and membership.gradeLabel or nil
        },
        args = { playerName, formatted },
        presentation = buildPresentation(theme, { variant = channel.kind })
    })

    local context = { targets = targets }
    if runHooks(source, payload, context) then return end

    TriggerEvent('chatMessage', source, playerName, formatted)
    if WasEventCanceled() then return end

    if (tonumber(channel.price) or 0) > 0 then
        if not Bridge.RemoveMoney(source, channel.price, 'chat advertisement') then
            return notify(source, 'insufficient_money', { amount = channel.price })
        end
    end

    emitMessage(context.targets, payload)
    if channel.show3D then
        emitEvent('dex_chat:show3D', context.targets, source, formatted, theme, 7000)
    end
    logMessage(channel.kind, source, formatted, { channel = channel.label })
end

local function handleOrganizationCommand(source, args, organization)
    if source <= 0 then return end
    local authorized, playerOrReason, membershipOrValues = authorizeOrganization(source, organization)
    if not authorized then return notify(source, playerOrReason, membershipOrValues) end

    local player = playerOrReason
    local membership = membershipOrValues
    local settings = organization.message or {}
    local text = moderate(
        source,
        table.concat(args, ' '),
        settings.maxLength or Config.Input.MaxLength,
        'organization:' .. organization.name,
        settings.cooldown or 15
    )
    if not text then return end

    local globalExpires = organizationCooldowns[organization.name] or 0
    if globalExpires > nowMs() and not hasAce(source, Config.Security.CooldownBypassAce) then
        return notify(source, 'cooldown', { seconds = math.ceil((globalExpires - nowMs()) / 1000) })
    end

    local globalCooldown = math.max(0, tonumber(settings.globalCooldown) or 0)
    local senderName = settings.anonymous and DexChat.Locale('anonymous_member') or player.characterName
    local banner = organization.banner or {}
    local targets = resolveRecipients(source, settings.scope or 'bucket', {
        organizationType = organization.type,
        organizationName = organization.name,
        distance = settings.distance
    })

    local payload = canonicalMessage(DexChat.MessageKind.ORGANIZATION, source, text, {
        duration = banner.duration or Config.Messages.DefaultDuration,
        channel = organization.shortLabel or organization.label,
        scope = settings.scope or 'bucket',
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
        presentation = buildPresentation('organization', {
            variant = 'banner',
            title = banner.title or organization.label,
            logo = banner.logo or '',
            layout = banner.layout or 'expanded',
            primary = banner.primary or '#2563EB',
            secondary = banner.secondary or '#0F172A',
            border = banner.border or '#60A5FA',
            text = banner.text or '#FFFFFF'
        })
    })

    local context = { targets = targets }
    if runHooks(source, payload, context) then return end

    organizationCooldowns[organization.name] = nowMs() + globalCooldown * 1000
    emitMessage(context.targets, payload)
    logMessage('organization', source, text, { title = organization.label, channel = organization.name })
end

for _, channel in pairs(compiledChannels) do
    if channel.commands then
        local current = channel
        for _, command in ipairs(current.commands) do
            RegisterCommand(command, function(source, args)
                routeChannel(source, current, table.concat(args, ' '))
            end, false)
        end
    end
end

for _, organization in pairs(compiledOrganizations) do
    local current = organization
    for _, command in ipairs(current.commands) do
        RegisterCommand(command, function(source, args)
            handleOrganizationCommand(source, args, current)
        end, false)
    end
end

local function canPrivateMessage(source, target)
    if not GetPlayerName(target) then return false, 'player_not_found' end
    if source == target and not Config.PrivateMessages.AllowSelf then return false, 'cannot_message_self' end
    if Config.PrivateMessages.SameBucketOnly and Config.Routing.Enabled and GetPlayerRoutingBucket(source) ~= GetPlayerRoutingBucket(target) then
        return false, 'different_instance'
    end
    return true
end

local function sendPrivateMessage(source, target, rawMessage)
    local allowed, reason = canPrivateMessage(source, target)
    if not allowed then return notify(source, reason) end

    local text = moderate(
        source,
        rawMessage,
        Config.PrivateMessages.MaxLength,
        'private',
        Config.PrivateMessages.Cooldown
    )
    if not text then return end

    local senderName = Bridge.GetCharacterName(source)
    local targetName = Bridge.GetCharacterName(target)
    local base = {
        kind = DexChat.MessageKind.PRIVATE,
        scope = DexChat.Scope.DIRECT,
        critical = false,
        presentation = buildPresentation(Config.PrivateMessages.Theme or 'private', { variant = 'private' })
    }

    local receiverPayload = canonicalMessage(base.kind, source, text, {
        channel = ('PM FROM %s'):format(senderName),
        scope = base.scope,
        sender = { serverId = source, name = senderName },
        presentation = base.presentation
    })
    local senderPayload = canonicalMessage(base.kind, source, text, {
        channel = ('PM TO %s'):format(targetName),
        scope = base.scope,
        sender = { serverId = source, name = senderName },
        presentation = base.presentation
    })

    lastPrivatePeer[source] = target
    lastPrivatePeer[target] = source
    emitMessage(target, receiverPayload)
    emitMessage(source, senderPayload)
    logMessage('private', source, Config.PrivateMessages.LogContent and text or '[content hidden]', { target = target })
end

if Config.PrivateMessages.Enabled then
    local privateCommands = { Config.PrivateMessages.Command }
    for _, alias in ipairs(Config.PrivateMessages.Aliases or {}) do privateCommands[#privateCommands + 1] = alias end
    for _, commandName in ipairs(privateCommands) do
        local command = commandAvailable(commandName, 'private')
        if command then
            RegisterCommand(command, function(source, args)
                local target = tonumber(args[1])
                if not target then return notify(source, 'pm_usage', { command = command }) end
                table.remove(args, 1)
                sendPrivateMessage(source, target, table.concat(args, ' '))
            end, false)
        end
    end

    local replyCommands = { Config.PrivateMessages.ReplyCommand }
    for _, alias in ipairs(Config.PrivateMessages.ReplyAliases or {}) do replyCommands[#replyCommands + 1] = alias end
    for _, commandName in ipairs(replyCommands) do
        local command = commandAvailable(commandName, 'private-reply')
        if command then
            RegisterCommand(command, function(source, args)
                local target = lastPrivatePeer[source]
                if not target then return notify(source, 'no_reply_target') end
                sendPrivateMessage(source, target, table.concat(args, ' '))
            end, false)
        end
    end
end

RegisterCommand('clear', function(source)
    if source > 0 then TriggerClientEvent('chat:clear', source) end
end, false)

RegisterCommand('clearall', function(source)
    if source == 0 or hasAce(source, Config.Security.ClearAllAce) or hasAce(source, Config.Security.StaffAce) then
        TriggerClientEvent('chat:clear', -1)
        logMessage('moderation', source, 'Cleared chat for all players')
    else
        notify(source, 'no_permission')
    end
end, false)

RegisterCommand('chatmute', function(source, args)
    if source ~= 0 and not hasAce(source, Config.Security.MuteAce) and not hasAce(source, Config.Security.StaffAce) then
        return notify(source, 'no_permission')
    end

    local target = tonumber(args[1])
    if not target or not GetPlayerName(target) then return notify(source, 'mute_usage') end
    local minutes = DexChat.Clamp(args[2] or Config.Security.StaffMute.DefaultMinutes, 1, Config.Security.StaffMute.MaxMinutes)
    local reason = table.concat(args, ' ', 3)
    if reason == '' then reason = 'Muted by staff' end

    local state = stateFor(target)
    state.staffMutedUntil = now() + math.floor(minutes * 60)
    state.muteReason = reason
    notify(target, 'muted_by_staff', { minutes = minutes, reason = reason })
    if source > 0 then notify(source, 'mute_applied', { player = target, minutes = minutes }) end
    logMessage('moderation', source, ('Muted %s for %s minute(s): %s'):format(target, minutes, reason), { target = target })
end, false)

RegisterCommand('chatunmute', function(source, args)
    if source ~= 0 and not hasAce(source, Config.Security.MuteAce) and not hasAce(source, Config.Security.StaffAce) then
        return notify(source, 'no_permission')
    end

    local target = tonumber(args[1])
    if not target or not GetPlayerName(target) then return notify(source, 'unmute_usage') end
    local state = stateFor(target)
    state.staffMutedUntil = 0
    state.temporaryMutedUntil = 0
    state.muteReason = nil
    notify(target, 'unmuted_by_staff')
    if source > 0 then notify(source, 'unmute_applied', { player = target }) end
    logMessage('moderation', source, ('Unmuted %s'):format(target), { target = target })
end, false)

RegisterCommand('say', function(source, args, rawCommand)
    local text = rawCommand:sub(5)
    if source == 0 then
        local sanitized = DexChat.Sanitize(text, Config.Input.MaxLength)
        if sanitized then
            emitMessage(-1, canonicalMessage(DexChat.MessageKind.SYSTEM, 0, sanitized, {
                channel = 'SERVER',
                critical = true,
                presentation = buildPresentation('system', { variant = 'system' })
            }))
            logMessage('system', 0, sanitized)
        end
    else
        routeChannel(source, compiledChannels.normal or Config.NormalChat, text)
    end
end, false)

local function routeRegisteredMode(source, message, modeName)
    local mode = modes[modeName]
    if not mode then return false end
    if mode.seObject and not hasAce(source, mode.seObject) then
        notify(source, 'no_permission')
        return true
    end

    local text = moderate(source, message, Config.Input.MaxLength, 'mode:' .. modeName, 1)
    if not text then return true end

    local payload = canonicalMessage(DexChat.MessageKind.CHAT, source, text, {
        mode = modeName,
        channel = mode.displayName,
        presentation = buildPresentation('normal', { variant = 'normal', accent = mode.color })
    })
    local context = { targets = resolveRecipients(source, Config.Routing.DefaultScope) }
    local callbacks = {
        updateMessage = function(changes) for key, value in pairs(changes or {}) do payload[key] = value end end,
        cancel = function() context.canceled = true end,
        setRouting = function(targets) context.targets = targets end,
        setSeObject = function(seObject) context.targets = getStaffPlayers(seObject) end
    }

    local ok, errorMessage = pcall(mode.callback, source, payload, callbacks)
    if not ok then
        print(('[dex_chat] Mode callback failed (%s): %s'):format(mode.resource, errorMessage))
        return true
    end
    if not context.canceled and not runHooks(source, payload, context) then emitMessage(context.targets, payload) end
    return true
end

RegisterNetEvent('_chat:messageEntered', function(_, _, message, mode)
    local playerSource = source
    if mode and routeRegisteredMode(playerSource, message, mode) then return end
    local channel = compiledChannels.normal
    if channel then routeChannel(playerSource, channel, message) end
end)

RegisterNetEvent('dex_chat:setTyping', function(value)
    local playerSource = source
    if not Config.TypingIndicator.Enabled or type(value) ~= 'boolean' then return end
    if typingStates[playerSource] == value then return end
    typingStates[playerSource] = value

    local recipients = getPlayersInProximity(playerSource, Config.Proximity.TypingIndicatorDistance)
    emitEvent('dex_chat:setTyping', recipients, playerSource, value)
end)

RegisterNetEvent('chat:init', function()
    local playerSource = source
    local suggestions = {}

    for name, mode in pairs(modes) do
        if not mode.seObject or hasAce(playerSource, mode.seObject) then
            TriggerClientEvent('chat:addMode', playerSource, {
                name = name,
                displayName = mode.displayName,
                color = mode.color,
                isChannel = mode.isChannel,
                isGlobal = mode.isGlobal
            })
        end
    end

    for _, channel in pairs(compiledChannels) do
        if channel.command and (not channel.permission or hasAce(playerSource, channel.permission)) then
            suggestions[#suggestions + 1] = {
                name = '/' .. channel.command,
                help = channel.label,
                params = {{ name = 'message', help = DexChat.Locale('suggestion_message') }}
            }
        end
    end

    local player = Bridge.GetPlayer(playerSource)
    for _, organization in pairs(compiledOrganizations) do
        local membership = player and (organization.type == 'gang' and player.gang or player.job)
        if membership and membership.name == organization.name then
            suggestions[#suggestions + 1] = {
                name = '/' .. organization.command,
                help = organization.label,
                params = {{ name = 'message', help = DexChat.Locale('suggestion_announcement') }}
            }
        end
    end

    if Config.PrivateMessages.Enabled then
        suggestions[#suggestions + 1] = {
            name = '/' .. Config.PrivateMessages.Command,
            help = DexChat.Locale('suggestion_private'),
            params = {
                { name = 'id', help = DexChat.Locale('suggestion_player_id') },
                { name = 'message', help = DexChat.Locale('suggestion_message') }
            }
        }
        suggestions[#suggestions + 1] = {
            name = '/' .. Config.PrivateMessages.ReplyCommand,
            help = DexChat.Locale('suggestion_reply'),
            params = {{ name = 'message', help = DexChat.Locale('suggestion_message') }}
        }
    end

    TriggerClientEvent('chat:addSuggestions', playerSource, suggestions)
    TriggerClientEvent('dex_chat:setPermissions', playerSource, {
        staff = hasAce(playerSource, Config.Security.StaffAce),
        showPlayerIds = Config.Messages.ShowPlayerIds == true or (Config.Messages.ShowPlayerIdsToStaff and hasAce(playerSource, Config.Security.StaffAce))
    })
end)

RegisterNetEvent('__cfx_internal:commandFallback', function(command)
    local playerSource = source
    if playerSource > 0 and compiledChannels.normal then
        routeChannel(playerSource, compiledChannels.normal, '/' .. command)
        CancelEvent()
    end
end)

RegisterNetEvent('playerJoining', function()
    if not Config.Messages.ShowJoinQuit or GetConvarInt('chat_showJoins', 1) == 0 then return end
    local playerSource = source
    local payload = canonicalMessage(DexChat.MessageKind.SYSTEM, 0, DexChat.Locale('player_joined', {
        player = GetPlayerName(playerSource) or 'A player'
    }), {
        channel = 'SERVER',
        presentation = buildPresentation('system', { variant = 'system' })
    })
    emitMessage(resolveRecipients(playerSource, 'bucket'), payload)
end)

AddEventHandler('playerDropped', function(reason)
    local playerSource = source
    local playerName = GetPlayerName(playerSource) or ('Player %s'):format(playerSource)
    local bucket = GetPlayerRoutingBucket(playerSource)

    if typingStates[playerSource] then
        emitEvent('dex_chat:setTyping', Config.Routing.Enabled and Config.Routing.BucketIsolation and getPlayersInBucket(bucket) or -1, playerSource, false)
    end

    playerStates[playerSource] = nil
    lastPrivatePeer[playerSource] = nil
    typingStates[playerSource] = nil
    for sender, peer in pairs(lastPrivatePeer) do
        if peer == playerSource then lastPrivatePeer[sender] = nil end
    end

    if not Config.Messages.ShowJoinQuit or GetConvarInt('chat_showQuits', 1) == 0 then return end
    local payload = canonicalMessage(DexChat.MessageKind.SYSTEM, 0, DexChat.Locale('player_left', { player = playerName }), {
        channel = 'SERVER',
        presentation = buildPresentation('system', { variant = 'system' })
    })
    emitMessage(Config.Routing.Enabled and Config.Routing.BucketIsolation and getPlayersInBucket(bucket) or -1, payload)
    if Config.Debug then print(('[dex_chat] %s dropped: %s'):format(playerName, reason or 'unknown')) end
end)

RegisterNetEvent('chat:addMessage', function(target, message)
    if source ~= 0 then return end
    if message == nil then message, target = target, -1 end
    TriggerClientEvent('chat:addMessage', target or -1, message)
end)

exports('addMessage', function(target, message)
    if message == nil then message, target = target, -1 end
    if not message then return false end
    TriggerClientEvent('chat:addMessage', target or -1, message)
    return true
end)

exports('registerMessageHook', function(callback)
    if type(callback) ~= 'function' then return false end
    hooks[#hooks + 1] = { resource = GetInvokingResource() or 'unknown', callback = callback }
    return true
end)

exports('registerMode', function(modeData)
    if type(modeData) ~= 'table' or not modeData.name or not modeData.displayName or type(modeData.cb) ~= 'function' then
        return false
    end

    local name = tostring(modeData.name)
    modes[name] = {
        displayName = tostring(modeData.displayName),
        color = modeData.color or '#FFFFFF',
        callback = modeData.cb,
        resource = GetInvokingResource() or 'unknown',
        seObject = modeData.seObject,
        isChannel = modeData.isChannel,
        isGlobal = modeData.isGlobal
    }

    local payload = {
        name = name,
        displayName = modes[name].displayName,
        color = modes[name].color,
        isChannel = modes[name].isChannel,
        isGlobal = modes[name].isGlobal
    }

    if modeData.seObject then
        emitEvent('chat:addMode', getStaffPlayers(modeData.seObject), payload)
    else
        TriggerClientEvent('chat:addMode', -1, payload)
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

if Config.AutoMessages.Enabled and #(Config.AutoMessages.Messages or {}) > 0 then
    CreateThread(function()
        local index = 0
        local interval = math.max(1, tonumber(Config.AutoMessages.IntervalMinutes) or 15) * 60000
        while true do
            Wait(interval)
            index = (index % #Config.AutoMessages.Messages) + 1
            local text = DexChat.Sanitize(Config.AutoMessages.Messages[index], Config.Input.MaxLength)
            if text then
                emitMessage(resolveRecipients(0, Config.AutoMessages.Scope), canonicalMessage(DexChat.MessageKind.SYSTEM, 0, text, {
                    channel = 'SERVER',
                    critical = true,
                    presentation = buildPresentation('system', { variant = 'system' })
                }))
            end
        end
    end)
end

print(('[dex_chat] Ready v%s: %d channels, %d organizations, framework=%s, bucketIsolation=%s'):format(
    DexChat.Version,
    DexChat.CountTable(compiledChannels),
    DexChat.CountTable(compiledOrganizations),
    Bridge.GetFramework(),
    tostring(Config.Routing.Enabled and Config.Routing.BucketIsolation)
))
