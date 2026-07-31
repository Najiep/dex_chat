# Dex Chat — Product Requirements

**Document status:** Approved baseline for implementation  
**Target resource:** `dex_chat`  
**Target platform:** FiveM / GTA V  
**Primary language:** Lua 5.4  
**UI:** Custom NUI  
**Version target:** 1.0.0

---

## 1. Product Summary

`dex_chat` is a full replacement for the default Cfx.re `chat` resource. It must provide a modern, configurable, secure, and framework-aware chat interface while retaining compatibility with resources that use the standard FiveM chat events and exports.

The main differentiator is organization-specific chat and announcement banners. A player's actual job or gang determines which command they may use and which banner is displayed.

Examples:

- A Ballas member may use `/ballas We own this block.`
- A Vagos member may use `/vagos Meeting at the barrio.`
- An on-duty police officer may use `/police Route 68 is closed.`
- An on-duty EMS employee may use `/ambulance EMS is available.`
- A mechanic employee may use `/mechanic Shop is now open.`

A player must never be able to select or spoof another organization's command, label, logo, colors, grade, sender identity, or visibility scope from the client.

---

## 2. Goals

The resource must:

1. Fully replace the stock FiveM `chat` resource without requiring edits to Cfx.re files.
2. Declare `provide 'chat'` so resources that depend on `chat` can resolve to `dex_chat`.
3. Preserve the commonly used stock chat events and exports.
4. Provide organization-specific commands configured per job and gang.
5. Validate all organization access on the server.
6. Support ESX Legacy, Qbox, and QBCore through isolated framework bridges.
7. Support standalone server messages even when no roleplay framework is active.
8. Respect routing buckets and prevent cross-instance chat leakage.
9. Offer a responsive, accessible, and performant NUI.
10. Provide anti-spam, sanitization, logging, and permission controls.
11. Be modular so chat channels can be enabled or disabled independently.
12. Remain easy to configure without editing core logic.

---

## 3. Non-Goals for Version 1.0

The initial release will not include:

- Voice chat or radio voice integration.
- A full social-media or phone application.
- Persistent direct-message conversations across restarts.
- Automatic translation of player messages.
- AI moderation.
- Database-backed chat history by default.
- A web admin dashboard.
- Rich Markdown, arbitrary HTML, or client-provided message templates.

These may be introduced later as optional modules.

---

## 4. Supported Runtime Modes

### 4.1 Framework detection

`Config.Framework` must support:

- `auto`
- `esx`
- `qbox`
- `qbcore`
- `standalone`

When set to `auto`, the server must detect a supported framework once during resource startup and lock the selected bridge for the lifetime of that resource instance.

The system must not repeatedly poll framework state every frame or on every message.

### 4.2 Framework priority

If more than one framework resource is started, detection priority must be explicit and configurable. Default priority:

1. `qbx_core`
2. `es_extended`
3. `qb-core`
4. `standalone`

A warning must be printed when multiple frameworks are detected.

### 4.3 Standardized player data

Every framework bridge must normalize player information into the following internal shape:

```lua
{
    source = 1,
    identifier = 'framework-specific-character-id',
    characterName = 'John Doe',
    job = {
        name = 'police',
        label = 'Los Santos Police Department',
        grade = 3,
        gradeLabel = 'Sergeant',
        onDuty = true,
        isBoss = false
    },
    gang = {
        name = 'ballas',
        label = 'Ballas',
        grade = 1,
        gradeLabel = 'Member',
        onDuty = true,
        isBoss = false
    }
}
```

Missing job or gang data must normalize to safe defaults rather than cause runtime errors.

---

## 5. Default Chat Replacement Requirements

### 5.1 Resource identity

The resource must be named `dex_chat` and include:

```lua
provide 'chat'
```

The server configuration must start `dex_chat` instead of the stock `chat` resource.

### 5.2 Compatibility events

The client must implement compatible handling for:

- `chatMessage` as a deprecated compatibility path.
- `chat:addMessage`
- `chat:addSuggestion`
- `chat:addSuggestions`
- `chat:removeSuggestion`
- `chat:addTemplate`
- `chat:clear`
- `chat:addMode`
- `chat:removeMode`

The server must implement or route:

- `_chat:messageEntered`
- `chat:init`
- `chatMessage`
- `__cfx_internal:commandFallback`

### 5.3 Compatibility exports

Client exports:

- `addMessage(message)`
- `addSuggestion(name, help, params)`

Server exports:

- `addMessage(target, message)`
- `registerMessageHook(callback)`
- `registerMode(modeData)`

Where practical, the custom API must accept the same common message object fields used by the stock resource:

- `template`
- `templateId`
- `color`
- `multiline`
- `args`
- `mode`

Unsupported or unsafe fields must be ignored safely and logged only in debug mode.

### 5.4 Console and command behavior

The system must support:

- Console `say` messages.
- Unknown command fallback visibility when enabled.
- Command suggestions generated from registered commands and ACE permissions.
- Optional player join and leave messages controlled by configuration or convars.

### 5.5 Migration safety

The stock chat must not be deleted or disabled in production until the compatibility test suite passes.

The installation guide must instruct the server owner to:

1. Back up the stock resource.
2. Remove or comment out `ensure chat`.
3. Ensure `dex_chat` before scripts that use chat exports/events.
4. Verify no category-level `ensure [gameplay]` starts the stock chat simultaneously.
5. Restart the server rather than hot-swapping both chat providers in production.

---

## 6. Organization Command Requirements

### 6.1 Configuration-driven commands

Jobs and gangs must be defined in configuration. Core server files must not contain hardcoded `police`, `ambulance`, `mechanic`, `ballas`, or `vagos` permission logic.

Example configuration intent:

```lua
Config.Organizations = {
    ballas = {
        type = 'gang',
        command = 'ballas',
        label = 'Ballas'
    },
    police = {
        type = 'job',
        command = 'police',
        aliases = { 'pd', 'lspd' },
        label = 'Los Santos Police Department'
    }
}
```

Commands must be registered automatically from validated configuration during startup.

### 6.2 Exact membership validation

For `/ballas`, the server must require the normalized active gang name to equal `ballas`.

For `/police`, the server must require the normalized active job name to equal `police`.

Command names must be case-insensitive from the player's perspective but stored in lowercase internally.

No client event may accept an authoritative organization name.

### 6.3 Grade validation

Each organization may define:

- `minimumGrade`
- `allowedGrades`
- `bossOnly`

If more than one rule exists, the most restrictive result applies.

### 6.4 Duty validation

Job organizations may define `requireDuty`.

When enabled, the bridge must report the player's current duty state and the command must be rejected while off duty.

Gang duty must remain optional because not every framework exposes gang duty.

### 6.5 Command aliases

Each organization may define aliases. Every alias must execute the same validated server handler as the primary command.

Aliases must not use `ExecuteCommand` in a way that changes the source to the server console or bypasses validation.

### 6.6 Message usage

Expected format:

```text
/{organization-command} [message]
```

An empty message must show localized usage help and must not start a cooldown.

### 6.7 Visibility scopes

Each organization command may be configured as:

- `public`: visible to all eligible players in the selected bucket scope.
- `organization`: visible only to members of that job or gang.
- `staff`: visible only to ACE-authorized staff.
- `proximity`: visible only to players within the configured distance and same routing bucket.
- `custom`: routed by a registered server callback.

Public announcements must default to players in the same routing bucket unless `crossBucket = true` is explicitly configured.

### 6.8 Sender display

Each organization may choose:

- Character name and grade.
- Character name only.
- Grade only.
- Anonymous member.
- Organization label only.

The sender display must be created on the server from trusted player data.

### 6.9 Banner appearance

Each organization may configure:

- Label and short label.
- Logo asset.
- Optional background asset.
- Icon name from an allowlist.
- Primary color.
- Secondary color.
- Border color.
- Text color.
- Banner title.
- Optional sound from a local allowlist.
- Display duration.
- Compact or expanded layout.

Remote image URLs and client-supplied CSS must not be accepted in version 1.0.

### 6.10 Duplicate command protection

Startup validation must reject or disable duplicate primary commands and aliases. A clear console error must identify both conflicting organizations.

Reserved commands must not be overridden unless explicitly allowed by configuration.

---

## 7. Built-In Chat Channels

The following modules must be individually configurable:

### 7.1 Normal chat

- Default text entered without `/`.
- Configurable global or proximity routing.
- Same-routing-bucket restriction enabled by default.

### 7.2 Roleplay channels

- `/me [action]`
- `/do [description]`
- `/try [action]`

`/try` must determine success or failure on the server using a secure random result.

Roleplay channels must support proximity routing and optional 3D text integration through an export/event, without making 3D text mandatory.

### 7.3 Out-of-character

- `/ooc [message]`
- Configurable global, bucket, or proximity scope.
- Independent cooldown.

### 7.4 Advertisements

- `/ad [message]`
- Optional price charged through the framework bridge.
- Server-side balance check and transaction.
- Optional job whitelist and cooldown.
- Payment must not be part of the initial core requirement if no supported framework is active.

### 7.5 Staff announcements

- `/staff [message]`
- ACE permission required.
- Configurable anonymous or named staff identity.
- Discord logging enabled by default when a webhook is configured.

### 7.6 Clear commands

- `/clear`: clears only the local player's UI.
- `/clearall`: clears all eligible clients and requires ACE permission.

Clearing the UI must not erase server logs.

---

## 8. Routing Bucket Requirements

1. Every routed message must resolve recipients on the server.
2. Proximity messages must only reach players in the sender's routing bucket.
3. Organization announcements must default to the sender's bucket.
4. Cross-bucket messages require an explicit configuration flag or privileged channel.
5. Late joiners must not receive expired transient banners.
6. A player's bucket must never be trusted from a client payload.
7. When the bucket system is disabled in configuration, bucket `0` behavior must remain fully functional.
8. Recipient resolution must be isolated in a reusable routing service.

---

## 9. NUI Requirements

### 9.1 Core UI

The NUI must provide:

- Chat message list.
- Text input.
- Command suggestions.
- Keyboard selection of suggestions.
- Scrollable history.
- Organization banner cards.
- Normal message cards.
- Channel badges.
- Timestamps.
- Hide/show states.
- Configurable opacity, scale, width, and message lifetime.

### 9.2 Input behavior

- Default key: `T`.
- Key mapping must be registered so players can rebind it.
- `Escape` closes and cancels input.
- `Enter` submits.
- Arrow keys navigate history and suggestions.
- Input length must be displayed when near the limit.
- Pasting multiline text must normalize to a single safe chat message.

### 9.3 Hide states

The player must be able to cycle:

1. Show when active.
2. Always show.
3. Always hide.

Preference should persist with resource KVP.

### 9.4 Responsive behavior

The UI must work at common aspect ratios and resolutions, including:

- 16:9
- 16:10
- 21:9
- 32:9
- 1280×720 minimum supported resolution

The banner must not overflow the safe area.

### 9.5 Accessibility

- Minimum readable font sizes.
- Sufficient contrast for default themes.
- Reduced-motion mode.
- Text alternatives when logos fail to load.
- Do not rely on color alone to identify a channel.
- Optional sound volume and mute control.

### 9.6 NUI technology

The preferred stack is:

- React
- TypeScript
- Vite
- Zustand or a small equivalent state store
- CSS variables for theme tokens

A framework-free production bundle is acceptable only if it meets the same maintainability and testing requirements.

---

## 10. Message Data Contract

The server-to-client internal message contract must be versioned.

Minimum fields:

```lua
{
    schemaVersion = 1,
    id = 'unique-message-id',
    kind = 'message|banner|system',
    channel = 'normal',
    scope = 'bucket',
    timestamp = 0,
    sender = {
        serverId = 1,
        displayName = 'John Doe',
        gradeLabel = 'Sergeant'
    },
    organization = {
        type = 'job',
        name = 'police',
        label = 'Los Santos Police Department',
        shortLabel = 'LSPD'
    },
    content = {
        text = 'Route 68 is closed.'
    },
    presentation = {
        themeId = 'police',
        layout = 'expanded',
        duration = 10000
    }
}
```

The client must render only validated presentation identifiers and sanitized text.

---

## 11. Security Requirements

### 11.1 Server authority

The server must determine:

- Player identity.
- Job and gang.
- Grade.
- Duty state.
- Routing bucket.
- ACE permission.
- Cooldown.
- Allowed command.
- Banner configuration.
- Recipients.
- Logging payload.

The client may submit only the typed text, selected normal chat mode, and non-authoritative UI metadata required for input behavior.

### 11.2 Event protection

- Do not expose a generic event that lets a client broadcast a ready-made message object.
- Validate source on every network event.
- Reject oversized payloads before concatenation or processing.
- Reject non-string message payloads.
- Rate-limit malformed requests as well as valid requests.
- Use separate rate-limit buckets for normal chat, organization commands, and staff actions.
- Never accept a target player list from the client.

### 11.3 Sanitization

Messages must:

- Strip control characters.
- Normalize whitespace.
- Enforce UTF-8-safe length limits where practical.
- Escape or render text without `innerHTML`.
- Reject null bytes.
- Prevent HTML, script, event-handler, CSS, and template injection.
- Preserve normal Unicode characters and common roleplay punctuation.

### 11.4 Rate limiting

Configuration must support:

- Per-player cooldown.
- Per-command cooldown.
- Global organization cooldown.
- Burst limits.
- Maximum messages per rolling window.
- Escalating temporary mute after repeated abuse.

Cooldown timestamps must use server time.

### 11.5 ACE permissions

ACE permission nodes must include:

- `dexchat.staff`
- `dexchat.clearall`
- `dexchat.bypass.cooldown`
- `dexchat.bypass.filter`
- `dexchat.crossbucket`
- `dexchat.debug`

### 11.6 Webhooks

Discord webhook URLs must remain server-only and must never be sent to NUI or clients.

Webhook failures must not block chat delivery.

Logs must escape Discord mentions by default.

---

## 12. Moderation Requirements

The resource must support:

- Configurable blocked words or patterns.
- Replace, reject, or log-only action.
- Per-player temporary mute.
- ACE bypass.
- Server export to mute/unmute/check mute status.
- Optional integration callback for an external moderation resource.

The default filter must be disabled until the server owner configures it.

---

## 13. Logging Requirements

Configurable log categories:

- Normal chat.
- OOC.
- Roleplay commands.
- Organization public announcements.
- Organization internal messages.
- Staff announcements.
- Moderation actions.
- Rejected or spoofed attempts.
- Rate-limit violations.
- Resource startup validation errors.

Destinations:

- Server console.
- Discord webhook.
- Custom export/callback.

Logs should include server ID, stable framework identifier where available, character name, organization, routing bucket, command, outcome, and sanitized content.

Sensitive identifiers must be configurable and disabled in Discord output by default.

---

## 14. Configuration Requirements

Configuration must be separated by concern:

- General settings.
- Framework settings.
- UI settings.
- Channel settings.
- Organization definitions.
- Security/rate limits.
- Logging.
- Locales.

Startup validation must detect:

- Invalid framework name.
- Duplicate commands or aliases.
- Invalid organization type.
- Missing command.
- Invalid grade values.
- Invalid color format.
- Missing local asset.
- Invalid scope.
- Unsafe duration or message length.
- Reserved command collision.

Invalid organization entries should be disabled individually when possible instead of stopping the whole resource.

Critical manifest or bridge errors should stop startup with a clear message.

---

## 15. Localization Requirements

- English must be included.
- All player-facing messages must use locale keys.
- Tagalog/Filipino locale should be included before 1.0 release.
- Organization labels may remain server-configured text.
- Missing locale keys must fall back to English.

---

## 16. Performance Requirements

### Client

- No permanent `Wait(0)` loop solely for chat visibility.
- Frame loops are allowed only while input or an animation requiring frame updates is active.
- Idle resource time should remain effectively negligible in normal resmon observation.
- NUI updates should be event-driven and batched where useful.
- Message list must have a configurable maximum size.
- Expired messages must be removed without unbounded timers.

### Server

- No per-frame or constant polling loop.
- Framework detection occurs once at startup.
- Command definitions are compiled once at startup.
- Recipient lists are calculated only when a message is sent.
- Cooldown cleanup must be bounded and infrequent, or use expiry-on-access.
- Webhook delivery must be asynchronous and non-blocking.

### Load target

The first performance target is stable behavior with at least 128 concurrent players. Architecture must not prevent higher OneSync player counts.

---

## 17. Reliability Requirements

- Missing logos must fall back to text initials.
- NUI load failure must produce a client console error and avoid trapping input focus.
- Resource restart must release NUI focus.
- Player disconnect must clear server-side transient state.
- Framework player unload must invalidate cached identity data.
- Invalid webhook settings must not stop the resource.
- A malformed message from another resource must not crash the client UI.

---

## 18. Developer API Requirements

### Client API

Required compatibility API plus custom exports:

- `addMessage(message)`
- `addSuggestion(name, help, params)`
- `setVisible(state)`
- `isInputOpen()`
- `clear()`

### Server API

Required compatibility API plus custom exports:

- `addMessage(target, message)`
- `registerMessageHook(callback)`
- `registerMode(modeData)`
- `sendSystemMessage(target, text, options)`
- `sendOrganizationMessage(source, organizationName, text, options)`
- `isMuted(source)`
- `mute(source, duration, reason)`
- `unmute(source)`

Custom send exports must execute the same validation and routing pipeline as commands unless an explicit trusted-internal option is used.

### Events

Custom events must use a consistent namespace:

```text
dex_chat:client:*
dex_chat:server:*
```

Internal-only events should not be network events.

---

## 19. Testing Requirements

### 19.1 Unit-style Lua tests

Test pure modules for:

- Configuration validation.
- Message sanitization.
- Command normalization.
- Cooldown logic.
- Recipient filtering.
- Grade rules.
- Organization authorization.

### 19.2 NUI tests

Test:

- Message rendering.
- Banner rendering.
- Missing assets.
- Suggestion navigation.
- Input cancellation and submission.
- History limits.
- Reduced motion.
- HTML/script payloads rendered as text.

### 19.3 Integration matrix

Required manual or automated integration coverage:

| Scenario | ESX | Qbox | QBCore | Standalone |
|---|---:|---:|---:|---:|
| Normal chat | Yes | Yes | Yes | Yes |
| Job command | Yes | Yes | Yes | N/A |
| Gang command | Configured adapter support | Yes | Yes | N/A |
| Duty requirement | Yes | Yes | Yes | N/A |
| Grade requirement | Yes | Yes | Yes | N/A |
| Same-bucket routing | Yes | Yes | Yes | Yes |
| Stock `chat:addMessage` | Yes | Yes | Yes | Yes |
| Server `addMessage` export | Yes | Yes | Yes | Yes |
| Suggestions | Yes | Yes | Yes | Yes |

### 19.4 Abuse tests

Test:

- Client attempts to spoof `organization = 'police'`.
- Non-Ballas player runs `/ballas`.
- Off-duty police runs `/police` when duty is required.
- Grade below minimum.
- Duplicate rapid submissions.
- Oversized payload.
- Table instead of string.
- HTML/script injection payload.
- Cross-bucket visibility.
- Unauthorized `/clearall`.
- Invalid custom template from another resource.

---

## 20. Acceptance Criteria for Version 1.0

Version 1.0 is acceptable only when all of the following are true:

- [ ] `dex_chat` starts successfully as `provide 'chat'`.
- [ ] The stock `chat` resource can remain stopped.
- [ ] Common `chat:addMessage` calls from existing resources render correctly.
- [ ] Client and server `addMessage` exports work.
- [ ] Suggestions can be added and removed.
- [ ] Normal text input works and never leaves NUI focus stuck.
- [ ] `/ballas` is usable by Ballas members only.
- [ ] `/vagos` is usable by Vagos members only when configured.
- [ ] `/police` is usable by valid police employees only.
- [ ] Job duty and grade rules are enforced server-side.
- [ ] Organization banners use server-selected themes.
- [ ] Proximity and bucket routing do not leak messages.
- [ ] Rate limits and maximum lengths are enforced.
- [ ] HTML/script content is displayed only as text.
- [ ] ESX, Qbox, and QBCore bridges pass their integration tests.
- [ ] English and Tagalog locale files are present.
- [ ] Discord logging does not expose webhook URLs to clients.
- [ ] Resource restart safely releases input focus.
- [ ] Installation and migration instructions are documented.
- [ ] No critical or high-severity security issue remains open.

---

## 21. Release Priority

### Must have

- Stock chat replacement compatibility.
- Custom NUI input and message list.
- Config-driven job and gang commands.
- Server-side membership, grade, duty, cooldown, and routing checks.
- ESX, Qbox, and QBCore bridges.
- Same-bucket routing.
- Sanitization and rate limiting.
- Configuration validation.

### Should have

- Discord logs.
- `/me`, `/do`, `/try`, `/ooc`.
- Staff announcements.
- Player UI preferences.
- English and Tagalog locale.
- NUI component tests.

### Could have after 1.0

- Persistent history.
- Direct messages.
- Admin UI.
- Database moderation history.
- Phone/radio integrations.
- Custom theme packs.

---

## 22. Definition of Done

A task is done only when:

1. Code is implemented in the correct module.
2. Security validation is server-authoritative.
3. Error paths are handled.
4. Configuration and locale keys are added.
5. Relevant tests pass.
6. Documentation is updated.
7. No debug print, secret, generated build artifact mistake, or dead code is left unintentionally.
8. The task's acceptance checks in `Task.md` are marked complete with evidence in the pull request description or test notes.
