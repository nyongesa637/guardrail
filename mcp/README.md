# guardrail MCP server

A thin Model Context Protocol server that exposes the guardrail CLI
as tools. AI agents that speak MCP (Claude Code, Cursor, Codex,
others) can apply / audit / protect repositories via tool calls
instead of running shell commands.

## Install

```bash
pip install --user 'mcp>=1.0'
```

That's the only runtime dep. The server itself is `server.py`, a
single file.

## Configure your agent

### Claude Code

Add to `~/.claude/settings.json` (or your project's
`.claude/settings.json`):

```json
{
  "mcpServers": {
    "guardrail": {
      "command": "/absolute/path/to/guardrail/bin/guardrail",
      "args": ["mcp", "run"]
    }
  }
}
```

`bin/guardrail mcp run` execs `python3 mcp/server.py` with the
correct `GUARDRAIL_HOME` baked in. You don't need to track Python
paths.

### Cursor

Create `.cursor/mcp.json` at the project root or `~/.cursor/mcp.json`
for global:

```json
{
  "mcpServers": {
    "guardrail": {
      "command": "/absolute/path/to/guardrail/bin/guardrail",
      "args": ["mcp", "run"]
    }
  }
}
```

### Codex (and any other MCP client)

Configure per your client's documentation. The command is always:

```
/absolute/path/to/guardrail/bin/guardrail mcp run
```

You can also run `guardrail mcp install` to print these snippets
ready to paste.

## Tools exposed

| Tool             | What it does                                                     |
| ---------------- | ---------------------------------------------------------------- |
| `apply`          | Write LICENSE/NOTICE/.github/* etc. into a repo                  |
| `audit`          | List missing files + hygiene findings                            |
| `protect`        | Configure GitHub repo settings + branch protection via gh        |
| `signing_setup`  | Configure local SSH commit signing                               |
| `list_templates` | List templates shipped by this guardrail                         |

Each tool wraps the corresponding `bin/guardrail` subcommand and
returns its stdout + stderr + exit code as a single text payload.

## Why a thin wrapper

The CLI is the source of truth. The MCP server has no parallel logic;
every behaviour change happens in `lib/*.sh` and the templates, so
agents and humans get identical results.
