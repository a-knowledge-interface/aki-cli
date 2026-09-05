#!/usr/bin/env bash
set -euo pipefail

# aki installer — downloads a prebuilt binary from the GitHub Releases of this repo.
#
#   curl -fsSL https://raw.githubusercontent.com/a-knowledge-interface/aki-cli/main/install.sh | bash
#
# There is no build step and no Rust toolchain involved; aki ships as a single
# self-contained binary plus the Claude Code skills it installs alongside itself.
#
# Environment:
#   AKI_VERSION       release to install, e.g. 0.8.21 (default: the latest release)
#   AKI_INSTALL_DIR   where the binary goes (default: ~/.local/bin)
#   AKI_SKILLS_DIR    where skills go (default: ~/.claude/skills)
#   AKI_NO_SKILLS=1   skip installing skills

REPO="a-knowledge-interface/aki-cli"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[x]${NC} $*" >&2; exit 1; }
have()  { command -v "$1" >/dev/null 2>&1; }

VERSION="${AKI_VERSION:-}"
INSTALL_DIR="${AKI_INSTALL_DIR:-$HOME/.local/bin}"
SKILLS_DIR="${AKI_SKILLS_DIR:-$HOME/.claude/skills}"

# --- Fetch helper -----------------------------------------------------------
#
# curl and wget disagree on almost every flag, so the difference is settled once
# here rather than at each of the three call sites.

if have curl; then
    fetch()       { curl -fsSL "$1" -o "$2"; }
    fetch_quiet() { curl -fsSL "$1" -o "$2" 2>/dev/null; }
elif have wget; then
    fetch()       { wget -qO "$2" "$1"; }
    fetch_quiet() { wget -qO "$2" "$1" 2>/dev/null; }
else
    error "need curl or wget to download the release"
fi

# Replace a binary by rename, never by writing through the existing path: the
# destination may be the `aki` a running daemon is executing, and on Linux
# writing to that fails outright with ETXTBSY. rename(2) leaves the running
# process on its old inode and puts the new build in place atomically.
install_binary() {
    local src="$1" dest="$2"
    local tmp="$dest.new.$$"
    cp "$src" "$tmp"
    chmod 0755 "$tmp"
    mv -f "$tmp" "$dest"
}

# --- Platform ---------------------------------------------------------------

OS="$(uname -s)"
ARCH="$(uname -m)"

# Friendly platform names, matching the release assets (package.sh maps the
# build triples to these same names).
case "$OS-$ARCH" in
    Linux-x86_64)            PLATFORM="linux-x64" ;;
    Linux-aarch64|Linux-arm64) PLATFORM="linux-arm64" ;;
    Darwin-x86_64)           PLATFORM="macos-x64" ;;
    Darwin-arm64)            PLATFORM="macos-arm64" ;;
    *) error "unsupported platform: $OS $ARCH" ;;
esac

ASSET="aki-$PLATFORM.tar.gz"

# The version-free asset name is what lets /releases/latest/download/ resolve
# without asking the API which release is current.
if [ -n "$VERSION" ]; then
    VERSION="${VERSION#v}"
    BASE="https://github.com/$REPO/releases/download/v$VERSION"
    info "installing aki v$VERSION for $PLATFORM"
else
    BASE="https://github.com/$REPO/releases/latest/download"
    info "installing the latest aki for $PLATFORM"
fi

# --- Download ---------------------------------------------------------------

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! fetch "$BASE/$ASSET" "$TMP/$ASSET"; then
    echo "" >&2
    echo "  No published binary for $PLATFORM${VERSION:+ at v$VERSION}." >&2
    echo "  See https://github.com/$REPO/releases for what is available." >&2
    error "download failed: $BASE/$ASSET"
fi

# Checksums are published next to the asset. Absent on older releases, so a
# missing .sha256 is not fatal — a present one that disagrees is.
if fetch_quiet "$BASE/$ASSET.sha256" "$TMP/$ASSET.sha256"; then
    if have sha256sum;  then SUM="$(sha256sum "$TMP/$ASSET" | cut -d' ' -f1)"
    elif have shasum;   then SUM="$(shasum -a 256 "$TMP/$ASSET" | cut -d' ' -f1)"
    else SUM=""; warn "no sha256sum/shasum available — skipping checksum verification"
    fi
    if [ -n "$SUM" ]; then
        WANT="$(cut -d' ' -f1 < "$TMP/$ASSET.sha256")"
        [ "$SUM" = "$WANT" ] || error "checksum mismatch — expected $WANT, got $SUM"
        info "checksum verified"
    fi
else
    warn "no published checksum for this asset — skipping verification"
fi

tar -xzf "$TMP/$ASSET" -C "$TMP"
PKG="$TMP/aki-$PLATFORM"
[ -x "$PKG/aki" ] || error "archive did not contain aki-$PLATFORM/aki"

# --- Install the binary -----------------------------------------------------

mkdir -p "$INSTALL_DIR"
install_binary "$PKG/aki" "$INSTALL_DIR/aki"
info "aki installed to $INSTALL_DIR/aki"

case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *)
        warn "$INSTALL_DIR is not on your PATH. Add this to your shell profile:"
        echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
        ;;
esac

# The verify below runs the binary by full path, so the install "succeeds" even
# when the user's shell would resolve `aki` to something else — an old build in
# ~/.cargo/bin is the classic case. Say so now, not after the first weird error.
RESOLVED="$(command -v aki 2>/dev/null || true)"
if [ -n "$RESOLVED" ] && [ "$RESOLVED" != "$INSTALL_DIR/aki" ]; then
    warn "another aki at $RESOLVED comes earlier on your PATH and shadows this install."
    echo "    Remove it (rm \"$RESOLVED\") or put $INSTALL_DIR first; then run: hash -r"
fi

# --- Install the skills -----------------------------------------------------
#
# These teach Claude Code to drive aki itself (create tasks, search project
# knowledge, write docs). aki works without them; it is just less fluent.

if [ "${AKI_NO_SKILLS:-}" = "1" ]; then
    info "skipping skills (AKI_NO_SKILLS=1)"
elif [ -d "$PKG/skills" ]; then
    mkdir -p "$SKILLS_DIR"
    for d in "$PKG"/skills/*/; do
        [ -f "$d/SKILL.md" ] || continue
        rm -rf "$SKILLS_DIR/$(basename "$d")"
        # ${d%/}: the glob leaves a trailing slash, and BSD/macOS `cp -r dir/ dst`
        # copies dir's CONTENTS into dst where GNU copies the dir itself.
        cp -r "${d%/}" "$SKILLS_DIR/"
    done
    info "skills installed to $SKILLS_DIR"
fi

# --- Prerequisites ----------------------------------------------------------
#
# None of these are bundled: git and zellij are system tools, and claude is
# Anthropic's own CLI with its own auth. Report honestly rather than guessing.

MISSING=0

if have git; then
    info "git: $(git --version | head -1)"
else
    warn "git not found — aki needs it for worktrees. Install it with your package manager."
    MISSING=1
fi

if have claude; then
    info "claude: $(command -v claude)"
else
    warn "claude CLI not found — aki drives it, so nothing will run without it:"
    echo "    npm install -g @anthropic-ai/claude-code"
    echo "    https://docs.anthropic.com/en/docs/claude-code/overview"
    MISSING=1
fi

# zellij is only needed for the terminal mode (`aki start` / `aki go`); the web
# UI (`aki web`) does not use it. Worth fetching, not worth failing over.
if have zellij; then
    info "zellij: $(zellij --version)"
else
    ZELLIJ_VERSION="0.42.2"
    case "$OS-$ARCH" in
        Linux-x86_64)              ZTRIPLE="x86_64-unknown-linux-musl" ;;
        Linux-aarch64|Linux-arm64) ZTRIPLE="aarch64-unknown-linux-musl" ;;
        Darwin-x86_64)             ZTRIPLE="x86_64-apple-darwin" ;;
        Darwin-arm64)              ZTRIPLE="aarch64-apple-darwin" ;;
    esac
    info "installing zellij v$ZELLIJ_VERSION (needed for terminal mode)..."
    ZURL="https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-${ZTRIPLE}.tar.gz"
    if fetch "$ZURL" "$TMP/zellij.tar.gz" && tar -xzf "$TMP/zellij.tar.gz" -C "$TMP" zellij; then
        install_binary "$TMP/zellij" "$INSTALL_DIR/zellij"
        info "zellij installed to $INSTALL_DIR/zellij"
    else
        warn "could not fetch zellij — install it from https://zellij.dev/ for terminal mode"
    fi
fi

# --- Verify -----------------------------------------------------------------

if ! "$INSTALL_DIR/aki" --version >/dev/null 2>&1; then
    error "installed binary does not run — wrong platform build, or a missing system library"
fi

echo ""
info "$("$INSTALL_DIR/aki" --version) installed"
if [ "$MISSING" = "1" ]; then
    warn "some prerequisites are missing (above) — install them before running aki"
fi
echo ""
echo "  Get started:"
echo "    cd your-workspace"
echo "    aki init                     # scan for git repos"
echo "    aki login                    # sign in (optional — needed for the web UI)"
echo "    aki -p \"fix the auth bug\"     # create a task and start working"
echo ""
