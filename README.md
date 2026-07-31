# dex_chat

A secure, server-authoritative replacement for the default Cfx.re `chat` resource. It adds configurable job and gang announcement banners while preserving commonly used stock chat events and exports.

## Included in v1.0

- Fullscreen NUI chat with command suggestions and message history.
- Organization-specific commands such as `/ballas`, `/vagos`, `/police`, `/ambulance`, and `/mechanic`.
- Server-side membership, grade, boss, and duty validation.
- ESX Legacy, Qbox, QBCore, and standalone bridge detection.
- ESX gang provider modes including `job2`, metadata, and external export.
- Routing-bucket isolation and optional proximity routing.
- Per-player and per-organization cooldowns with temporary anti-spam mutes.
- Safe DOM rendering without raw HTML injection.
- Compatibility events/exports for `chat:addMessage`, suggestions, templates, modes, hooks, clear, and deprecated `chatMessage`.
- Optional Discord logging.

## Installation

1. Put the folder in your server resources as `dex_chat`.
2. Stop/remove the stock `[gameplay]/chat` resource from your startup list.
3. Add `ensure dex_chat` before resources that depend on chat.
4. Keep `provide 'chat'` in `fxmanifest.lua`.
5. Configure framework and organizations under `config/`.
6. Restart the server and test in a staging environment first.

Do not intentionally start both the stock `chat` resource and `dex_chat` together.

## ESX gang setup

ESX has no universal gang schema. Configure `Config.FrameworkOptions.ESX.GangProvider`:

- `job2`: reads a secondary job named `job2`.
- `job`: treats the primary ESX job as the gang.
- `metadata`: reads a metadata key.
- `export`: calls your gang resource export.
- `disabled`: disables trusted ESX gang membership.

Example external provider:

```lua
GangProvider = {
    Mode = 'export',
    Resource = 'your_gang_resource',
    Export = 'GetPlayerGang'
}
```

The export should return a table shaped like:

```lua
{
    name = 'ballas',
    label = 'Ballas',
    grade = { level = 1, name = 'Member', isboss = false },
    onduty = true
}
```

## Permissions

```cfg
add_ace group.admin dex_chat.staff allow
add_ace group.admin dex_chat.cooldown.bypass allow
```

`/clearall` requires `dex_chat.staff` unless used from the server console.

## Commands

```text
/ballas [message]
/vagos [message]
/police [message]
/pd [message]
/lspd [message]
/ambulance [message]
/ems [message]
/mechanic [message]
/mech [message]
/ooc [message]
/clear
/clearall
/toggleChat
```

## Custom logos

Add image files inside `web/dist/images/`, include them in `fxmanifest.lua`, then set for example:

```lua
logo = 'images/gangs/ballas.webp'
```

The banner automatically falls back to the configured short label when an image is missing.

## Development policy

The production-ready NUI is committed under `web/dist/`, so no Node runtime or build step is needed on the game server.

See [Requirement.md](Requirement.md), [Design.md](Design.md), and [Task.md](Task.md) for the full roadmap and architecture.
