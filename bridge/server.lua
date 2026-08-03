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

    local detected = {}
    for _, name in ipairs(Config.FrameworkOptions.DetectionPriority or {}) do
        if name == 'esx' and resourceStarted('es_extended') then detected[#detected + 1] = 'esx' end
        if name == 'qbox' and resourceStarted('qbx_core') then detected[#detected + 1] = 'qbox' end
        if name == 'qbcore' and resourceStarted('qb-core') then detected[#detected + 1] = 'qbcore' end
    end

    if #detected > 1 then
        print(('[dex_chat] Warning: multiple frameworks detected (%s). Using %s by priority.'):format(
            table.concat(detected, ', '), detected[1]
        ))
    end

    return detected[1] or 'standalone'
end

local function normalizeGrade(data)
    local gradeData = type(data.grade) == 'table' and data.grade or nil
    local level = tonumber(
        gradeData and (gradeData.level or gradeData.grade or gradeData.id)
        or data.grade
        or data.grade_level
    ) or 0
    local label = gradeData and (gradeData.name or gradeData.label)
        or data.grade_label
        or data.grade_name
        or tostring(level)
    local boss = gradeData and (gradeData.isboss == true or gradeData.isBoss == true)
        or data.isboss == true
        or data.isBoss == true
        or data.grade_name == 'boss'

    return level, tostring(label), boss == true
end

local function normalizeOrganization(data, fallbackDuty)
    if type(data) ~= 'table' or not data.name then
        return {
            name = 'none',
            label = 'None',
            grade = 0,
            gradeLabel = '0',
            onDuty = false,
            isBoss = false
        }
    end

    local grade, gradeLabel, isBoss = normalizeGrade(data)
    local duty = data.onduty
    if duty == nil then duty = data.onDuty end
    if duty == nil then duty = fallbackDuty end

    return {
        name = tostring(data.name):lower(),
        label = tostring(data.label or data.name),
        grade = grade,
        gradeLabel = gradeLabel,
        onDuty = duty == true,
        isBoss = isBoss
    }
end

local function initialize()
    framework = detectFramework()

    if framework == 'esx' then
        local ok, core = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and core then ESX = core else framework = 'standalone' end
    elseif framework == 'qbcore' then
        local ok, core = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok and core then QBCore = core else framework = 'standalone' end
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
        if player then
            if player.getIdentifier then
                local ok, identifier = pcall(player.getIdentifier, player)
                if ok and identifier then return identifier end
            end
            if player.identifier then return player.identifier end
        end
    elseif framework == 'qbox' then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
        local data = ok and player and player.PlayerData
        if data then return data.citizenid or data.license end
    elseif framework == 'qbcore' and QBCore then
        local player = QBCore.Functions.GetPlayer(source)
        local data = player and player.PlayerData
        if data then return data.citizenid or data.license end
    end

    local identifiers = GetPlayerIdentifiers(source)
    for _, identifier in ipairs(identifiers or {}) do
        if identifier:sub(1, 8) == 'license:' then return identifier end
    end
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
        local charinfo = ok and player and player.PlayerData and player.PlayerData.charinfo
        if charinfo then
            local name = ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')
            return name:match('^%s*(.-)%s*$')
        end
    elseif framework == 'qbcore' and QBCore then
        local player = QBCore.Functions.GetPlayer(source)
        local charinfo = player and player.PlayerData and player.PlayerData.charinfo
        if charinfo then
            local name = ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')
            return name:match('^%s*(.-)%s*$')
        end
    end

    return GetPlayerName(source) or ('Player %s'):format(source)
end

function Bridge.GetJob(source)
    if framework == 'esx' and ESX then
        local player = ESX.GetPlayerFromId(source)
        local job = player and (player.getJob and player.getJob() or player.job)
        local fallback = Config.FrameworkOptions.ESX.AssumeOnDutyWhenUnavailable == true
        return normalizeOrganization(job, fallback)
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

        return normalizeOrganization(gang, true)
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

function Bridge.RemoveMoney(source, amount, reason)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount == 0 then return true end

    if framework == 'esx' and ESX then
        local player = ESX.GetPlayerFromId(source)
        if not player then return false end
        local account = Config.FrameworkOptions.ESX.AdvertisementAccount or 'money'

        if account == 'money' and player.getMoney and player.removeMoney then
            if (tonumber(player.getMoney()) or 0) < amount then return false end
            player.removeMoney(amount, reason or 'dex_chat')
            return true
        end

        if player.getAccount and player.removeAccountMoney then
            local accountData = player.getAccount(account)
            if not accountData or (tonumber(accountData.money) or 0) < amount then return false end
            player.removeAccountMoney(account, amount, reason or 'dex_chat')
            return true
        end
    elseif framework == 'qbox' then
        local account = Config.FrameworkOptions.Qbox.AdvertisementAccount or 'cash'
        local ok, result = pcall(function()
            return exports.qbx_core:RemoveMoney(source, account, amount, reason or 'dex_chat')
        end)
        return ok and result ~= false
    elseif framework == 'qbcore' and QBCore then
        local player = QBCore.Functions.GetPlayer(source)
        local account = Config.FrameworkOptions.QBCore.AdvertisementAccount or 'cash'
        if not player or not player.Functions then return false end
        local balance = player.PlayerData and player.PlayerData.money and player.PlayerData.money[account] or 0
        if (tonumber(balance) or 0) < amount then return false end
        return player.Functions.RemoveMoney(account, amount, reason or 'dex_chat') ~= false
    end

    return framework == 'standalone'
end

function Bridge.Notify(source, message, messageType)
    TriggerClientEvent('dex_chat:notify', source, {
        message = message,
        type = messageType or 'inform'
    })
end
