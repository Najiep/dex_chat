Config.Channels = {
    normal = {
        enabled = true,
        label = 'LOCAL',
        kind = 'chat',
        scope = 'proximity',
        distance = 20.0,
        cooldown = 1,
        maxLength = 250,
        theme = 'normal',
        quick = true
    },

    ooc = {
        enabled = true,
        command = 'ooc',
        aliases = {},
        label = 'OOC',
        kind = 'ooc',
        scope = 'bucket',
        cooldown = 3,
        maxLength = 250,
        theme = 'ooc',
        quick = true
    },

    me = {
        enabled = true,
        command = 'me',
        aliases = {},
        label = 'ME',
        kind = 'roleplay',
        scope = 'proximity',
        distance = 15.0,
        cooldown = 1,
        maxLength = 180,
        theme = 'roleplay',
        format = '* {name} {message}',
        show3D = true,
        quick = true
    },

    doo = {
        enabled = true,
        command = 'do',
        aliases = {},
        label = 'DO',
        kind = 'roleplay',
        scope = 'proximity',
        distance = 15.0,
        cooldown = 1,
        maxLength = 180,
        theme = 'roleplay',
        format = '* {message} (( {name} ))',
        show3D = true,
        quick = true
    },

    try = {
        enabled = true,
        command = 'try',
        aliases = {},
        label = 'TRY',
        kind = 'roleplay',
        scope = 'proximity',
        distance = 15.0,
        cooldown = 2,
        maxLength = 180,
        theme = 'roleplay',
        format = '* {name} tries to {message}',
        randomResult = true,
        show3D = true,
        quick = true
    },

    advertisement = {
        enabled = true,
        command = 'ad',
        aliases = { 'advert' },
        label = 'ADVERTISEMENT',
        kind = 'advertisement',
        scope = 'bucket',
        cooldown = 30,
        maxLength = 220,
        theme = 'advertisement',
        price = 250,
        allowedJobs = nil,
        quick = true
    },

    staff = {
        enabled = true,
        command = 'staff',
        aliases = { 'adminchat' },
        label = 'STAFF',
        kind = 'staff',
        scope = 'staff',
        cooldown = 1,
        maxLength = 250,
        theme = 'staff',
        permission = 'dex_chat.staff',
        critical = true,
        quick = false
    },

    job = {
        enabled = true,
        command = 'jobchat',
        aliases = { 'jobc' },
        label = 'JOB',
        kind = 'organization',
        scope = 'organization',
        organizationType = 'job',
        cooldown = 1,
        maxLength = 250,
        theme = 'organization',
        requireDuty = false,
        quick = false
    },

    gang = {
        enabled = true,
        command = 'gangchat',
        aliases = { 'gangc' },
        label = 'GANG',
        kind = 'organization',
        scope = 'organization',
        organizationType = 'gang',
        cooldown = 1,
        maxLength = 250,
        theme = 'organization',
        quick = false
    }
}

Config.PrivateMessages = {
    Enabled = true,
    Command = 'pm',
    Aliases = { 'msg', 'dm' },
    ReplyCommand = 'reply',
    ReplyAliases = { 'r' },
    Cooldown = 1,
    MaxLength = 250,
    Theme = 'private',
    SameBucketOnly = true,
    AllowSelf = false,
    LogContent = true
}
