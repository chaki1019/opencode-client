# opencode-mobile-push

An [OpenCode](https://opencode.ai) v2 plugin that notifies your phone when
the agent finishes, stops on an error, or is waiting for a permission or an
answer. It works with the opencode-mobile app.

## Setup

1. Add the plugin to `~/.config/opencode/opencode.json` (or `opencode.jsonc`) and restart OpenCode:

```jsonc
"plugins": ["opencode-mobile-push"]
```

2. In the app, connect to your OpenCode server, open the bell on the
   projects screen and turn on notifications for that server.

On first start the plugin creates a pairing key and saves it to
`~/.config/opencode/opencode-mobile-push.json` (readable only by you). The
app reads that key through the OpenCode server, so nothing has to be copied
by hand, and every phone that connects to this computer uses the same key.
Notifications go through the public relay at `https://relay.opencodemobile.app`.

To pin a version, use `"opencode-mobile-push@0.3.0"`.

To use your own relay, or a key you choose, pass them as options:

```jsonc
"plugins": [
  {
    "package": "opencode-mobile-push",
    "options": { "relay": "https://<your-relay>", "key": "<pairing key>" }
  }
]
```

Without npm, copy `opencode-mobile-push.js` to `~/.config/opencode/plugins/`
(OpenCode loads that folder by itself). The settings file works the same way:

```json
{ "relay": "https://<your-relay>", "key": "<pairing key>" }
```

Options given in `opencode.json` / `opencode.jsonc` take precedence over this file.

### Options

All default to `true`.

| Option | Effect |
|---|---|
| `includeTitle` | Include the session title and error text (encrypted) |
| `notifyOnComplete` | The agent finished its turn |
| `notifyOnError` | The turn stopped on an error |
| `notifyOnPermission` | The agent is waiting for a permission |
| `notifyOnQuestion` | The agent is waiting for an answer |

## Privacy

The relay never sees what a notification says. Two keys are derived from the
pairing key with HKDF-SHA256: an auth token the relay knows (and stores only
as a hash), and an encryption key it never gets. The project name and session
title are sealed with AES-256-GCM and opened only on the phone. The relay
sees the kind of event and the session ID.

Subagent sessions are not reported, and the same notification is not sent
twice within 15 seconds.

## License

MIT
