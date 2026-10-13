#!/bin/sh
# ackt installer.
#
#     curl -fsSL https://raw.githubusercontent.com/isacikgoz/ackt-releases/main/install.sh | sh
#
# It downloads from the public releases at github.com/isacikgoz/ackt-releases
# over HTTPS: nothing to sign in to.
#
# Installs ackt to ~/.local/bin and its plugins to ~/.local/share/ackt/bin
# (XDG_DATA_HOME moves it), and starts the daemon in the background: a
# launchd agent on macOS, a systemd user service on Linux. Running it again
# upgrades in place. Nothing is written outside your home directory.
#
# Jev (triage) runs on Node: it is installed when Node 20 or later is on
# PATH, and a later run adds it once it is. The Claude agent is your own
# Claude Code: set up when claude is installed. Memory embeds with Ollama:
# its model is pulled when ollama is installed.
#
# Settings, all optional:
#     ACKT_VERSION=v0.1.0     a release other than the latest
#     ACKT_BIN_DIR=...        where ackt goes (default ~/.local/bin)
#     ACKT_NO_SERVICE=1       install only; do not start the daemon
#     ACKT_DOWNLOAD_URL=...   download over HTTP from here instead of GitHub (a mirror, a test)
#
# Uninstall:
#     ackt service uninstall
#     rm -rf ~/.local/bin/ackt ~/.local/share/ackt/bin ~/.local/share/ackt/lib
# (your messages and settings are in ~/.local/share/ackt and ~/.config/ackt)

set -eu

REPO=isacikgoz/ackt-releases
VERSION=${ACKT_VERSION:-latest}
BIN_DIR=${ACKT_BIN_DIR:-$HOME/.local/bin}
case ${XDG_DATA_HOME:-} in
/*) DATA_HOME=$XDG_DATA_HOME ;;
*) DATA_HOME=$HOME/.local/share ;;
esac
PLUGIN_DIR=${ACKT_PLUGIN_DIR:-$DATA_HOME/ackt/bin}
LIB_DIR=$DATA_HOME/ackt/lib
# Where privacy mode's Touch ID helper went, before privacy mode was gone.
OLD_LIBEXEC_DIR=${ACKT_DATA_DIR:-$DATA_HOME/ackt}/libexec

say() { printf '%s\n' "$*"; }
note() { printf '  %s\n' "$*"; }
fail() {
	printf 'ackt install: %s\n' "$*" >&2
	exit 1
}

# --- where it runs ------------------------------------------------------------

case $(uname -s) in
Darwin) os=darwin ;;
Linux) os=linux ;;
*) fail "ackt runs on macOS and Linux; this is $(uname -s)" ;;
esac
case $(uname -m) in
x86_64 | amd64) arch=amd64 ;;
arm64 | aarch64) arch=arm64 ;;
*) fail "no ackt build for $(uname -m)" ;;
esac
# A shell under Rosetta says x86_64 on Apple silicon; the native build is
# the one to run.
if [ "$os" = darwin ] && [ "$arch" = amd64 ] &&
	[ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = 1 ]; then
	arch=arm64
fi

# download gets the release files named, into the directory given, from
# base.
download() {
	dir=$1
	shift
	for f in "$@"; do
		fetch "$base/$f" "$dir/$f"
	done
}

fetch() {
	if command -v curl >/dev/null 2>&1; then
		curl -fsSL -o "$2" "$1" || fail "could not download $1"
	elif command -v wget >/dev/null 2>&1; then
		wget -q -O "$2" "$1" || fail "could not download $1"
	else
		fail "needs curl or wget"
	fi
}

sha256() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | cut -d' ' -f1
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$1" | cut -d' ' -f1
	else
		fail "needs sha256sum or shasum, to check the download"
	fi
}

# --- download and check -------------------------------------------------------

tmp=$(mktemp -d 2>/dev/null || mktemp -d -t ackt)
trap 'rm -rf "$tmp"' EXIT INT TERM

# Where the release is: ACKT_DOWNLOAD_URL, or the release on GitHub - the
# newest, pre-releases included, unless ACKT_VERSION names one. GitHub's
# own latest skips pre-releases, and every release so far is one.
base=${ACKT_DOWNLOAD_URL:-}
base=${base%/}
if [ -z "$base" ]; then
	if [ "$VERSION" = latest ]; then
		fetch "https://api.github.com/repos/$REPO/releases?per_page=1" "$tmp/releases.json"
		VERSION=$(sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' "$tmp/releases.json" | head -n 1)
		[ -n "$VERSION" ] || fail "no release found at https://github.com/$REPO/releases"
	fi
	base=https://github.com/$REPO/releases/download/$VERSION
fi

asset=ackt_${os}_${arch}.tar.gz
say "downloading ackt ($VERSION, $os/$arch)"
download "$tmp" "$asset" checksums.txt
want=$(awk -v f="$asset" '$2 == f { print $1 }' "$tmp/checksums.txt")
[ -n "$want" ] || fail "checksums.txt does not list $asset"
[ "$(sha256 "$tmp/$asset")" = "$want" ] || fail "$asset does not match its checksum; not installing it"
tar -xzf "$tmp/$asset" -C "$tmp"
src=$tmp/ackt
version=$(cat "$src/VERSION")

# --- install ------------------------------------------------------------------

# Each file is copied beside its place and moved over it, so a running
# daemon or plugin keeps the file it has open and the next start gets the
# new one.
put() {
	mkdir -p "$(dirname "$2")"
	cp "$1" "$2.new"
	chmod "$3" "$2.new"
	mv -f "$2.new" "$2"
}

put "$src/bin/ackt" "$BIN_DIR/ackt" 0755
for p in "$src"/plugins/ackt-*; do
	name=$(basename "$p")
	[ "$name" = ackt-jev ] && continue # with node, below
	put "$p" "$PLUGIN_DIR/$name" 0755
done

rm -f "$OLD_LIBEXEC_DIR/ackt-unlock"
rmdir "$OLD_LIBEXEC_DIR" 2>/dev/null || true

node_ok=
if command -v node >/dev/null 2>&1; then
	major=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)
	[ "$major" -ge 20 ] 2>/dev/null && node_ok=1
fi

if [ -n "$node_ok" ]; then
	put "$src/plugins/ackt-jev" "$PLUGIN_DIR/ackt-jev" 0755
fi
# Claude used to run on the Agent SDK from here, and Claude Code as
# claudecode; it is one agent now, claude. (The daemon clears the rest.)
rm -rf "$LIB_DIR/claude" "$PLUGIN_DIR/ackt-claudecode"

say "installed ackt $version"
note "ackt      $BIN_DIR/ackt"
note "plugins   $PLUGIN_DIR"
if [ -z "$node_ok" ]; then
	note "Jev (triage) needs Node 20 or later: install it, then run this again"
fi
# The Claude agent is Claude Code, on the reader's own login: added when
# claude is installed and the config has no Claude agent yet.
if command -v claude >/dev/null 2>&1; then
	if "$BIN_DIR/ackt" plugin add claude >"$tmp/claude.log" 2>&1; then
		note "Claude Code is set up as an agent: attach it to a context with A"
	elif ! grep -q "configured already" "$tmp/claude.log"; then
		note "Claude Code was not set up as an agent:"
		sed 's/^/    /' "$tmp/claude.log" | tail -3
	fi
else
	note "agents run on Claude Code: install it (https://claude.com/claude-code), then run this again"
fi
# Memory embeds messages on the reader's own machine, with Ollama: its
# model is pulled when ollama is installed and running.
if command -v ollama >/dev/null 2>&1; then
	if ollama list 2>/dev/null | grep -q '^nomic-embed-text'; then
		:
	elif ollama pull nomic-embed-text >"$tmp/ollama.log" 2>&1; then
		note "memory embeds on Ollama: nomic-embed-text is pulled"
	else
		note "Ollama did not pull nomic-embed-text - is it running (ollama serve)? Then run this again"
	fi
else
	note "memory embeds on your machine with Ollama: install it (https://ollama.com), then run this again"
fi
# Sign-ins and API keys are kept in the OS keyring; on Linux that is the
# Secret Service, reached through secret-tool.
if [ "$os" = linux ] && ! command -v secret-tool >/dev/null 2>&1; then
	note "to keep sign-ins and API keys, install secret-tool: libsecret-tools (Debian, Ubuntu) or libsecret (Fedora, Arch)"
fi

# --- the daemon ---------------------------------------------------------------

if [ -z "${ACKT_NO_SERVICE:-}" ]; then
	# It says why when it cannot, and how to start the daemon instead.
	"$BIN_DIR/ackt" service install || true
fi

# --- next ---------------------------------------------------------------------

say ""
case ":$PATH:" in
*":$BIN_DIR:"*)
	say "next: run ackt, then ctrl+p to add your accounts"
	;;
*)
	say "$BIN_DIR is not on your PATH. Add it:"
	case $(basename "${SHELL:-sh}") in
	fish) note "fish_add_path $BIN_DIR" ;;
	zsh) note "echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.zshrc" ;;
	bash) note "echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bashrc" ;;
	*) note "export PATH=\"$BIN_DIR:\$PATH\"   (in your shell's startup file)" ;;
	esac
	say "then run ackt, and ctrl+p to add your accounts"
	;;
esac
