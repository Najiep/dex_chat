Config = Config or {}

Config.Framework = 'auto' -- auto | esx | qbox | qbcore | standalone
Config.Locale = 'en' -- en | tl
Config.Debug = false

Config.Input = {
    DefaultKey = 'T',
    MaxLength = 250,
    HistoryLimit = 50,
    OpenSettingsCommand = 'chatsettings',
    OpenSettingsKey = 'F7'
}

Config.UI = {
    Theme = 'midnight',
    Position = 'top-left', -- top-left | top-right | bottom-left | bottom-right
    Width = 560,
    MaxHeight = 430,
    Scale = 1.0,
    Opacity = 0.96,
    Blur = true,
    Compact = false,
    ReducedMotion = false,
    ShowChannelTabs = true,
    ShowCharacterCounter = true,
    ShowSettingsButton = true,
    KeepCriticalMessagesVisibleWhenHidden = true
}

Config.Messages = {
    ClientHistoryLimit = 200,
    DefaultDuration = 12000,
    ShowTimestamps = true,
    ShowJoinQuit = true,
    ShowPlayerIds = false,
    ShowPlayerIdsToStaff = true
}

Config.Routing = {
    Enabled = true,
    BucketIsolation = true,
    DefaultScope = 'bucket', -- global | bucket
    PrivateMessagesSameBucketOnly = true
}

Config.Proximity = {
    Enabled = true,
    Distance = 20.0,
    RoleplayDistance = 15.0,
    TypingIndicatorDistance = 20.0
}

Config.TypingIndicator = {
    Enabled = true,
    Text = '... ',
    Scale = 0.32,
    HeightOffset = 1.05
}

Config.AutoMessages = {
    Enabled = false,
    IntervalMinutes = 15,
    Scope = 'global',
    Messages = {
        'Welcome to the server. Please follow the community rules.'
    }
}

Config.FrameworkOptions = {
    DetectionPriority = { 'esx', 'qbox', 'qbcore' },

    ESX = {
        AssumeOnDutyWhenUnavailable = true,
        AdvertisementAccount = 'money',

        -- disabled | job | job2 | metadata | export
        GangProvider = {
            Mode = 'job2',
            MetadataKey = 'gang',
            Resource = '',
            Export = ''
        }
    },

    QBCore = {
        AdvertisementAccount = 'cash'
    },

    Qbox = {
        AdvertisementAccount = 'cash'
    }
}

-- Backward-compatible aliases used by older integrations.
Config.NormalChat = Config.NormalChat or {
    Enabled = true,
    Scope = 'bucket',
    Cooldown = 1,
    MaxLength = Config.Input.MaxLength,
    Label = 'LOCAL'
}

Config.OOC = Config.OOC or {
    Enabled = true,
    Command = 'ooc',
    Scope = 'bucket',
    Cooldown = 3,
    MaxLength = Config.Input.MaxLength,
    Label = 'OOC'
}
