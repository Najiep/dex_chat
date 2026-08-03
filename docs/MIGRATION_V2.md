# Migrating from dex_chat v1 to v2

## Before upgrading

1. Back up the current `dex_chat` folder and server configuration.
2. Confirm the stock Cfx `chat` resource is not started separately.
3. Test the v2 branch on a staging server before production.
4. Review any resource that registers custom chat modes or message hooks.

## Configuration changes

v2 adds these files:

- `config/themes.lua`
- `config/channels.lua`

Existing `config/organizations.lua`, framework selection and stock compatibility APIs remain supported.

`Config.NormalChat` and `Config.OOC` are retained as backward-compatible aliases, but new behavior should be configured in `Config.Channels.normal` and `Config.Channels.ooc`.

## New ACE permissions

```cfg
add_ace group.admin dex_chat.staff allow
add_ace group.admin dex_chat.clearall allow
add_ace group.admin dex_chat.mute allow
add_ace group.admin dex_chat.cooldown.bypass allow
add_ace group.admin dex_chat.filter.bypass allow
add_ace group.admin dex_chat.crossbucket allow
```

The old `dex_chat.staff` and `dex_chat.cooldown.bypass` nodes continue to work.

## Changed behavior

- Normal chat defaults to proximity scope in `Config.Channels.normal`.
- Private messages default to same-routing-bucket only.
- `/try` is randomized on the server.
- Advertisement money is removed only after validation and message hooks succeed.
- Repeated duplicate or burst messages can trigger a temporary mute.
- Discord logs are queued instead of firing all webhooks immediately.
- Player UI settings are stored locally using KVP.
- Raw `chat:addTemplate` HTML is not rendered.

## Testing checklist

- Open chat with `T` and submit normal proximity messages.
- Test OOC, ME, DO, TRY and advertisement commands.
- Verify advertisement payment on the selected framework/account.
- Verify police/EMS/mechanic and gang organization permissions.
- Verify job/gang chat only reaches matching members.
- Verify bucket isolation across every server instance.
- Verify `/pm` and `/reply`, including different-bucket rejection.
- Verify staff chat, `/clearall`, `/chatmute` and `/chatunmute` ACE rules.
- Verify custom resources still using `chat:addMessage`, `registerMessageHook` and `registerMode`.
- Test 16:9, ultrawide and 1280×720 UI layouts.
- Run the Lua tests in `tests/lua/`.

## Rollback

If staging reveals a compatibility problem:

1. Stop `dex_chat`.
2. Restore the backed-up v1 folder.
3. Restore the previous configuration.
4. Restart the server rather than hot-swapping both chat providers.
