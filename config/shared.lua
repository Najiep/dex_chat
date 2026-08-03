Config = Config or {}

Config.Framework = 'auto' -- auto | esx | qbox | qbcore | standalone
Config.Locale = 'en' -- en | tl
Config.Debug = false

Config.Input = {
    DefaultKey = 'T',
    MaxLength = 250,
    HistoryLimit = 50
}

Config.Messages = {
    ClientHistoryLimit = 150,
    DefaultDuration = 10000,
    ShowTimestamps = true,
    ShowJoinQuit = true
}

Config.Routing = {
    BucketIsolation = true,
    DefaultScope = 'bucket' -- global | bucket
}

Config.NormalChat = {
    Enabled = true,
    Scope = 'bucket',
    Cooldown = 1,
    MaxLength = 250,
    Label = 'LOCAL'
}

Config.OOC = {
    Enabled = true,
    Command = 'ooc',
    Scope = 'bucket',
    Cooldown = 3,
    MaxLength = 250,
    Label = 'OOC'
}

Config.Proximity = {
    Enabled = true,
    Distance = 20.0
}

Config.FrameworkOptions = {
    DetectionPriority = { 'esx', 'qbox', 'qbcore' },

    ESX = {
        -- disabled | job | job2 | metadata | export
        GangProvider = {
            Mode = 'job2',
            MetadataKey = 'gang',
            Resource = '',
            Export = ''
        }
    }
}
