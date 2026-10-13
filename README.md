# ackt

One feed for your Mattermost conversations, in the terminal: every team and
DM side by side, triaged so what needs you comes first, gathered into
contexts, and - when you allow it - worked on by Claude.

This repository holds ackt's releases and its installer. The source is not
public.

## Install

macOS or Linux, amd64 or arm64:

```sh
curl -fsSL https://raw.githubusercontent.com/isacikgoz/ackt-releases/main/install.sh | sh
```

The installer downloads the newest release, pre-releases included
(`ACKT_VERSION=<tag>` picks another), checks its checksum, puts `ackt` in
`~/.local/bin` and its plugins in `~/.local/share/ackt/bin`, and starts the
daemon in the background: a launchd agent on macOS, a systemd user service
on Linux. Running it again upgrades in place. Nothing is written outside
your home directory.

Optional, picked up when installed:

- [Claude Code](https://claude.com/claude-code): the agent that reads,
  summarises and drafts, and proposes anything that leaves ackt.
- Node 20 or later: Jev, the decision model for triage. OpenAI's Decisions
  API can judge instead: `ackt plugin add openai`.
- [Ollama](https://ollama.com): memory embeds messages on your machine.

## First run

Run `ackt`. The plugins panel opens: pick Mattermost and sign in where it
asks - a personal access token, your password, or your browser for single
sign-on. `?` lists every key.

### Single sign-on

Set `sso: true` on the Mattermost account (`ackt plugin add mattermost work
url=https://chat.example.com sso=true`). ackt shows a link; `enter` opens it
in your browser, where you sign in the way you always do and allow ackt. The
sign-in is kept in your keychain and renewed on its own.

The server needs one of:

- dynamic client registration turned on (System Console > Integrations >
  Integration Management; `ServiceSettings.EnableDynamicClientRegistration`);
- or an OAuth 2.0 app an admin registered with the callback URL
  `http://127.0.0.1:27065/callback`: set its client ID with
  `ackt plugin set mattermost work oauth_client_id=<id>`, and ackt asks for
  its secret once.

## Uninstall

```sh
ackt service uninstall
rm -rf ~/.local/bin/ackt ~/.local/share/ackt/bin ~/.local/share/ackt/lib
```

Your messages and settings are in `~/.local/share/ackt` and
`~/.config/ackt`.

## License

[Apache License 2.0](LICENSE).
