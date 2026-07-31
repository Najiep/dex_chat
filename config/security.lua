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
        exec = true
    },

    MaxRawBytes = 1024,
    CollapseWhitespace = true,
    CooldownBypassAce = 'dex_chat.cooldown.bypass',
    StaffAce = 'dex_chat.staff',
    AnnouncementAce = 'dex_chat.announcement',

    -- Optional escalating mute after repeated rate-limit violations.
    ViolationWindow = 60,
    MaxViolations = 8,
    TemporaryMuteSeconds = 30
}
