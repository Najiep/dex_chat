# Dex Chat — Implementation Tasks

**Document status:** Active implementation plan  
**Depends on:** `Requirement.md`, `Design.md`  
**Target release:** 1.0.0

---

## 1. Execution Rules

This task list is ordered. Complete each phase gate before moving to the next phase unless a task is explicitly marked as parallel-safe.

### Development rules

- Use one active implementation agent and one main feature branch/PR at a time to avoid conflicting architecture changes.
- Do not edit the Cfx.re stock `chat` resource.
- Do not disable the stock chat on the production server until the compatibility gate passes.
- Keep framework-specific code inside `bridge/`.
- Keep all permissions, membership checks, routing, cooldowns, and presentation selection server-authoritative.
- Do not add a high-frequency idle loop.
- Do not use raw HTML rendering for player messages.
- Do not commit secrets, webhook URLs, or local server configuration.
- Every completed task must include its validation evidence in commit/PR notes.

### Task status legend

- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete
- `[!]` Blocked

### Priority legend

- **P0** — Required for a safe replacement.
- **P1** — Required for version 1.0.
- **P2** — Valuable after the core is stable.

---

## 2. Milestone Summary

| Milestone | Outcome | Release Gate |
|---|---|---|
| M0 | Repository and tooling ready | Buildable skeleton |
| M1 | Core validation and schema ready | Pure logic tests pass |
| M2 | Framework bridges ready | Identity tests pass |
| M3 | Stock compatibility ready | Existing resources render messages |
| M4 | Custom NUI ready | Input and rendering stable |
| M5 | Organization commands ready | `/ballas` and `/police` secured |
| M6 | Channels, routing, moderation ready | No cross-bucket leakage |
| M7 | Full test and migration ready | Stock chat can be stopped |
| M8 | 1.0 release ready | Security and performance gates pass |

---

# Phase 0 — Repository Governance and Baseline

## T0.1 — Confirm repository policy

**Priority:** P0  
**Dependencies:** None

- [ ] Confirm license and add `LICENSE`.
- [ ] Add `.gitignore` for Node, editor, build-cache, and local config files.
- [ ] Add `.editorconfig`.
- [ ] Add Lua formatting/lint configuration.
- [ ] Add TypeScript/ESLint configuration.
- [ ] Decide whether `web/dist/` is committed or generated in release CI.
- [ ] Document branch and commit conventions.

**Acceptance checks:**

- Repository contains no generated cache, secrets, or local server files.
- A new developer can identify the source/build policy from README.

## T0.2 — Create root documentation

**Priority:** P0  
**Dependencies:** T0.1

- [ ] Create `README.md` with product summary.
- [ ] Link `Requirement.md`, `Design.md`, and `Task.md`.
- [ ] Add development prerequisites.
- [ ] Add framework support matrix.
- [ ] Add clear warning not to run stock `chat` and `dex_chat` simultaneously.

**Acceptance checks:**

- README contains setup placeholders but does not claim unfinished features are complete.

## T0.3 — Define release/version policy

**Priority:** P1  
**Dependencies:** T0.1

- [ ] Adopt semantic versioning.
- [ ] Define message schema version.
- [ ] Define configuration schema version.
- [ ] Add `CHANGELOG.md`.

---

# Phase 1 — Resource Scaffold and Build System

## T1.1 — Create FiveM resource scaffold

**Priority:** P0  
**Dependencies:** Phase 0

- [ ] Create `fxmanifest.lua`.
- [ ] Set `fx_version 'cerulean'` and `game 'gta5'`.
- [ ] Add resource metadata.
- [ ] Add `provide 'chat'`.
- [ ] Define deterministic shared/client/server script order.
- [ ] Define `ui_page` and NUI files.
- [ ] Avoid hard framework dependencies.

**Acceptance checks:**

- `refresh` detects `dex_chat` as a valid resource.
- Resource starts with placeholder client/server files.
- Manifest does not report missing files.

## T1.2 — Create source directories

**Priority:** P0  
**Dependencies:** T1.1

- [ ] Create `config/`.
- [ ] Create `shared/`.
- [ ] Create `bridge/` adapters.
- [ ] Create `client/`.
- [ ] Create `server/`.
- [ ] Create `locales/`.
- [ ] Create `web/` source structure.
- [ ] Create `tests/` structure.

## T1.3 — Initialize NUI project

**Priority:** P0  
**Dependencies:** T1.2

- [ ] Initialize Vite + React + TypeScript.
- [ ] Add production build command.
- [ ] Add development browser/mock mode.
- [ ] Add type-check command.
- [ ] Add component test runner.
- [ ] Set NUI base path correctly for FiveM.

**Acceptance checks:**

- `npm ci` succeeds.
- `npm run build` succeeds.
- Built `index.html` loads in FiveM NUI without external CDN dependencies.

## T1.4 — Add continuous checks

**Priority:** P1  
**Dependencies:** T1.1, T1.3

- [ ] Add workflow for NUI install/build/type-check/test.
- [ ] Add Lua lint/test workflow when tooling is selected.
- [ ] Prevent accidental secret commits where practical.

---

## Gate M0 — Buildable Skeleton

Do not proceed until:

- [ ] FiveM recognizes the resource.
- [ ] Lua files load without syntax errors.
- [ ] NUI production build succeeds.
- [ ] Empty resource restart releases NUI focus.

---

# Phase 2 — Shared Types, Configuration, and Validation

## T2.1 — Define constants and enums

**Priority:** P0  
**Dependencies:** M0

- [ ] Define message kinds.
- [ ] Define routing scopes.
- [ ] Define organization types.
- [ ] Define hide states.
- [ ] Define error/rejection codes.
- [ ] Define schema versions.

## T2.2 — Define normalized Lua data contracts

**Priority:** P0  
**Dependencies:** T2.1

- [ ] Add annotations/types for normalized player data.
- [ ] Add organization data type.
- [ ] Add canonical message type.
- [ ] Add routing context type.
- [ ] Add command definition type.
- [ ] Add log event type.

## T2.3 — Create base configuration

**Priority:** P0  
**Dependencies:** T2.1

- [ ] Add framework and locale settings.
- [ ] Add input limits and key mapping.
- [ ] Add UI history and visibility settings.
- [ ] Add routing bucket settings.
- [ ] Add default channel settings.
- [ ] Add security/rate-limit settings.
- [ ] Add logging settings without real webhook values.

## T2.4 — Create organization configuration

**Priority:** P0  
**Dependencies:** T2.3

- [ ] Add Ballas example using `/ballas`.
- [ ] Add Vagos example using `/vagos`.
- [ ] Add Police example using `/police`, `/pd`, `/lspd`.
- [ ] Add Ambulance example using `/ambulance`, `/ems`.
- [ ] Add Mechanic example using `/mechanic`, `/mech`.
- [ ] Include grade, duty, scope, cooldown, anonymity, and theme settings.
- [ ] Keep examples easy to remove or disable.

## T2.5 — Implement configuration validator

**Priority:** P0  
**Dependencies:** T2.2, T2.4

- [ ] Validate framework values.
- [ ] Validate organization names/types.
- [ ] Validate commands and aliases.
- [ ] Detect duplicate command collisions.
- [ ] Validate reserved names.
- [ ] Validate grade rules.
- [ ] Validate scopes.
- [ ] Validate colors.
- [ ] Validate asset paths.
- [ ] Validate durations and message lengths.
- [ ] Disable invalid organizations individually when safe.
- [ ] Stop startup on critical core configuration errors.

## T2.6 — Compile runtime configuration

**Priority:** P0  
**Dependencies:** T2.5

- [ ] Normalize commands to lowercase.
- [ ] Build command-to-organization lookup.
- [ ] Build alias lookup.
- [ ] Build immutable theme definitions.
- [ ] Build enabled channel table.
- [ ] Print safe startup summary.

## T2.7 — Implement localization core

**Priority:** P1  
**Dependencies:** T2.3

- [ ] Add locale resolver.
- [ ] Add English locale.
- [ ] Add Tagalog locale.
- [ ] Add English fallback for missing keys.
- [ ] Ensure every player-facing error uses locale keys.

---

# Phase 3 — Sanitization, Rate Limits, and Pure Services

## T3.1 — Implement server sanitizer

**Priority:** P0  
**Dependencies:** T2.2

- [ ] Reject non-string values.
- [ ] Reject excessive byte length before expensive processing.
- [ ] Remove null bytes.
- [ ] Remove unsafe control characters.
- [ ] Normalize tabs/newlines to spaces.
- [ ] Trim and collapse whitespace as configured.
- [ ] Enforce final length.
- [ ] Preserve normal Unicode roleplay text.

**Required tests:**

- [ ] Empty input.
- [ ] Whitespace-only input.
- [ ] HTML/script payload.
- [ ] Embedded null byte.
- [ ] Multiline paste.
- [ ] Long ASCII input.
- [ ] Long multibyte input.
- [ ] Normal Tagalog text.

## T3.2 — Implement message ID generator

**Priority:** P0  
**Dependencies:** T2.2

- [ ] Generate unique IDs without trusting clients.
- [ ] Avoid predictable collisions during rapid sends.
- [ ] Keep IDs compact enough for NUI state.

## T3.3 — Implement rate limiter

**Priority:** P0  
**Dependencies:** T2.3

- [ ] Add normal chat bucket.
- [ ] Add organization chat bucket.
- [ ] Add malformed request bucket.
- [ ] Add per-command cooldown.
- [ ] Add per-organization global cooldown.
- [ ] Add ACE cooldown bypass.
- [ ] Add escalating temporary mute option.
- [ ] Clear player state on disconnect.
- [ ] Use expiry-on-access or bounded cleanup.

## T3.4 — Implement moderation service

**Priority:** P1  
**Dependencies:** T3.1

- [ ] Add disabled-by-default blocked pattern list.
- [ ] Add replace/reject/log-only modes.
- [ ] Add ACE bypass.
- [ ] Add temporary mute functions.
- [ ] Add external moderation callback registration.

## T3.5 — Implement canonical message builder

**Priority:** P0  
**Dependencies:** T2.2, T3.1, T3.2

- [ ] Build versioned message payload.
- [ ] Separate sender, organization, content, and presentation.
- [ ] Apply safe defaults.
- [ ] Ensure no webhook, identifier, permission, or internal config leaks to clients.

---

## Gate M1 — Pure Logic Stable

- [ ] Configuration validator tests pass.
- [ ] Sanitizer tests pass.
- [ ] Rate-limit tests pass.
- [ ] Message schema tests pass.
- [ ] No core service depends directly on ESX/Qbox/QBCore.

---

# Phase 4 — Framework Bridge Layer

## T4.1 — Implement bridge selector

**Priority:** P0  
**Dependencies:** M1

- [ ] Support `auto`, `esx`, `qbox`, `qbcore`, `standalone`.
- [ ] Apply configurable detection priority.
- [ ] Warn when multiple frameworks are active.
- [ ] Fail clearly when an explicitly selected framework is unavailable.
- [ ] Do not poll continuously.

## T4.2 — Implement standalone bridge

**Priority:** P0  
**Dependencies:** T4.1

- [ ] Resolve FiveM player name.
- [ ] Return safe empty job/gang data.
- [ ] Support ACE-based staff channels.
- [ ] Return safe failure for unsupported money operations.

## T4.3 — Implement ESX bridge

**Priority:** P0  
**Dependencies:** T4.1

- [ ] Resolve player by source.
- [ ] Resolve stable character identifier.
- [ ] Resolve character name.
- [ ] Normalize active job.
- [ ] Normalize grade/grade label.
- [ ] Normalize duty state using configured ESX server behavior.
- [ ] Add configurable gang provider modes.
- [ ] Add optional account balance/removal methods.
- [ ] Handle player unload and framework restart safely.

**Required ESX tests:**

- [ ] Unemployed player.
- [ ] Police grade 0.
- [ ] Police higher grade.
- [ ] On-duty/off-duty transition.
- [ ] Missing gang provider.
- [ ] Player disconnect during message processing.

## T4.4 — Implement Qbox bridge

**Priority:** P0  
**Dependencies:** T4.1

- [ ] Resolve player data using supported exports.
- [ ] Normalize active job.
- [ ] Normalize active gang.
- [ ] Normalize nested grade fields.
- [ ] Normalize duty state.
- [ ] Handle multijob/multigang policy explicitly.
- [ ] Add optional money operations.
- [ ] Invalidate caches on job/gang/duty updates.

## T4.5 — Implement QBCore bridge

**Priority:** P0  
**Dependencies:** T4.1

- [ ] Resolve `PlayerData` safely.
- [ ] Normalize job fields.
- [ ] Normalize gang fields.
- [ ] Normalize grade level/name.
- [ ] Normalize `onduty`.
- [ ] Add optional money operations.
- [ ] Invalidate caches on framework updates.

## T4.6 — Add bridge contract tests

**Priority:** P0  
**Dependencies:** T4.2–T4.5

- [ ] Create common contract test cases.
- [ ] Mock each framework shape.
- [ ] Confirm all adapters return identical normalized types.
- [ ] Confirm missing fields do not crash core services.

---

## Gate M2 — Framework Identity Ready

- [ ] ESX identity/job tests pass.
- [ ] Qbox job/gang tests pass.
- [ ] QBCore job/gang tests pass.
- [ ] Standalone normal/staff chat can operate.
- [ ] Core modules contain no framework-specific field access.

---

# Phase 5 — Stock Chat Compatibility

## T5.1 — Implement client message compatibility

**Priority:** P0  
**Dependencies:** M2

- [ ] Register `chatMessage` deprecated event.
- [ ] Register `chat:addMessage`.
- [ ] Normalize string and table messages.
- [ ] Queue messages until NUI is ready.
- [ ] Bound the pre-ready queue.

## T5.2 — Implement suggestion compatibility

**Priority:** P0  
**Dependencies:** T5.1

- [ ] Register `chat:addSuggestion`.
- [ ] Register `chat:addSuggestions`.
- [ ] Register `chat:removeSuggestion`.
- [ ] Export client `addSuggestion`.
- [ ] Preserve parameter help where valid.

## T5.3 — Implement clear compatibility

**Priority:** P0  
**Dependencies:** T5.1

- [ ] Register `chat:clear`.
- [ ] Clear only NUI history.
- [ ] Preserve logs.

## T5.4 — Implement template compatibility

**Priority:** P0  
**Dependencies:** T5.1

- [ ] Register `chat:addTemplate`.
- [ ] Store templates by ID.
- [ ] Parse safe positional placeholders.
- [ ] Never use raw `innerHTML`.
- [ ] Fall back to standard card for unsupported templates.
- [ ] Add debug diagnostics.

## T5.5 — Implement modes compatibility

**Priority:** P0  
**Dependencies:** T5.1

- [ ] Register client `chat:addMode`.
- [ ] Register client `chat:removeMode`.
- [ ] Implement server `registerMode` export.
- [ ] Apply optional ACE access.
- [ ] Remove modes when owner resource stops.

## T5.6 — Implement server addMessage export

**Priority:** P0  
**Dependencies:** T3.5

- [ ] Support `addMessage(target, message)`.
- [ ] Support omitted target as broadcast behavior.
- [ ] Validate target and payload.
- [ ] Preserve common message fields.
- [ ] Reject malformed payload safely.

## T5.7 — Implement message hook export

**Priority:** P0  
**Dependencies:** T5.6

- [ ] Add `registerMessageHook`.
- [ ] Support update, cancel, ACE route, and target routing controls.
- [ ] Track owner resource.
- [ ] Remove hooks on resource stop.
- [ ] Revalidate payload and targets after hooks.

## T5.8 — Implement chat init and command refresh

**Priority:** P0  
**Dependencies:** T5.2

- [ ] Implement `chat:init` handshake.
- [ ] Enumerate registered commands where supported.
- [ ] Filter suggestions by ACE.
- [ ] Refresh after resource start/stop with debounce.

## T5.9 — Implement normal message entry

**Priority:** P0  
**Dependencies:** T3.1, T3.3, T5.1

- [ ] Handle `_chat:messageEntered`.
- [ ] Ignore client-provided author identity.
- [ ] Route through canonical message service.
- [ ] Implement console `say`.
- [ ] Implement command fallback behavior.
- [ ] Add configurable join/leave messages.

## T5.10 — Create compatibility test resource

**Priority:** P0  
**Dependencies:** T5.1–T5.9

- [ ] Test client `chat:addMessage`.
- [ ] Test server `TriggerClientEvent('chat:addMessage')`.
- [ ] Test client export.
- [ ] Test server export.
- [ ] Test suggestions.
- [ ] Test clear.
- [ ] Test template fallback.
- [ ] Test hook update/cancel/routing.
- [ ] Test modes.

---

## Gate M3 — Compatibility Ready

- [ ] At least three existing server resources using stock chat APIs work without code changes.
- [ ] Client/server addMessage exports pass.
- [ ] Suggestions and clear pass.
- [ ] Hooks and modes pass.
- [ ] Unsupported templates fail safely rather than crash or inject HTML.
- [ ] Stock chat remains enabled only outside the test server during this gate.

---

# Phase 6 — NUI Input and Rendering

## T6.1 — Define TypeScript message contracts

**Priority:** P0  
**Dependencies:** M1

- [ ] Mirror schema version 1.
- [ ] Add runtime guards for NUI payloads.
- [ ] Reject unknown critical schema versions safely.

## T6.2 — Implement NUI bridge utilities

**Priority:** P0  
**Dependencies:** T1.3

- [ ] Add typed NUI event listener.
- [ ] Add typed callback/fetch helper.
- [ ] Add browser mock support.
- [ ] Handle malformed messages without breaking React tree.

## T6.3 — Implement UI store

**Priority:** P0  
**Dependencies:** T6.1, T6.2

- [ ] Store messages.
- [ ] Enforce history limit.
- [ ] Store suggestions/modes.
- [ ] Store input state.
- [ ] Store visibility and preferences.
- [ ] Deduplicate message IDs.

## T6.4 — Implement normal message cards

**Priority:** P0  
**Dependencies:** T6.3

- [ ] Render author, content, timestamp, and channel badge.
- [ ] Render content only as text.
- [ ] Support system/error/console styles.
- [ ] Support multiline wrapping without overflow.

## T6.5 — Implement organization banner cards

**Priority:** P0  
**Dependencies:** T6.3

- [ ] Render local logo/background assets.
- [ ] Render text fallback initials.
- [ ] Apply validated CSS variables.
- [ ] Support compact and expanded layouts.
- [ ] Show configured sender/grade fields.
- [ ] Handle long text and ultra-wide ratios.
- [ ] Add local allowlisted sound support.

## T6.6 — Implement message list behavior

**Priority:** P0  
**Dependencies:** T6.4, T6.5

- [ ] Auto-scroll when near bottom.
- [ ] Preserve manual scroll position.
- [ ] Remove expired transient messages.
- [ ] Avoid one timer per message where possible.
- [ ] Enforce bounded DOM count.

## T6.7 — Implement chat input

**Priority:** P0  
**Dependencies:** T6.3

- [ ] Open on registered key mapping.
- [ ] Focus input reliably.
- [ ] Submit with Enter.
- [ ] Cancel with Escape.
- [ ] Show character limit.
- [ ] Normalize pasted multiline text.
- [ ] Support command history.
- [ ] Support selected mode.

## T6.8 — Implement suggestions UI

**Priority:** P0  
**Dependencies:** T6.7

- [ ] Prefix-match commands.
- [ ] Display command help and parameters.
- [ ] Keyboard navigation.
- [ ] Mouse selection.
- [ ] Do not display ACE-restricted commands sent for another player.

## T6.9 — Implement visibility preferences

**Priority:** P1  
**Dependencies:** T6.3

- [ ] Show when active.
- [ ] Always show.
- [ ] Always hide.
- [ ] Persist via resource KVP.
- [ ] Add UI scale/opacity settings.
- [ ] Add reduced-motion and sound controls.

## T6.10 — Implement client focus lifecycle

**Priority:** P0  
**Dependencies:** T6.7

- [ ] Release focus after submit.
- [ ] Release focus after cancel.
- [ ] Release focus on resource stop.
- [ ] Recover if NUI fails to load.
- [ ] Prevent duplicate open state.

## T6.11 — Add NUI tests

**Priority:** P0  
**Dependencies:** T6.4–T6.10

- [ ] Script payload displays as text.
- [ ] Missing logo uses fallback.
- [ ] Banner colors are token values only.
- [ ] Long message wraps.
- [ ] Suggestion navigation works.
- [ ] Escape cancels.
- [ ] History limit is enforced.
- [ ] Reduced motion disables non-essential animations.

---

## Gate M4 — Custom UI Ready

- [ ] NUI works at 1280×720, 1920×1080, and an ultra-wide resolution.
- [ ] Focus never remains stuck after submit/cancel/restart.
- [ ] HTML/script payloads are not executed.
- [ ] Message list remains bounded.
- [ ] Banner fallback works without image assets.
- [ ] Idle resmon does not show a permanent frame loop caused by chat.

---

# Phase 7 — Routing and Channel Services

## T7.1 — Implement routing service

**Priority:** P0  
**Dependencies:** M2, M4

- [ ] Implement global scope.
- [ ] Implement bucket scope.
- [ ] Implement proximity scope.
- [ ] Implement job scope.
- [ ] Implement gang scope.
- [ ] Implement ACE scope.
- [ ] Implement validated custom scope.
- [ ] Deduplicate and validate recipients.

## T7.2 — Implement routing bucket isolation

**Priority:** P0  
**Dependencies:** T7.1

- [ ] Read sender bucket on server.
- [ ] Read target buckets on server.
- [ ] Default public organization announcements to same bucket.
- [ ] Require explicit permission/config for cross-bucket routing.
- [ ] Test bucket 0 and non-zero buckets.

## T7.3 — Implement normal chat channel

**Priority:** P0  
**Dependencies:** T7.1

- [ ] Support configured global/bucket/proximity scope.
- [ ] Use trusted sender identity.
- [ ] Apply normal rate limit.
- [ ] Run hooks and moderation.

## T7.4 — Implement `/ooc`

**Priority:** P1  
**Dependencies:** T7.1

- [ ] Configurable scope.
- [ ] Independent cooldown.
- [ ] Dedicated presentation style.

## T7.5 — Implement `/me` and `/do`

**Priority:** P1  
**Dependencies:** T7.1

- [ ] Proximity and same-bucket routing.
- [ ] Dedicated roleplay presentation.
- [ ] Optional export/event for 3D text integration.
- [ ] No mandatory frame loop in core chat.

## T7.6 — Implement `/try`

**Priority:** P1  
**Dependencies:** T7.5

- [ ] Server chooses success/failure.
- [ ] Result is included in canonical message.
- [ ] Same routing/security as roleplay messages.

## T7.7 — Implement staff announcements

**Priority:** P1  
**Dependencies:** T7.1

- [ ] `/staff` command.
- [ ] ACE permission.
- [ ] Configurable named/anonymous sender.
- [ ] Optional cross-bucket scope.
- [ ] Mandatory moderation/log event.

## T7.8 — Implement clear commands

**Priority:** P1  
**Dependencies:** M4

- [ ] `/clear` local only.
- [ ] `/clearall` ACE protected.
- [ ] Same-bucket or global behavior configurable for clearall.

## T7.9 — Implement advertisements

**Priority:** P2  
**Dependencies:** T7.1, bridge money APIs

- [ ] `/ad` command.
- [ ] Configurable price/account.
- [ ] Server balance and transaction validation.
- [ ] Job whitelist option.
- [ ] Independent cooldown.
- [ ] Disable payment requirement in standalone.

---

# Phase 8 — Organization Commands and Banners

## T8.1 — Implement command registry

**Priority:** P0  
**Dependencies:** T2.6

- [ ] Register primary organization commands.
- [ ] Register aliases using direct shared handler closures.
- [ ] Preserve player source.
- [ ] Add localized usage suggestions.
- [ ] Remove/rebuild commands safely on resource restart.

## T8.2 — Implement organization authorization

**Priority:** P0  
**Dependencies:** M2

- [ ] Compare exact normalized membership name.
- [ ] Enforce minimum grade.
- [ ] Enforce allowed grade list.
- [ ] Enforce boss-only.
- [ ] Enforce job duty.
- [ ] Return localized rejection reasons.
- [ ] Log spoof/unauthorized attempts.

## T8.3 — Implement organization message service

**Priority:** P0  
**Dependencies:** T3.5, T7.1, T8.2

- [ ] Resolve organization from command registry, not client payload.
- [ ] Sanitize text.
- [ ] Apply rate limits/cooldowns.
- [ ] Resolve sender display mode.
- [ ] Resolve server-owned theme.
- [ ] Build canonical banner payload.
- [ ] Run hooks with revalidation.
- [ ] Route recipients.
- [ ] Log delivered/rejected outcome.

## T8.4 — Implement Ballas command acceptance scenario

**Priority:** P0  
**Dependencies:** T8.3

- [ ] Ballas member can run `/ballas [message]`.
- [ ] Non-Ballas player is rejected.
- [ ] Ballas banner uses configured purple theme.
- [ ] Anonymous setting hides character identity when enabled.
- [ ] Same-bucket behavior passes.
- [ ] Cooldown behavior passes.

## T8.5 — Implement Police command acceptance scenario

**Priority:** P0  
**Dependencies:** T8.3

- [ ] Police employee can run `/police [message]`.
- [ ] `/pd` and `/lspd` call the same handler.
- [ ] Non-police player is rejected.
- [ ] Off-duty police is rejected when required.
- [ ] Grade restrictions pass.
- [ ] Character name and grade display correctly.
- [ ] Same-bucket behavior passes.

## T8.6 — Validate remaining examples

**Priority:** P1  
**Dependencies:** T8.3

- [ ] `/vagos`.
- [ ] `/ambulance` and `/ems`.
- [ ] `/mechanic` and `/mech`.
- [ ] Disabled organization command is not registered.
- [ ] Duplicate alias is rejected during startup.

## T8.7 — Add trusted server export

**Priority:** P1  
**Dependencies:** T8.3

- [ ] Add `sendOrganizationMessage` export.
- [ ] Default to normal authorization pipeline.
- [ ] Define explicit trusted-internal mode.
- [ ] Ensure trusted mode cannot be called from clients.
- [ ] Validate message and theme regardless of trust mode.

---

## Gate M5 — Organization System Ready

- [ ] `/ballas` passes all positive/negative tests.
- [ ] `/police` passes all positive/negative tests.
- [ ] Client organization spoof attempt fails.
- [ ] Alias handling preserves source and permissions.
- [ ] Banner presentation is server selected.
- [ ] Same-bucket routing has no leak.

---

# Phase 9 — Logging, Moderation, and Administration

## T9.1 — Implement structured console logger

**Priority:** P1  
**Dependencies:** T3.5

- [ ] Standard log categories/outcomes.
- [ ] Safe player/context formatting.
- [ ] Debug details only when enabled.
- [ ] No secret output.

## T9.2 — Implement Discord logger

**Priority:** P1  
**Dependencies:** T9.1

- [ ] Server-only webhook setting.
- [ ] Mention escaping.
- [ ] Field truncation.
- [ ] Independent failure handling.
- [ ] Independent rate control.
- [ ] Organization-specific webhook override option.

## T9.3 — Add custom logger API

**Priority:** P2  
**Dependencies:** T9.1

- [ ] Register custom log callback/export.
- [ ] Protect against callback errors.

## T9.4 — Implement mute administration API

**Priority:** P1  
**Dependencies:** T3.4

- [ ] `mute` export.
- [ ] `unmute` export.
- [ ] `isMuted` export.
- [ ] ACE-protected commands optionally included.
- [ ] Log moderation changes.

## T9.5 — Add rejected-attempt logging

**Priority:** P1  
**Dependencies:** T8.2

- [ ] Not member.
- [ ] Off duty.
- [ ] Grade too low.
- [ ] Cooldown abuse.
- [ ] Malformed payload.
- [ ] Cross-bucket bypass attempt.
- [ ] Unauthorized clearall/staff action.

---

# Phase 10 — Performance and Reliability Hardening

## T10.1 — Remove unnecessary loops

**Priority:** P0  
**Dependencies:** Core implementation

- [ ] Audit every `CreateThread`.
- [ ] Document why each loop exists.
- [ ] Replace polling with events where possible.
- [ ] Ensure no idle `Wait(0)` chat loop.
- [ ] Ensure message expiry scheduler is bounded.

## T10.2 — Bound all in-memory collections

**Priority:** P0  
**Dependencies:** Core implementation

- [ ] NUI message history.
- [ ] Input history.
- [ ] Pre-ready queue.
- [ ] Rate-limit entries.
- [ ] Template registry.
- [ ] Hooks/modes lifecycle.
- [ ] Temporary logs/queues.

## T10.3 — Handle resource lifecycle

**Priority:** P0  
**Dependencies:** Core implementation

- [ ] Client resource stop releases focus.
- [ ] Server resource stop clears transient state.
- [ ] Owner resource stop removes hooks/modes.
- [ ] Framework restart behavior is defined.
- [ ] NUI reload queues safely.

## T10.4 — Handle disconnect races

**Priority:** P0  
**Dependencies:** T7.1, T8.3

- [ ] Player disconnect during identity lookup.
- [ ] Player disconnect during routing.
- [ ] Target disconnect before delivery.
- [ ] Source changes job/gang during command processing.
- [ ] Logger handles unavailable player context.

## T10.5 — Profile client and server

**Priority:** P0  
**Dependencies:** M5

- [ ] Measure idle client resmon.
- [ ] Measure input-open resmon.
- [ ] Measure burst of normal messages.
- [ ] Measure organization broadcast to test population.
- [ ] Inspect NUI memory after history limit cycles.
- [ ] Record results in release notes.

---

## Gate M6 — Secure Routing and Stability

- [ ] No cross-bucket leakage in normal, proximity, job, gang, and banner tests.
- [ ] No unbounded runtime collection found.
- [ ] No permanent unnecessary frame loop found.
- [ ] Disconnect/restart tests do not produce stuck focus or crashes.
- [ ] Logging failure does not block message delivery.

---

# Phase 11 — Full Integration and Abuse Testing

## T11.1 — Build framework integration matrix

**Priority:** P0  
**Dependencies:** M6

Run the required scenarios on:

- [ ] ESX Legacy.
- [ ] Qbox.
- [ ] QBCore.
- [ ] Standalone.

Scenarios:

- [ ] Normal chat.
- [ ] Stock addMessage event.
- [ ] Client/server addMessage exports.
- [ ] Suggestions.
- [ ] Job command.
- [ ] Gang command where supported/configured.
- [ ] Grade validation.
- [ ] Duty validation.
- [ ] Bucket routing.
- [ ] Resource restart.

## T11.2 — Run security abuse suite

**Priority:** P0  
**Dependencies:** M6

- [ ] Client sends fake organization name.
- [ ] Client sends fake grade/duty.
- [ ] Client sends target list.
- [ ] Client sends ready-made presentation/theme.
- [ ] Client sends table instead of text.
- [ ] Client sends oversized payload.
- [ ] Client sends null/control characters.
- [ ] Client sends script/HTML/CSS payload.
- [ ] Client spams valid commands.
- [ ] Client spams malformed events.
- [ ] Client attempts unauthorized cross-bucket message.
- [ ] Client attempts unauthorized staff/clearall action.

## T11.3 — Test third-party compatibility

**Priority:** P0  
**Dependencies:** M3, M6

- [ ] Inventory/resource system chat message.
- [ ] Admin resource chat message.
- [ ] Framework command suggestion.
- [ ] Resource using `exports.chat:addMessage`.
- [ ] Resource registering a hook.
- [ ] Resource registering a mode.
- [ ] Document unsupported unsafe-template edge cases.

## T11.4 — UI compatibility testing

**Priority:** P0  
**Dependencies:** M4

- [ ] 1280×720.
- [ ] 1920×1080.
- [ ] 2560×1440.
- [ ] 21:9.
- [ ] 32:9 where available.
- [ ] UI scale changes.
- [ ] Reduced motion.
- [ ] Sound disabled.
- [ ] Logo missing/corrupt.
- [ ] Very long organization label.

## T11.5 — Load testing

**Priority:** P1  
**Dependencies:** M6

- [ ] Simulate message bursts.
- [ ] Validate rate limiter under burst.
- [ ] Validate routing at target player count.
- [ ] Validate webhook backlog behavior.
- [ ] Verify no material memory growth after repeated history turnover.

---

## Gate M7 — Safe Stock Chat Replacement

Only after this gate may production configuration stop stock `chat`.

- [ ] Compatibility suite passes.
- [ ] Framework matrix passes for enabled server framework(s).
- [ ] Abuse suite passes.
- [ ] Routing bucket suite passes.
- [ ] Focus/restart suite passes.
- [ ] Rollback procedure has been tested on staging.
- [ ] Server owner has backed up the stock chat resource/config.

---

# Phase 12 — Installation, Migration, and Release

## T12.1 — Write installation guide

**Priority:** P0  
**Dependencies:** M7

- [ ] Required files and build artifacts.
- [ ] Resource placement.
- [ ] Framework selection.
- [ ] Organization configuration.
- [ ] Asset placement.
- [ ] ACE permissions.
- [ ] Server.cfg order.
- [ ] Clear warning against simultaneous chat providers.

## T12.2 — Write migration guide

**Priority:** P0  
**Dependencies:** M7

- [ ] Backup steps.
- [ ] Staging test steps.
- [ ] Remove/comment `ensure chat`.
- [ ] Check category-level starts such as `[gameplay]`.
- [ ] Ensure `dex_chat` in correct order.
- [ ] Verify dependent resources.
- [ ] Rollback steps.

## T12.3 — Write configuration guide

**Priority:** P1  
**Dependencies:** M5

- [ ] Create a new job banner.
- [ ] Create a new gang banner.
- [ ] Add aliases.
- [ ] Configure grade and duty rules.
- [ ] Configure public/internal/bucket scopes.
- [ ] Configure cooldowns.
- [ ] Configure logging.
- [ ] Configure ESX gang provider.

## T12.4 — Add developer API documentation

**Priority:** P1  
**Dependencies:** M3, M5

- [ ] Compatibility events.
- [ ] Compatibility exports.
- [ ] Custom client exports.
- [ ] Custom server exports.
- [ ] Hook API.
- [ ] Mode API.
- [ ] Message schema.
- [ ] Trusted internal message rules.

## T12.5 — Prepare release package

**Priority:** P0  
**Dependencies:** T12.1–T12.4

- [ ] Build NUI production bundle.
- [ ] Exclude development/test-only files as defined.
- [ ] Include default local assets or fallbacks.
- [ ] Verify manifest file list.
- [ ] Verify no secrets.
- [ ] Add changelog entry.
- [ ] Tag version `v1.0.0` after final approval.

## T12.6 — Final security review

**Priority:** P0  
**Dependencies:** T11.2, T12.5

- [ ] Review all network events.
- [ ] Review all exports callable by other resources.
- [ ] Review all client payload handling.
- [ ] Review hook/custom callback trust boundaries.
- [ ] Review asset path validation.
- [ ] Review webhook/log redaction.
- [ ] Review routing and ACE checks.
- [ ] Resolve all critical/high findings.

## T12.7 — Final performance review

**Priority:** P0  
**Dependencies:** T10.5, T12.5

- [ ] Record idle and active resource measurements.
- [ ] Check server hitch warnings during burst test.
- [ ] Check NUI memory.
- [ ] Check message routing at target population.
- [ ] Resolve major regressions.

---

## Gate M8 — Version 1.0 Ready

- [ ] All P0 tasks complete.
- [ ] All required P1 tasks complete or explicitly deferred with reason.
- [ ] No critical/high security issue open.
- [ ] Stock compatibility verified.
- [ ] ESX/Qbox/QBCore status accurately documented.
- [ ] `/ballas` and `/police` acceptance scenarios pass.
- [ ] Routing bucket isolation passes.
- [ ] Installation and rollback are tested.
- [ ] NUI build and source are reproducible.
- [ ] Release notes include known limitations.

---

# 13. Suggested Commit Sequence

Use small, reviewable commits in this order:

1. `chore: scaffold dex_chat resource`
2. `chore: initialize chat nui`
3. `feat: add shared chat schemas and config validation`
4. `feat: add sanitization and rate limiting`
5. `feat: add framework bridge interface`
6. `feat: add esx bridge`
7. `feat: add qbox and qbcore bridges`
8. `feat: add stock chat compatibility layer`
9. `feat: add custom chat nui input and messages`
10. `feat: add server routing service`
11. `feat: add organization command system`
12. `feat: add job and gang banner ui`
13. `feat: add roleplay and staff channels`
14. `feat: add moderation and logging`
15. `test: add compatibility and abuse coverage`
16. `docs: add installation and migration guides`
17. `chore: prepare v1.0.0 release`

Do not combine the entire implementation into one unreviewable commit.

---

# 14. Pull Request Checklist

Every implementation PR must answer:

- [ ] Which tasks are completed?
- [ ] Which requirements are satisfied?
- [ ] What security boundary changed?
- [ ] What framework(s) were tested?
- [ ] What stock chat compatibility was tested?
- [ ] What routing bucket scenarios were tested?
- [ ] What NUI build/test commands passed?
- [ ] What manual FiveM tests were performed?
- [ ] Are there migrations or configuration changes?
- [ ] Is rollback possible?
- [ ] Are screenshots or recordings included for UI changes?

---

# 15. Immediate Next Sprint

The first implementation sprint should complete only the safe foundation:

- [ ] T0.1 Repository policy.
- [ ] T0.2 Root README.
- [ ] T1.1 FiveM scaffold.
- [ ] T1.2 Source directories.
- [ ] T1.3 NUI project.
- [ ] T2.1 Constants.
- [ ] T2.2 Data contracts.
- [ ] T2.3 Base configuration.
- [ ] T2.4 Organization examples.
- [ ] T2.5 Configuration validator.
- [ ] T3.1 Sanitizer.
- [ ] T3.3 Rate limiter.

**Sprint exit condition:** The resource starts, the NUI builds, configuration compiles safely, and pure security logic has tests. Do not remove the stock chat during this sprint.
