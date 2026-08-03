# dex_chat v2

A secure, server-authoritative and highly configurable replacement for the default Cfx.re `chat` resource.

`dex_chat` keeps the standard FiveM chat events/exports while adding premium-style channels, themes, organization announcements, private messages, moderation, routing-bucket isolation, per-player UI settings, typing indicators and roleplay 3D text.

## Highlights

- Full replacement through `provide 'chat'`.
- ESX Legacy, Qbox, QBCore and standalone bridges.
- LOCAL, OOC, ME, DO, TRY, advertisement, staff, job and gang channels.
- `/pm`, `/reply`, staff mute/unmute and automatic anti-spam mutes.
- Configurable organization banners for jobs and gangs.
- Routing-bucket and proximity-aware server-side recipient resolution.
- Configurable themes, channel colors, compact mode, opacity, scale, blur and reduced motion.
- Command autocomplete, quick-channel tabs, message history and character counter.
- Safe DOM rendering with no raw HTML execution.
- Burst, duplicate, cooldown, URL, mention and word-filter controls.
- Queued Discord logging to avoid webhook bursts.
- Optional server advertisements with framework money removal.
- Typing indicators and `/me`, `/do`, `/try` floating 3D text.
- Automated Lua configuration and sanitizer tests.

## Installation

1. Put the resource in your server resources folder as `dex_chat`.
2. Stop or remove the stock `[gameplay]/chat` resource.
3. Add `ensure dex_chat` before resources that use chat exports/events.
4. Do not start the stock `chat` resource and `dex_chat` together.
5. Configure the files under `config/`.
6. Add the ACE permissions you need.
7. Restart the server and test on staging first.

```cfg
ensure dex_chat

add_ace group.admin dex_chat.staff allow
add_ace group.admin dex_chat.clearall allow
add_ace group.admin dex_chat.mute allow
add_ace group.admin dex_chat.cooldown.bypass allow
add_ace group.admin dex_chat.filter.bypass allow
add_ace group.admin dex_chat.crossbucket allow
```

## Default commands

| Command | Purpose |
| --- | --- |
| `T` | Open chat |
| `/toggleChat` | Cycle auto-show, always-show and hidden states |
| `/chatsettings` or `F7` | Open personal chat settings |
| `/ooc` | OOC channel |
| `/me` | Roleplay action with optional 3D text |
| `/do` | Roleplay scene description with optional 3D text |
| `/try` | Server-randomized success/failure roleplay action |
| `/ad` | Paid advertisement |
| `/staff` | ACE-restricted staff chat |
| `/jobchat` | Current job-only chat |
| `/gangchat` | Current gang-only chat |
| `/pm [id] [message]` | Private message |
| `/reply [message]` | Reply to the last PM peer |
| `/clear` | Clear local chat |
| `/clearall` | Clear all clients; staff permission required |
| `/chatmute [id] [minutes] [reason]` | Staff mute |
| `/chatunmute [id]` | Remove a staff mute |

Organization commands such as `/police`, `/ambulance`, `/mechanic`, `/ballas` and `/vagos` remain configuration-driven in `config/organizations.lua`.

## Configuration files

- `config/shared.lua` — framework, UI, routing, proximity, typing and auto messages.
- `config/themes.lua` — UI themes and message presentation themes.
- `config/channels.lua` — built-in channel behavior, commands, scopes, cooldowns and prices.
- `config/organizations.lua` — job/gang announcement commands and banners.
- `config/security.lua` — ACE nodes, rate limits, filters and mute limits.
- `config/logging.lua` — console and queued Discord logs.
- `locales/en.lua` and `locales/tl.lua` — localized messages.

See `docs/CONFIGURATION.md` for examples and `docs/MIGRATION_V2.md` before upgrading an existing installation.

## ESX gang provider

ESX does not have one universal gang format. Configure `Config.FrameworkOptions.ESX.GangProvider`:

```lua
GangProvider = {
    Mode = 'job2', -- disabled | job | job2 | metadata | export
    MetadataKey = 'gang',
    Resource = '',
    Export = ''
}
```

An external provider should return:

```lua
{
    name = 'ballas',
    label = 'Ballas',
    grade = { level = 1, name = 'Member', isboss = false },
    onduty = true
}
```

## Stock chat compatibility

Client events/exports:

- `chatMessage`
- `chat:addMessage`
- `chat:addSuggestion`
- `chat:addSuggestions`
- `chat:removeSuggestion`
- `chat:addTemplate`
- `chat:clear`
- `chat:addMode`
- `chat:removeMode`
- `exports.chat:addMessage`
- `exports.chat:addSuggestion`

Server events/exports:

- `_chat:messageEntered`
- `chat:init`
- `chat:addMessage` from server context
- `__cfx_internal:commandFallback`
- `exports.chat:addMessage`
- `exports.chat:registerMessageHook`
- `exports.chat:registerMode`

Raw template HTML is retained only for API compatibility and is never inserted into the DOM.

## Validation

Run from the resource root with Lua 5.4:

```bash
lua5.4 tests/lua/sanitizer_spec.lua
lua5.4 tests/lua/config_spec.lua
```

The GitHub Actions workflow runs these checks automatically.

## Important behavior

- Player identity, job, gang, grade, duty, bucket, recipients, cooldowns and presentation are determined by the server.
- Webhook URLs remain server-only.
- Remote organization logos are rejected by the UI; use local files under `web/dist/images/`.
- Private messages are same-bucket by default.
- Staff mutes are in-memory and reset when the resource/server restarts.
- Database-backed history is intentionally not enabled by default.
