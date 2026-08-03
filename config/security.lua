Config.Security = {
    ReservedCommands = {
        say = true,
        quit = true,
        connect = true,
        ensure = true,
        start = true,
        stop = true,
        restart = true,
        refresh = true,
        exec = true,
        rcon = true,
        clear = true,
        clearall = true,
        chatmute = true,
        chatunmute = true,
        togglechat = true,
        chatsettings = true,
        dexchat_open = true
    },

    MaxRawBytes = 1024,
    CollapseWhitespace = true,

    CooldownBypassAce = 'dex_chat.cooldown.bypass',
    FilterBypassAce = 'dex_chat.filter.bypass',
    StaffAce = 'dex_chat.staff',
    ClearAllAce = 'dex_chat.clearall',
    MuteAce = 'dex_chat.mute',
    CrossBucketAce = 'dex_chat.crossbucket',
    AnnouncementAce = 'dex_chat.announcement',

    Burst = {
        Enabled = true,
        MaxMessages = 6,
        WindowSeconds = 10
    },

    Duplicate = {
        Enabled = true,
        WindowSeconds = 8
    },

    Filter = {
        Enabled = true,
        Mode = 'block', -- block | disabled
        BlacklistedWords = {},
        BlockUrls = false,
        AllowedDomains = {},
        MaxMentions = 5
    },

    -- Optional escalating mute after repeated abuse or malformed payloads.
    ViolationWindow = 60,
    MaxViolations = 8,
    TemporaryMuteSeconds = 30,

    StaffMute = {
        MaxMinutes = 1440,
        DefaultMinutes = 10
    }
}
