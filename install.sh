#!/usr/bin/env bash
# install.sh — install guardrail into ~/.local/share/guardrail and
# symlink the CLI to ~/.local/bin/guardrail.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/nyongesa637/guardrail/main/install.sh | bash
#   bash install.sh                       # if already cloned
#   bash install.sh --dest /opt/guardrail # custom location

set -euo pipefail

REPO_URL="https://github.com/nyongesa637/guardrail.git"
DEFAULT_DEST="${HOME}/.local/share/guardrail"
DEFAULT_BIN="${HOME}/.local/bin"

DEST="$DEFAULT_DEST"
BIN="$DEFAULT_BIN"
LINK_AGENTS=true

while [ $# -gt 0 ]; do
  case "$1" in
    --dest)         DEST="$2"; shift 2 ;;
    --bin)          BIN="$2";  shift 2 ;;
    --no-agents)    LINK_AGENTS=false; shift ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# //;s/^#$//'
      exit 0
      ;;
    *) echo "install: unknown flag: $1" >&2; exit 1 ;;
  esac
done

c() { printf '\033[1;36m%s\033[0m' "$1"; }
g() { printf '\033[1;32m%s\033[0m' "$1"; }
y() { printf '\033[1;33m%s\033[0m' "$1"; }
r() { printf '\033[1;31m%s\033[0m' "$1"; }
note() { printf '%s %s\n' "$(c '·')" "$1"; }
ok()   { printf '%s %s\n' "$(g '✓')" "$1"; }
warn() { printf '%s %s\n' "$(y '!')" "$1"; }
die()  { printf '%s %s\n' "$(r '✗')" "$1" >&2; exit 1; }

command -v git >/dev/null || die "git is required"
command -v bash >/dev/null || die "bash is required"

# Clone or update.
if [ -d "$DEST/.git" ]; then
  note "Updating existing guardrail at $DEST"
  git -C "$DEST" pull --ff-only --quiet
elif [ -d "$DEST" ] && [ -f "$DEST/bin/guardrail" ]; then
  note "Found a non-git copy of guardrail at $DEST (skipping clone)"
else
  if [ -d "$DEST" ]; then
    die "Destination exists but isn't guardrail: $DEST  (move it or pass --dest)"
  fi
  note "Cloning $REPO_URL → $DEST"
  mkdir -p "$(dirname "$DEST")"
  git clone --quiet "$REPO_URL" "$DEST"
fi

ok "guardrail repo is at $DEST"

# Symlink the binary.
mkdir -p "$BIN"
ln -sf "$DEST/bin/guardrail" "$BIN/guardrail"
ok "linked $BIN/guardrail → $DEST/bin/guardrail"

# PATH check.
case ":${PATH}:" in
  *":${BIN}:"*) ok "$BIN is on your PATH" ;;
  *)            warn "add $BIN to your PATH (e.g. echo 'export PATH=\"$BIN:\$PATH\"' >> ~/.bashrc)" ;;
esac

# Optionally link agent integrations.
if $LINK_AGENTS; then
  if [ -d "$HOME/.claude" ]; then
    mkdir -p "$HOME/.claude/commands"
    for f in "$DEST"/.claude/commands/*.md; do
      ln -sf "$f" "$HOME/.claude/commands/$(basename "$f")"
    done
    ok "linked Claude slash commands → $HOME/.claude/commands/"
  else
    note "no $HOME/.claude/ — skipping Claude slash-command install"
  fi

  if [ -d "$HOME/.cursor" ]; then
    mkdir -p "$HOME/.cursor/rules"
    for f in "$DEST"/.cursor/rules/*.mdc; do
      ln -sf "$f" "$HOME/.cursor/rules/$(basename "$f")"
    done
    ok "linked Cursor rules → $HOME/.cursor/rules/"
  else
    note "no $HOME/.cursor/ — skipping Cursor rules install"
  fi
fi

echo ""
note "Try it:"
echo "    guardrail version"
echo "    guardrail help"
echo "    guardrail templates"
echo ""
note "Bootstrap a repo:"
echo "    cd path/to/your/repo"
echo "    guardrail init"
