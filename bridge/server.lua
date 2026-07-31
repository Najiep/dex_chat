Bridge = Bridge or {}

local framework = 'standalone'
local ESX
local QBCore

local function resourceStarted(name)
    return GetResourceState(name) == 'started'
end

local function detectFramework()
    if Config.Framework ~= 'auto' then
        return Config.Framework
    end

    for _, name in ipairs(Config.FrameworkOptions.DetectionPriority or {}) do
        if name == 'esx' and resourceStarted('es_extended') then return 'esx' end
        if name == 'qbox' and resourceStarted('qbx_core') then return 'qbox' end
        if name == 'qbcore' and resourceStarted('qb-core') then return 'qbcore' end
    end

    return 'standalone'
end

local function normalizeGrade(grade)
    if type(grade) == 'number' then
        return grade, tostring(grade), false
    end

    if type(grade) ~= 'table' then
        return 0, '0', false
    end

    local level = tonumber(grade.level or grade.grade or grade.id) or 0
    local label = grade.name or grade.label or tostring(level)
    local boss = grade.isboss == true or grade.isBoss == true
    return level, tostring(label), boss
end

local function normalizeOrganization(data, fallbackDuty)
    if type(data) ~= 'table' or not data.name then
        return { name = 'none', label = 'None', grade = 0, gradeLabel = '0', onDuty = false, isBoss = false }
    end

    local grade, gradeLabel, isBoss = normalizeGrade(data.grade)

    return {
        name = tostring(data.name):lower(),
        label = tostring(data.label or data.name),
        grade = grade,
        gradeLabel = gradeLabel,
        onDuty = data.onduty == true or data.onDuty == true or fallbackDuty == true,
        isBoss = isBoss or data.isboss == true or data.isBoss == true
    }
end

local function initialize()
    framework = detectFramework()

    if framework == 'esx' then
        local ok, core = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok then ESX = core else framework = 'standalone' end
    elseif framework == 'qbcore' then
        local ok, core = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok then QBCore = core else framework = 'standalone' end
    elseif framework == 'qbox' and not resourceStarted('qbx_core') then
        framework = 'standalone'
    end

    print(('[dex_chat] Framework bridge: %s'):format(framework))
end

initialize()

function Bridge.GetFramework()
    return framework
end

function Bridge.GetIdentifier(source)
    if framework == 'esx' and ESX then
        local player = ESX.GetPlayerFromId(source)
        return player and (player.identifier or (player.getIdentifier and player.getIdentifier())) or nil
    end

    local identifiers = GetPlayerIdentifiers(source)
    return identifiers and identifiers[1] or nil
end

function Bridge.GetCharacterName(source)
    if framework == 'esx' and ESX then
        local player = ESX.GetPlayerFromId(source)
        if player then
            if player.getName then
                local ok, name = pcall(player.getName, player)
                if ok and name and name ~= '' then return name end
            end
            if player.name and player.name ~= '' then return player.name end
        end
    elseif framework == 'qbox' then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
        local data = ok and player and player.PlayerData
        local charinfo = data and data.charinfo
        if charinfo then
            return (('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):match('^%s*(.-)%s*$')
        end
    elseif framework == 'qbcore' and QBCore then
        local player = QBCore.Functions.GetPlayer(source)
        local charinfo = player and player.PlayerData and player.PlayerData.charinfo
        if charinfo then
            return (('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):match('^%s*(.-)%s*$')
        end
    end

    return GetPlayerName(source) or ('Player %s'):format(source)
end

function Bridge.GetJob(source)
    if framework == 'esx' and ESX then
        local player = ESX.GetPlayerFromId(source)
        return normalizeOrganization(player and (player.getJob and player.getJob() or player.job), true)
    elseif framework == 'qbox' then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
        return normalizeOrganization(ok and player and player.PlayerData and player.PlayerData.job)
    elseif framework == 'qbcore' and QBCore then
        local player = QBCore.Functions.GetPlayer(source)
        return normalizeOrganization(player and player.PlayerData and player.PlayerData.job)
    end

    return normalizeOrganization(nil)
end

function Bridge.GetGang(source)
    if framework == 'esx' and ESX then
        local player = ESX.GetPlayerFromId(source)
        if not player then return normalizeOrganization(nil) end

        local provider = Config.FrameworkOptions.ESX.GangProvider or {}
        local mode = provider.Mode or 'disabled'
        local gang

        if mode == 'job' then
            gang = player.getJob and player.getJob() or player.job
        elseif mode == 'job2' then
            if player.get then
                local ok, value = pcall(player.get, player, 'job2')
                if ok then gang = value end
            end
            gang = gang or player.job2
        elseif mode == 'metadata' and player.getMeta then
            local ok, value = pcall(player.getMeta, player, provider.MetadataKey or 'gang')
            if ok then gang = value end
        elseif mode == 'export' and provider.Resource ~= '' and provider.Export ~= '' then
            local ok, value = pcall(function()
                return exports[provider.Resource][provider.Export](source)
            end)
            if ok then gang = value end
        end

        return normalizeOrganization(gang)
    elseif framework == 'qbox' then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
        return normalizeOrganization(ok and player and player.PlayerData and player.PlayerData.gang)
    elseif framework == 'qbcore' and QBCore then
        local player = QBCore.Functions.GetPlayer(source)
        return normalizeOrganization(player and player.PlayerData and player.PlayerData.gang)
    end

    return normalizeOrganization(nil)
end

function Bridge.GetPlayer(source)
    if not GetPlayerName(source) then return nil end

    return {
        source = source,
        identifier = Bridge.GetIdentifier(source),
        characterName = Bridge.GetCharacterName(source),
        job = Bridge.GetJob(source),
        gang = Bridge.GetGang(source)
    }
end

function Bridge.Notify(source, message, messageType)
    TriggerClientEvent('dex_chat:notify', source, {
        message = message,
        type = messageType or 'inform'
    })
end
