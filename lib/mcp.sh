#!/usr/bin/env bash
# mcp.sh — manage the optional MCP server.

set -euo pipefail
source "$GUARDRAIL_HOME/lib/common.sh"

sub="${1:-help}"
shift || true

case "$sub" in
  run)
    require_cmd python3
    exec python3 "$GUARDRAIL_HOME/mcp/server.py" "$@"
    ;;

  install)
    cat <<EOF
Add guardrail to your AI agent as an MCP server.

CLAUDE CODE  (in ~/.claude/settings.json or .claude/settings.json):
  {
    "mcpServers": {
      "guardrail": {
        "command": "$GUARDRAIL_HOME/bin/guardrail",
        "args": ["mcp", "run"]
      }
    }
  }

CURSOR  (in .cursor/mcp.json):
  {
    "mcpServers": {
      "guardrail": {
        "command": "$GUARDRAIL_HOME/bin/guardrail",
        "args": ["mcp", "run"]
      }
    }
  }

CODEX  (Codex picks up MCP via its native config; or invoke the CLI
        directly via shell):
  $GUARDRAIL_HOME/bin/guardrail apply ...

The MCP server exposes these tools:
  - apply            apply the guardrail pattern to a repo
  - audit            list missing files in a repo
  - protect          configure github repo settings + branch protection
  - list_templates   list the templates this guardrail ships
  - signing_setup    print steps to enable local SSH signing
EOF
    ;;

  help|--help|-h|"")
    cat <<EOF
guardrail mcp — manage the MCP server

  install    print MCP config snippets for Claude / Cursor / Codex
  run        run the MCP server (stdio)
  help       this help
EOF
    ;;

  *) die "unknown mcp subcommand: $sub" ;;
esac
