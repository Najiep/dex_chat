# dex_chat v2 Configuration

## Channel scopes

Each channel in `config/channels.lua` can use one of these scopes:

- `global` — all connected players.
- `bucket` — players in the sender's routing bucket when bucket isolation is enabled.
- `proximity` — players inside the configured distance and routing bucket.
- `organization` — players with the same normalized job or gang.
- `staff` — players allowed by the configured ACE permission.

## Creating a channel

```lua
Config.Channels.twitter = {
    enabled = true,
    command = 'twitter',
    aliases = { 'tweet' },
    label = 'TWITTER',
    kind = 'chat',
    scope = 'bucket',
    cooldown = 5,
    maxLength = 220,
    theme = 'normal',
    quick = true
}
```

`quick = true` adds the channel to the NUI quick-channel tabs. The UI prefixes the selected command before submission; the server still validates and routes it.

## Paid advertisements

```lua
Config.Channels.advertisement = {
    enabled = true,
    command = 'ad',
    label = 'ADVERTISEMENT',
    kind = 'advertisement',
    scope = 'bucket',
    cooldown = 30,
    maxLength = 220,
    theme = 'advertisement',
    price = 250,
    allowedJobs = nil
}
```

Set `allowedJobs = { 'taxi', 'mechanic' }` to whitelist jobs. Money removal is performed after validation and hooks, immediately before delivery.

## Job or gang channels

```lua
Config.Channels.job = {
    enabled = true,
    command = 'jobchat',
    label = 'JOB',
    kind = 'organization',
    scope = 'organization',
    organizationType = 'job',
    requireDuty = false,
    cooldown = 1,
    maxLength = 250,
    theme = 'organization'
}
```

Use `organizationType = 'gang'` for gang-only delivery.

## Organization announcements

Organization announcements are separate from job/gang chat. They support membership, grade, boss and duty requirements plus custom banner presentation.

```lua
Config.Organizations.police = {
    enabled = true,
    type = 'job',
    command = 'police',
    aliases = { 'pd', 'lspd' },
    label = 'Los Santos Police Department',
    shortLabel = 'LSPD',
    authorization = {
        minimumGrade = 0,
        allowedGrades = nil,
        bossOnly = false,
        requireDuty = true
    },
    message = {
        scope = 'bucket',
        anonymous = false,
        cooldown = 15,
        globalCooldown = 3,
        maxLength = 220
    },
    banner = {
        title = 'PUBLIC SAFETY ANNOUNCEMENT',
        logo = 'images/jobs/police.webp',
        layout = 'expanded',
        primary = '#2563EB',
        secondary = '#0F172A',
        border = '#60A5FA',
        text = '#FFFFFF',
        duration = 10000
    }
}
```

Use only local logo paths inside `web/dist/`. Remote URLs are not rendered.

## Themes

`Config.Themes` controls the overall chat UI. `Config.MessageThemes` controls individual message cards.

```lua
Config.MessageThemes.twitter = {
    accent = '#38BDF8',
    background = 'rgba(7, 30, 50, 0.94)',
    text = '#F0F9FF',
    icon = 'at-sign'
}
```

Then set `theme = 'twitter'` on a channel.

## Filters

```lua
Config.Security.Filter = {
    Enabled = true,
    Mode = 'block',
    BlacklistedWords = { 'exampleword' },
    BlockUrls = true,
    AllowedDomains = { 'discord.gg/yourserver' },
    MaxMentions = 5
}
```

Filters run after UTF-8 sanitization and before payment or delivery. ACE `dex_chat.filter.bypass` bypasses word/URL/mention filtering, but not payload validation.

## Rate limits

- Per-channel cooldown.
- Rolling burst window.
- Duplicate-message window.
- Per-organization user cooldown.
- Global organization announcement cooldown.
- Escalating temporary mute after repeated violations.

ACE `dex_chat.cooldown.bypass` bypasses cooldown, duplicate and burst checks.

## Routing buckets

```lua
Config.Routing = {
    Enabled = true,
    BucketIsolation = true,
    DefaultScope = 'bucket',
    PrivateMessagesSameBucketOnly = true
}
```

When disabled, bucket-scoped channels fall back to normal unrestricted delivery. Proximity still uses server-side player coordinates.

## Per-player settings

Players can open `/chatsettings` or press `F7`. Settings are stored using client resource KVP:

- theme
- scale
- opacity
- compact mode
- timestamps
- background blur
- reduced motion

These are display-only preferences and are never trusted for routing or permissions.
