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

## Desktop app (alpha)

ackt in a window of its own, with how many things need you in the menu bar
(macOS) or the tray (Linux). It brings ackt with it: the first launch
installs it and runs it in the background, as the installer above does.
Download it from the newest `desktop-v…` release on the
[releases page](https://github.com/isacikgoz/ackt-releases/releases):

- macOS, Apple Silicon: the `.dmg`, signed and notarized; drag ackt to
  Applications and open it.
- Debian and Ubuntu: `sudo apt install ./ackt_<version>_amd64.deb`.
- Arch Linux: the `PKGBUILD`; `makepkg -si` in its folder.
- Any Linux: the AppImage; `chmod +x`, then open it (it needs FUSE 3).

*Uninstall ackt…* in its menu takes it off, keeping your messages or not.

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
  Integration Management; `ServiceSettings.EnableDynamicClientRegistration`).
  ackt registers itself to come back to `http://localhost:<port>/callback`,
  so a server that limits where apps may come back to
  (`ServiceSettings.DCRRedirectURIAllowlist`) needs a pattern like
  `http://localhost:*/*`;
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
