-- Keeps the NUI settings button decoupled from client/main.lua internals.
RegisterNUICallback('openSettings', function(_, callback)
    ExecuteCommand(Config.Input.OpenSettingsCommand)
    callback({ ok = true })
end)
