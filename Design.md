# Dex Chat — Technical Design

**Document status:** Implementation architecture  
**Depends on:** `Requirement.md`  
**Target release:** 1.0.0

---

## 1. Design Overview

`dex_chat` will be an event-driven FiveM resource that replaces the stock `chat` resource while preserving its commonly used public interface.

The resource is divided into five major layers:

1. **Compatibility layer** — stock chat events and exports.
2. **Chat domain layer** — validation, channels, routing, hooks, modes, and message construction.
3. **Framework bridge layer** — ESX, Qbox, QBCore, or standalone player data.
4. **Presentation layer** — custom NUI for messages, banners, input, history, and suggestions.
5. **Infrastructure layer** — configuration, localization, logging, rate limits, and moderation.

The server is authoritative. NUI and client Lua are treated as untrusted presentation/input components.

---

## 2. Key Architecture Decisions

### ADR-001: Replace instead of modifying stock chat

**Decision:** Build `dex_chat` as a separate resource and declare:

```lua
provide 'chat'
```

**Reasoning:**

- Cfx.re stock files remain untouched and easy to restore.
- Updates to server data do not overwrite custom code.
- Resources declaring `dependency 'chat'` can resolve to `dex_chat`.
- The replacement can maintain compatibility while adding custom behavior.

### ADR-002: Server-authoritative organization messages

**Decision:** The client never sends a completed banner object.

Client submission:

```lua
{
    text = 'Route 68 is closed.'
}
```

Server derives:

- Job or gang membership.
- Organization command identity.
- Grade and duty state.
- Character display name.
- Banner theme.
- Routing bucket.
- Recipients.
- Cooldown state.
- Log data.

**Reasoning:** Prevents spoofing and unauthorized public announcements.

### ADR-003: Configuration compiles at startup

**Decision:** Organization and channel configuration is normalized and validated once during startup.

The runtime uses compiled tables:

```lua
Runtime.Commands['ballas'] = {
    organization = 'ballas',
    handler = 'organization'
}
```

**Reasoning:**

- No repeated parsing on each command.
- Duplicate aliases are detected early.
- Runtime handlers remain small and predictable.

### ADR-004: One normalized framework interface

**Decision:** Core chat logic depends only on `Bridge`, not directly on a framework.

**Reasoning:**

- Framework-specific shapes do not leak into authorization logic.
- Each adapter can be tested separately.
- Standalone mode remains possible.

### ADR-005: Message rendering uses schemas, not arbitrary HTML

**Decision:** Internal messages use a versioned data schema and a theme ID.

**Reasoning:**

- Prevents HTML/template injection.
- Keeps visual behavior consistent.
- Enables safe future schema migration.

### ADR-006: Recipient resolution happens on the server

**Decision:** Every channel asks `Router.ResolveRecipients()` for its final target list.

**Reasoning:**

- Routing buckets remain authoritative.
- Proximity, organization, ACE, and custom scopes share one pipeline.
- Client-provided target lists are impossible.

### ADR-007: No required database

**Decision:** Version 1.0 stores cooldowns, hooks, modes, mutes, and transient history in memory.

**Reasoning:**

- Keeps installation simple.
- Chat remains usable without oxmysql.
- Persistent moderation can be added through an optional adapter later.

---

## 3. Proposed Repository Structure

```text
dex_chat/
├── fxmanifest.lua
├── README.md
├── Requirement.md
├── Design.md
├── Task.md
├── LICENSE
│
├── config/
│   ├── shared.lua
│   ├── client.lua
│   ├── server.lua
│   ├── channels.lua
│   ├── organizations.lua
│   ├── security.lua
│   └── logging.lua
│
├── shared/
│   ├── constants.lua
│   ├── types.lua
│   ├── validation.lua
│   ├── sanitizer.lua
│   └── utils.lua
│
├── bridge/
│   ├── init.lua
│   ├── interface.lua
│   ├── standalone/
│   │   └── server.lua
│   ├── esx/
│   │   ├── client.lua
│   │   └── server.lua
│   ├── qbox/
│   │   ├── client.lua
│   │   └── server.lua
│   └── qbcore/
│       ├── client.lua
│       └── server.lua
│
├── client/
│   ├── main.lua
│   ├── input.lua
│   ├── compatibility.lua
│   ├── suggestions.lua
│   ├── preferences.lua
│   ├── nui.lua
│   └── debug.lua
│
├── server/
│   ├── main.lua
│   ├── compatibility.lua
│   ├── command_registry.lua
│   ├── message_service.lua
│   ├── organization_service.lua
│   ├── channel_service.lua
│   ├── router.lua
│   ├── hooks.lua
│   ├── modes.lua
│   ├── rate_limiter.lua
│   ├── moderation.lua
│   ├── logging.lua
│   └── debug.lua
│
├── locales/
│   ├── en.lua
│   └── tl.lua
│
├── web/
│   ├── package.json
│   ├── package-lock.json
│   ├── tsconfig.json
│   ├── vite.config.ts
│   ├── index.html
│   ├── public/
│   │   ├── sounds/
│   │   └── images/
│   │       ├── jobs/
│   │       └── gangs/
│   └── src/
│       ├── main.tsx
│       ├── App.tsx
│       ├── env.ts
│       ├── types/
│       │   └── chat.ts
│       ├── stores/
│       │   └── chatStore.ts
│       ├── hooks/
│       │   ├── useNuiEvent.ts
│       │   └── useKeyboard.ts
│       ├── components/
│       │   ├── ChatRoot.tsx
│       │   ├── MessageList.tsx
│       │   ├── MessageCard.tsx
│       │   ├── BannerCard.tsx
│       │   ├── ChatInput.tsx
│       │   ├── Suggestions.tsx
│       │   ├── ChannelBadge.tsx
│       │   └── AssetFallback.tsx
│       ├── utils/
│       │   ├── nui.ts
│       │   ├── formatting.ts
│       │   └── validation.ts
│       └── styles/
│           ├── tokens.css
│           ├── chat.css
│           └── animations.css
│
└── tests/
    ├── lua/
    │   ├── sanitizer_spec.lua
    │   ├── organization_spec.lua
    │   ├── routing_spec.lua
    │   └── rate_limiter_spec.lua
    └── web/
        ├── BannerCard.test.tsx
        ├── ChatInput.test.tsx
        └── MessageCard.test.tsx
```

Generated NUI output should be written to `web/dist/` and included in release packages. Source repositories may either commit the build or build it in CI; the project must choose one policy and document it.

---

## 4. Resource Manifest Design

Proposed `fxmanifest.lua` shape:

```lua
fx_version 'cerulean'
game 'gta5'

name 'dex_chat'
author 'Dex Development'
description 'Custom FiveM chat replacement with job and gang banners'
version '1.0.0'

provide 'chat'

ui_page 'web/dist/index.html'

shared_scripts {
    'config/shared.lua',
    'config/channels.lua',
    'config/organizations.lua',
    'shared/constants.lua',
    'shared/types.lua',
    'shared/validation.lua',
    'shared/sanitizer.lua',
    'shared/utils.lua',
    'locales/*.lua'
}

client_scripts {
    'config/client.lua',
    'bridge/init.lua',
    'bridge/*/client.lua',
    'client/*.lua'
}

server_scripts {
    'config/server.lua',
    'config/security.lua',
    'config/logging.lua',
    'bridge/interface.lua',
    'bridge/*/server.lua',
    'server/*.lua'
}

files {
    'web/dist/index.html',
    'web/dist/**/*',
    'web/public/images/**/*',
    'web/public/sounds/**/*'
}
```

Implementation note: glob ordering must be checked carefully. If deterministic load order cannot be guaranteed, list files explicitly rather than depending on broad globs.

No hard dependency on ESX, Qbox, QBCore, ox_lib, or oxmysql should be declared because framework selection is dynamic.

---

## 5. Runtime Startup Sequence

```text
Resource start
   │
   ├─ Load configuration
   ├─ Validate general settings
   ├─ Detect/select framework bridge
   ├─ Validate bridge interface
   ├─ Normalize channel definitions
   ├─ Normalize organization definitions
   ├─ Compile command and alias registry
   ├─ Register compatibility exports/events
   ├─ Register channel commands
   ├─ Register organization commands
   ├─ Register built-in modes/hooks
   ├─ Start bounded cleanup scheduler
   └─ Print startup summary
```

Startup summary example:

```text
[dex_chat] Framework: ESX
[dex_chat] Organizations: 8 enabled, 1 disabled
[dex_chat] Commands: 19 registered
[dex_chat] Stock compatibility: enabled
[dex_chat] Routing buckets: enabled
[dex_chat] Logging: console + Discord
```

Secrets must not appear in the summary.

---

## 6. Framework Bridge Design

### 6.1 Interface

`bridge/interface.lua` defines expected functions:

```lua
Bridge = Bridge or {}

---@param source number
---@return DexPlayerData|nil
function Bridge.GetPlayer(source) end

---@param source number
---@return string|nil
function Bridge.GetIdentifier(source) end

---@param source number
---@return string
function Bridge.GetCharacterName(source) end

---@param source number
---@return DexOrganizationData
function Bridge.GetJob(source) end

---@param source number
---@return DexOrganizationData
function Bridge.GetGang(source) end

---@param source number
---@param account string
---@return number
function Bridge.GetBalance(source, account) end

---@param source number
---@param account string
---@param amount number
---@param reason string
---@return boolean
function Bridge.RemoveMoney(source, account, amount, reason) end

---@param source number
---@param message string
---@param messageType string
function Bridge.Notify(source, message, messageType) end
```

Only functions needed by enabled modules are required to perform meaningful work. Unsupported optional operations return safe failure values.

### 6.2 ESX adapter

Server responsibilities:

- Resolve `xPlayer` from source.
- Read character name through supported player methods/data.
- Normalize job name, label, grade, grade label, and duty state.
- Support gang data through a configurable provider because ESX does not have one universal gang schema.
- Support optional money removal for advertisements.

Gang provider modes:

- `disabled`
- `job2`
- `metadata`
- `export`
- `customCallback`

No ESX gang structure should be assumed silently.

### 6.3 Qbox adapter

Server responsibilities:

- Resolve player data using supported Qbox exports.
- Read active `job`, `jobs`, `gang`, and `gangs` where relevant.
- Normalize grade level and label.
- Normalize `onduty` to `onDuty`.
- Prefer active job/gang for command authorization unless configuration explicitly permits secondary memberships.

### 6.4 QBCore adapter

Server responsibilities:

- Resolve player with the supported QBCore player export/core API.
- Normalize `PlayerData.job`.
- Normalize `PlayerData.gang`.
- Normalize nested grade level/name.
- Normalize `onduty`.

### 6.5 Standalone adapter

Standalone mode provides:

- FiveM player name as character name.
- No trusted job/gang membership.
- ACE-based channels.
- Normal, OOC, system, console, and staff chat.

Organization commands are disabled unless an external organization provider is registered.

---

## 7. Configuration Model

### 7.1 General configuration

```lua
Config = {
    Framework = 'auto',
    Locale = 'en',
    Debug = false,

    Input = {
        DefaultKey = 'T',
        MaxLength = 250,
        HistoryLimit = 50
    },

    Messages = {
        ClientHistoryLimit = 150,
        DefaultDuration = 10000,
        ShowTimestamps = true
    },

    Routing = {
        BucketIsolation = true,
        DefaultScope = 'bucket'
    }
}
```

### 7.2 Organization configuration

```lua
Config.Organizations = {
    ballas = {
        enabled = true,
        type = 'gang',
        command = 'ballas',
        aliases = {},
        label = 'Ballas',
        shortLabel = 'BALLAS',

        authorization = {
            minimumGrade = 0,
            allowedGrades = nil,
            bossOnly = false,
            requireDuty = false
        },

        message = {
            scope = 'bucket',
            anonymous = true,
            cooldown = 30,
            globalCooldown = 5,
            maxLength = 200
        },

        banner = {
            themeId = 'ballas',
            title = 'BALLAS ANNOUNCEMENT',
            logo = 'images/gangs/ballas.webp',
            background = nil,
            icon = 'users',
            primary = '#7C3AED',
            secondary = '#2E1065',
            border = '#A78BFA',
            text = '#FFFFFF',
            layout = 'expanded',
            sound = 'organization.ogg',
            duration = 10000
        }
    },

    police = {
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
            themeId = 'police',
            title = 'PUBLIC SAFETY ANNOUNCEMENT',
            logo = 'images/jobs/police.webp',
            icon = 'shield',
            primary = '#2563EB',
            secondary = '#0F172A',
            border = '#60A5FA',
            text = '#FFFFFF',
            layout = 'expanded',
            sound = 'public-service.ogg',
            duration = 10000
        }
    }
}
```

### 7.3 Compiled organization model

Configuration is converted into an immutable runtime representation:

```lua
Runtime.Organizations['ballas'] = {
    name = 'ballas',
    type = ORG_GANG,
    command = 'ballas',
    commandSet = {
        ballas = true
    },
    authorization = { ... },
    presentation = { ... }
}
```

Original config tables must not be mutated after compilation.

---

## 8. Command Registry Design

### 8.1 Registration

`command_registry.lua` owns all registered chat commands.

```lua
CommandRegistry.Register({
    name = 'ballas',
    aliases = {},
    kind = 'organization',
    organization = 'ballas',
    handler = OrganizationService.HandleCommand
})
```

### 8.2 Alias handling

Every alias registers a closure that preserves the original player source and calls the same handler directly:

```lua
RegisterCommand(alias, function(source, args, rawCommand)
    definition.handler(source, args, rawCommand, definition)
end, false)
```

Do not route aliases through a server `ExecuteCommand` string.

### 8.3 Reserved command set

Default reserved names:

- `say`
- `quit`
- `connect`
- `ensure`
- `start`
- `stop`
- `restart`
- `refresh`
- `clear`
- `clearall`
- `togglechat`

The validator may allow safe overrides only through an explicit setting.

---

## 9. Message Processing Pipeline

Every player-originated message follows this pipeline:

```text
Receive text/command
   │
   ├─ Verify source and payload type
   ├─ Check mute state
   ├─ Apply payload byte/character limit
   ├─ Sanitize and normalize text
   ├─ Reject empty result
   ├─ Resolve channel/organization definition
   ├─ Resolve trusted player data
   ├─ Authorize membership/grade/duty/ACE
   ├─ Check per-player rate limit
   ├─ Check per-command/global cooldown
   ├─ Run moderation policy
   ├─ Construct canonical message schema
   ├─ Run registered message hooks
   ├─ Resolve recipients on server
   ├─ Deliver validated payload
   ├─ Record cooldown
   └─ Log outcome asynchronously
```

Cooldown should be recorded only after the message is accepted for delivery, except malformed-request abuse counters which may record earlier.

---

## 10. Organization Authorization

Proposed function:

```lua
---@param source number
---@param organization DexCompiledOrganization
---@return boolean allowed
---@return string|nil reason
---@return DexPlayerData|nil player
function OrganizationService.Authorize(source, organization)
    local player = Bridge.GetPlayer(source)
    if not player then
        return false, 'player_unavailable'
    end

    local membership = organization.type == 'job'
        and player.job
        or player.gang

    if not membership or membership.name ~= organization.name then
        return false, 'not_member', player
    end

    if organization.authorization.requireDuty and not membership.onDuty then
        return false, 'off_duty', player
    end

    if membership.grade < organization.authorization.minimumGrade then
        return false, 'grade_too_low', player
    end

    if organization.authorization.bossOnly and not membership.isBoss then
        return false, 'boss_only', player
    end

    return true, nil, player
end
```

Actual implementation must also handle `allowedGrades` and framework data failures safely.

---

## 11. Routing Service Design

### 11.1 Router interface

```lua
---@param context DexRoutingContext
---@return number[] recipients
function Router.ResolveRecipients(context) end
```

Context:

```lua
{
    source = 1,
    scope = 'bucket',
    bucket = 2,
    proximity = 20.0,
    organizationType = 'gang',
    organizationName = 'ballas',
    ace = nil,
    crossBucket = false
}
```

### 11.2 Scope implementations

#### Public/global

All connected players, but only when explicitly enabled.

#### Bucket

All players where:

```lua
GetPlayerRoutingBucket(target) == senderBucket
```

#### Proximity

Players must:

- Be in the same routing bucket.
- Have a valid player ped.
- Be within configured distance.

Distance calculation is performed only when a proximity message is sent.

#### Organization

For each connected player:

- Resolve normalized player data.
- Compare active job/gang name.
- Optionally require duty.
- Apply bucket isolation unless cross-bucket organization chat is enabled.

A short-lived per-player membership cache may be used, but it must be invalidated by framework job/gang update events and player unload.

#### ACE

Use `IsPlayerAceAllowed` for each target.

#### Custom

Invoke a trusted server callback that returns target sources. Validate all returned values before delivery.

### 11.3 Recipient safety

- Remove duplicates.
- Remove invalid/disconnected sources.
- Never include source `0` as a client recipient.
- Never trust client targets.
- Apply a maximum recipient count safeguard without breaking legitimate global messages.

---

## 12. Compatibility Layer Design

### 12.1 Client compatibility

`client/compatibility.lua` handles:

```lua
RegisterNetEvent('chat:addMessage', function(message)
    Nui.PushMessage(Compatibility.NormalizeMessage(message))
end)
```

It also handles suggestions, templates, modes, and clearing.

### 12.2 Template compatibility

Stock resources may register HTML templates. Direct HTML insertion conflicts with the secure-schema design.

Version 1.0 strategy:

1. Store template identifiers and raw template strings in a compatibility registry.
2. Support a safe subset for positional text placeholders.
3. Strip unsupported markup or fall back to a standard compatibility message card.
4. Never inject raw template strings with `innerHTML`.
5. Emit a debug warning when a template cannot be represented safely.

A future optional unsafe compatibility mode must not be enabled by default.

### 12.3 Client exports

```lua
exports('addMessage', function(message)
    TriggerEvent('chat:addMessage', message)
end)

exports('addSuggestion', function(name, help, params)
    TriggerEvent('chat:addSuggestion', name, help, params)
end)
```

### 12.4 Server addMessage export

```lua
exports('addMessage', function(target, message)
    if message == nil then
        message = target
        target = -1
    end

    MessageService.SendCompatibility(target, message)
end)
```

The service validates shape before forwarding.

### 12.5 Message hooks

Hooks are stored with owner resource:

```lua
Hooks[id] = {
    resource = GetInvokingResource(),
    callback = callback
}
```

Hook control object supports:

- `updateMessage(fields)`
- `cancel()`
- `setSeObject(ace)`
- `setRouting(targetOrTargets)`

All hook output must be revalidated after hooks run.

Hooks are removed when their owner resource stops.

### 12.6 Modes

Modes use the same lifecycle pattern as hooks.

Mode registration validates:

- Name.
- Display label.
- Color.
- Callback.
- Optional ACE object.

Mode callbacks cannot bypass final payload validation.

---

## 13. Rate Limiter Design

Use expiry-on-access token buckets or rolling windows without a high-frequency cleanup loop.

Suggested state:

```lua
RateLimiter.Players[source] = {
    normal = {
        tokens = 4,
        updatedAt = 0
    },
    organization = {
        tokens = 2,
        updatedAt = 0
    },
    violations = 0,
    mutedUntil = 0
}
```

Per-organization cooldown:

```lua
RateLimiter.OrganizationCooldowns['ballas'] = 0
```

Keys must be removed on `playerDropped`.

A low-frequency cleanup, such as every five minutes, may remove stale global entries. It must not run every frame or every second.

---

## 14. Sanitization Design

### 14.1 Server sanitizer

Input stages:

1. Type check.
2. Byte limit guard.
3. Remove null bytes.
4. Remove C0/C1 control characters except permitted spacing.
5. Convert line breaks/tabs to spaces.
6. Collapse repeated whitespace according to configuration.
7. Trim.
8. Enforce final character/codepoint limit.
9. Apply moderation policy.

### 14.2 UI rendering

React text nodes must render message text:

```tsx
<span>{message.content.text}</span>
```

Do not use `dangerouslySetInnerHTML` for player or compatibility messages.

### 14.3 Asset validation

Organization asset paths must:

- Be local relative paths.
- Match an allowed extension.
- Reject `..`, protocol strings, and query-based external URLs.
- Fall back to initials on load failure.

---

## 15. Logging Design

### 15.1 Log event

```lua
{
    category = 'organization',
    outcome = 'delivered',
    source = 12,
    identifier = 'char-id',
    characterName = 'John Doe',
    command = 'police',
    organization = 'police',
    bucket = 2,
    recipients = 41,
    content = 'Route 68 is closed.',
    timestamp = os.time()
}
```

### 15.2 Logger adapters

- `ConsoleLogger`
- `DiscordLogger`
- `CustomLogger`

Logger failures are caught and never cancel chat delivery.

### 15.3 Discord behavior

- Use server-only webhook configuration.
- Escape `@everyone`, `@here`, and role/user mention formats.
- Truncate fields to Discord limits.
- Batch only if batching does not reorder important moderation events.
- Apply independent webhook rate control.

---

## 16. NUI Message Protocol

### 16.1 Lua to NUI actions

```text
DEX_CHAT/BOOTSTRAP
DEX_CHAT/ADD_MESSAGE
DEX_CHAT/ADD_MESSAGES
DEX_CHAT/CLEAR
DEX_CHAT/SET_VISIBLE
DEX_CHAT/SET_INPUT
DEX_CHAT/ADD_SUGGESTION
DEX_CHAT/ADD_SUGGESTIONS
DEX_CHAT/REMOVE_SUGGESTION
DEX_CHAT/ADD_MODE
DEX_CHAT/REMOVE_MODE
DEX_CHAT/SET_PREFERENCES
DEX_CHAT/SHOW_ERROR
```

Example:

```lua
SendNUIMessage({
    action = 'DEX_CHAT/ADD_MESSAGE',
    payload = message
})
```

### 16.2 NUI to Lua callbacks

```text
ready
submit
cancel
setPreference
requestSuggestions
```

Example submit payload:

```ts
{
  text: string;
  mode?: string;
}
```

Lua must still validate payload type and limits before any server event.

### 16.3 Boot handshake

1. Client starts with focus disabled.
2. NUI sends `ready`.
3. Client sends bootstrap settings, themes, modes, suggestions, and preferences.
4. Client marks NUI ready.
5. Queued messages are flushed in order.

Queue length must be bounded to prevent memory growth if NUI never becomes ready.

---

## 17. NUI Component Design

### ChatRoot

Owns visibility states and layout safe area.

### MessageList

- Renders ordered messages.
- Enforces list size.
- Supports auto-scroll only when the user is near the bottom.
- Removes expired transient messages.

### MessageCard

Renders normal, OOC, roleplay, staff, console, and compatibility messages.

### BannerCard

Renders job/gang banners using trusted theme tokens.

Suggested layout:

```text
┌────────────────────────────────────────┐
│ [LOGO] ORGANIZATION NAME        18:42 │
│         BANNER TITLE                   │
│                                        │
│ Message text wraps safely here.        │
│                                        │
│ Sender • Grade                         │
└────────────────────────────────────────┘
```

### ChatInput

- Controlled input.
- Character counter.
- Mode badge.
- Command parser preview.
- History navigation.

### Suggestions

- Prefix matching.
- Keyboard navigation.
- Parameter hints.
- ACE-filtered command list from Lua.

### AssetFallback

Displays organization initials if an image fails.

---

## 18. UI State Model

```ts
interface ChatState {
  ready: boolean;
  visibleMode: 'active' | 'always' | 'hidden';
  inputOpen: boolean;
  inputText: string;
  selectedMode?: string;
  messages: DexChatMessage[];
  suggestions: ChatSuggestion[];
  modes: ChatMode[];
  preferences: ChatPreferences;
}
```

State rules:

- Message IDs are unique.
- Duplicate IDs are ignored or replaced only by an explicit update action.
- Maximum message count is enforced at insertion.
- Preferences are validated before storage.

---

## 19. Input and Focus Lifecycle

### Opening

1. Player presses registered chat key.
2. Client checks pause/menu/death restrictions if configured.
3. Client sets input state.
4. `SetNuiFocus(true, false)`.
5. NUI focuses input.

### Submit

1. NUI callback sends text and mode.
2. Client immediately closes focus.
3. If text begins with `/`, client executes the command locally through `ExecuteCommand` after removing `/`.
4. Otherwise client sends `_chat:messageEntered` with the selected mode.
5. Server processes through the canonical pipeline.

### Cancel

- Close input.
- Release focus.
- Preserve or clear draft according to preference.

### Resource stop

`onClientResourceStop` must always release NUI focus when the stopping resource is `dex_chat`.

---

## 20. Error Handling Strategy

Player-facing failures use locale keys:

- `error.not_member`
- `error.off_duty`
- `error.grade_too_low`
- `error.cooldown`
- `error.muted`
- `error.message_empty`
- `error.message_too_long`
- `error.invalid_command`
- `error.internal`

Errors should appear as local system messages in the chat UI. Framework notifications may be optionally enabled, but chat must not depend on them.

Server errors include structured context without exposing secrets.

---

## 21. Cache Strategy

Safe caches:

- Compiled configuration: lifetime of resource.
- Registered command map: lifetime of resource.
- Static themes: lifetime of resource.
- Player normalized data: optional short-lived cache.
- Suggestions: rebuilt only when resources/commands change.

Player cache invalidation triggers:

- Player joined/loaded.
- Player dropped/unloaded.
- Job changed.
- Gang changed.
- Duty changed.
- Resource restart.

Correctness is preferred over aggressive caching.

---

## 22. Performance Design

### Client

- No idle frame loop for message maintenance.
- Use event listeners and bounded timers.
- Use one expiry scheduler rather than one permanent timer per message when possible.
- Memoize message/banner components where beneficial.
- Avoid large shadows, blur layers, and layout-thrashing animations.
- Animate transform/opacity only.

### Server

- Command handlers perform work only on submission.
- Router loops over connected players only for messages that require recipient filtering.
- Webhooks run outside the critical delivery path.
- Configuration is precompiled.
- Cleanup scheduler is infrequent and bounded.

### Proximity optimization

For proximity chat, use server-known player coordinates where reliable. If an implementation requires client coordinate assistance, it must not trust the client to define recipients; the server remains the final authority and should validate same bucket and reasonable source state.

---

## 23. Testing Architecture

### Lua pure-module tests

Pure logic modules should avoid direct natives where possible so they can be tested with mocks:

- Sanitizer.
- Config validator.
- Grade rules.
- Cooldown math.
- Command conflicts.
- Recipient deduplication.

### Server integration test resource

Create an optional `dex_chat_test` resource for development that can:

- Emit stock compatibility events.
- Call client/server exports.
- Register hooks and modes.
- Generate safe and malicious test payloads.
- Simulate organization authorization with a test bridge.

Do not ship the test resource in production release packages unless clearly disabled.

### NUI tests

Use a browser test runner for component behavior and payload rendering.

### Manual verification checklist

- Fresh connect.
- Resource restart.
- Framework restart.
- Job/gang change while connected.
- Routing bucket switch.
- Ultra-wide resolution.
- Low resolution.
- Missing logo.
- Long Unicode message.
- Spam attempt.
- Existing third-party resource using `chat:addMessage`.

---

## 24. Deployment Design

Recommended `server.cfg` order:

```cfg
# Do not start the stock chat simultaneously.
ensure dex_chat

# Framework and gameplay resources follow according to server architecture.
ensure es_extended
# or ensure qbx_core
# or ensure qb-core
```

If the framework must start before the chat bridge detects it, use:

```cfg
ensure es_extended
ensure dex_chat
```

The final install guide must specify the actual supported order after integration tests. Auto detection should also listen for a configured framework startup delay or fail clearly instead of silently falling back to standalone when the intended framework starts later.

Recommended production strategy:

1. Install `dex_chat` alongside the stock resource.
2. Keep stock `chat` stopped in a staging server.
3. Run compatibility tests.
4. Verify all chat-dependent resources.
5. Deploy during a restart window.
6. Keep a rollback config ready.

Rollback:

```cfg
stop dex_chat
ensure chat
```

A full server restart is preferred for rollback.

---

## 25. Versioning and Compatibility

- Resource version uses semantic versioning.
- Internal message schema starts at version `1`.
- Configuration schema has a separate integer version.
- Startup migration may support old config versions later.
- Breaking developer API changes require a major version.
- New optional message fields may be added in minor versions.

---

## 26. Security Review Checklist

Before release:

- [ ] No client can choose an organization banner.
- [ ] No client can choose recipients.
- [ ] All network payloads have type and size checks.
- [ ] All text is rendered without raw HTML.
- [ ] Organization authorization uses current server data.
- [ ] Routing bucket comes from the server.
- [ ] ACE checks run server-side.
- [ ] Hook output is revalidated.
- [ ] Custom routing callback output is validated.
- [ ] Webhook URLs are server-only.
- [ ] Logs escape Discord mentions.
- [ ] Rate limit state clears on disconnect.
- [ ] Resource stop releases NUI focus.
- [ ] Debug mode does not reveal secrets.

---

## 27. Initial Theme Direction

Default visual tokens:

```css
:root {
  --chat-bg: rgba(11, 15, 20, 0.86);
  --chat-surface: rgba(17, 22, 31, 0.94);
  --chat-card: rgba(23, 29, 39, 0.96);
  --chat-border: rgba(255, 255, 255, 0.10);
  --chat-text: #f8fafc;
  --chat-muted: #94a3b8;
  --chat-accent: #00e5ff;
  --chat-danger: #ef4444;
  --chat-warning: #f59e0b;
}
```

The base UI should remain neutral. Organization banners inject only validated color tokens and assets.

---

## 28. Implementation Boundaries

Core services must not:

- Import ESX/Qbox/QBCore directly.
- Call NUI directly from server code.
- Read webhook configuration on the client.
- Construct untrusted HTML.
- Register hardcoded organization commands.
- Use endless high-frequency loops.

Bridge modules must not:

- Make routing decisions.
- Construct UI payloads.
- Apply cooldowns.
- Perform moderation.

NUI must not:

- Decide permissions.
- Decide organization identity.
- Decide recipients.
- Trust local storage values without Lua validation.
- execute arbitrary HTML or scripts from messages.

---

## 29. Final Architecture Flow

```text
Player presses T
      │
      ▼
Custom NUI input
      │ submit text
      ▼
Client input controller
      │ command or normal event
      ▼
Server chat service
      │
      ├─ Sanitizer
      ├─ Moderation
      ├─ Bridge identity lookup
      ├─ Organization/channel authorization
      ├─ Rate limiter
      ├─ Hook/mode pipeline
      ├─ Routing service
      └─ Logger
      │
      ▼
Validated recipients
      │
      ▼
Client compatibility/NUI adapter
      │
      ▼
MessageCard or BannerCard
```

This flow is the required implementation model unless a later architecture decision record replaces it with a documented reason.
