# opencode-mobile-push

An [OpenCode](https://opencode.ai) v2 plugin that notifies your phone when
the agent finishes, stops on an error, or is waiting for a permission or an
answer. It works with the opencode-client mobile app.

## Setup

1. In the app, connect to your OpenCode server, open the bell on the
   projects screen and turn on notifications for that server.
2. Add the snippet the app shows to `~/.config/opencode/opencode.json` and
   restart OpenCode:

```jsonc
"plugins": [
  {
    "package": "opencode-mobile-push",
    "options": {
      "relay": "<relay URL shown in the app>",
      "key": "<pairing key shown in the app>"
    }
  }
]
```

To pin a version, use `"opencode-mobile-push@0.1.0"`. Without npm, copy
`opencode-mobile-push.js` to `~/.config/opencode/plugins/` and use
`"package": "./plugins/opencode-mobile-push.js"` instead.

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
