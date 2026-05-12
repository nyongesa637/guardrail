#!/usr/bin/env bash
# Shared helpers for guardrail.

# Coloured output (downgrades cleanly when not a TTY).
if [ -t 2 ]; then
  C_RED=$'\033[1;31m'
  C_YEL=$'\033[1;33m'
  C_GRN=$'\033[1;32m'
  C_CYN=$'\033[1;36m'
  C_DIM=$'\033[2m'
  C_OFF=$'\033[0m'
else
  C_RED=""; C_YEL=""; C_GRN=""; C_CYN=""; C_DIM=""; C_OFF=""
fi

die()  { printf '%s✗%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }
warn() { printf '%s!%s %s\n' "$C_YEL" "$C_OFF" "$*" >&2; }
note() { printf '%s·%s %s\n' "$C_CYN" "$C_OFF" "$*"; }
ok()   { printf '%s✓%s %s\n' "$C_GRN" "$C_OFF" "$*"; }
dim()  { printf '%s%s%s\n'   "$C_DIM" "$*" "$C_OFF"; }

require_cmd() {
  local missing=()
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || missing+=("$c")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    die "missing required command(s): ${missing[*]}"
  fi
}

require_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "not inside a git repository (cd to one or run 'git init' first)"
}

# Repo root if inside one.
repo_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

# Display the help block.
cmd_help() {
  cat <<'EOF'
guardrail — drop a governance / security / CI pattern into any repo.

USAGE
  guardrail <command> [flags]

COMMANDS
  init                Interactive setup for the current repo.
                      Asks for project name, license, author. Writes
                      all templates, never overwrites existing files
                      unless --force is passed.

  apply [flags]       Non-interactive apply. Flags:
                        --license=AGPL-3.0|MIT|Apache-2.0
                        --name=<project name>
                        --author='<Name>'
                        --gh-user=<github username>
                        --force         overwrite existing files
                        --dry-run       print what would happen

  audit               Report which guardrail files are present and
                      which are missing in the current repo. Exits
                      0 if everything is present, 1 otherwise.

  protect [owner/repo]
                      Configure GitHub repo settings via the gh API.
                      Applies: Dependabot alerts, Actions allowlist,
                      read-only workflow defaults, fork access (if
                      private), branch protection (if available),
                      secret scanning (if available), required
                      signatures (if available). Falls back gracefully
                      on free private repos.

  signing             Configure local SSH commit signing in the
                      current repo: gpg.format=ssh, user.signingkey,
                      commit.gpgsign=true, allowed_signers file.
                      Prints next steps for registering the key as a
                      signing key on GitHub.

  mcp                 Manage the optional MCP server. Subcommands:
                        install  — print Claude / Cursor / Codex
                                   MCP config snippets
                        run      — run the server (stdio)

  templates           List the templates this guardrail ships.

  version             Print version (0.1.0).

  help                This help.

EXAMPLES
  cd my-new-project
  guardrail init                         # interactive
  guardrail signing                      # set up local SSH signing
  guardrail protect                      # configure github

  guardrail apply --license=MIT --name=foo --author='Jane Doe' --force
  guardrail audit
  guardrail protect nyongesa637/foo

ENVIRONMENT
  GUARDRAIL_HOME      Override the install root.
                      Default: $(dirname "$(readlink -f "$0")")/..

REFERENCES
  https://github.com/nyongesa637/guardrail
EOF
}
