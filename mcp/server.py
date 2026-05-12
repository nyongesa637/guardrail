"""
guardrail MCP server.

Exposes the guardrail CLI as MCP tools so AI agents (Claude Code,
Cursor, Codex, anything that speaks MCP) can apply / audit / protect
repositories via tool calls instead of shell-out.

The server is a thin wrapper: each tool runs the corresponding
`bin/guardrail` subcommand and returns its stdout + stderr to the
agent. The CLI is the single source of truth.

Run it via:

    python3 server.py

Or, from the guardrail repo root:

    bin/guardrail mcp run

Requires the `mcp` Python package:

    pip install --user 'mcp>=1.0'
"""

from __future__ import annotations

import asyncio
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

try:
    from mcp.server import Server  # type: ignore[import-not-found]
    from mcp.server.stdio import stdio_server  # type: ignore[import-not-found]
    from mcp.types import TextContent, Tool  # type: ignore[import-not-found]
except ImportError as e:  # pragma: no cover
    sys.stderr.write(
        "guardrail mcp: the 'mcp' package is required.\n"
        "  pip install --user 'mcp>=1.0'\n"
        f"  (import error: {e})\n",
    )
    sys.exit(2)


GUARDRAIL_HOME = Path(os.environ.get("GUARDRAIL_HOME", Path(__file__).resolve().parent.parent))
GUARDRAIL_BIN = GUARDRAIL_HOME / "bin" / "guardrail"


def _run(args: list[str], cwd: str | None = None, env_extra: dict[str, str] | None = None) -> tuple[int, str, str]:
    """Run guardrail with given args. Returns (rc, stdout, stderr)."""
    env = os.environ.copy()
    env["GUARDRAIL_HOME"] = str(GUARDRAIL_HOME)
    if env_extra:
        env.update(env_extra)
    try:
        proc = subprocess.run(
            [str(GUARDRAIL_BIN), *args],
            cwd=cwd or os.getcwd(),
            env=env,
            capture_output=True,
            text=True,
            timeout=900,
        )
        return proc.returncode, proc.stdout, proc.stderr
    except subprocess.TimeoutExpired:
        return 124, "", "guardrail subprocess timed out (15 min)"
    except FileNotFoundError:
        return 127, "", f"guardrail binary not found at {GUARDRAIL_BIN}"


def _fmt(rc: int, out: str, err: str) -> str:
    """Format subprocess output for the MCP client."""
    parts = []
    if out.strip():
        parts.append(out.rstrip())
    if err.strip():
        parts.append(f"--- stderr ---\n{err.rstrip()}")
    parts.append(f"--- exit code: {rc} ---")
    return "\n\n".join(parts)


server = Server("guardrail")


@server.list_tools()  # type: ignore[misc]
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="apply",
            description=(
                "Apply the guardrail governance pattern to a repository. "
                "Writes the standard set of LICENSE, NOTICE, TRADEMARK, "
                "CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, CODEOWNERS, "
                "CHANGELOG, and .github/{workflows,dependabot,templates}/ "
                "files. Existing files are skipped unless force=true."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "repo_path": {
                        "type": "string",
                        "description": "Absolute path to the target git repo. "
                                       "Defaults to the MCP server's CWD.",
                    },
                    "project_name": {"type": "string"},
                    "license": {
                        "type": "string",
                        "enum": ["AGPL-3.0", "MIT", "Apache-2.0"],
                        "default": "AGPL-3.0",
                    },
                    "author": {"type": "string", "description": "Author's full name"},
                    "gh_user": {"type": "string", "description": "GitHub username"},
                    "force": {
                        "type": "boolean",
                        "default": False,
                        "description": "Overwrite existing files.",
                    },
                    "dry_run": {"type": "boolean", "default": False},
                },
            },
        ),
        Tool(
            name="audit",
            description=(
                "Audit the current repo for missing guardrail files and "
                "extra hygiene (gitignored .env, signing, etc.). Returns "
                "stdout listing present / missing files and the exit code."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "repo_path": {"type": "string"},
                },
            },
        ),
        Tool(
            name="protect",
            description=(
                "Configure GitHub repo settings + branch protection via "
                "the gh API. Tightens repo defaults, enables Dependabot, "
                "restricts Actions, and applies branch protection where "
                "the repo's plan supports it. Degrades gracefully on free "
                "private repos."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "repo": {
                        "type": "string",
                        "description": "owner/name. Defaults to the linked repo at repo_path.",
                    },
                    "repo_path": {"type": "string"},
                },
            },
        ),
        Tool(
            name="signing_setup",
            description=(
                "Configure local SSH commit signing in the target repo. "
                "Sets gpg.format=ssh, user.signingkey, commit.gpgsign, "
                "and writes the allowed_signers entry. Prints the gh "
                "steps required to register the same key on GitHub."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "repo_path": {"type": "string"},
                },
            },
        ),
        Tool(
            name="list_templates",
            description="List every template shipped by this guardrail.",
            inputSchema={"type": "object", "properties": {}},
        ),
    ]


@server.call_tool()  # type: ignore[misc]
async def call_tool(name: str, arguments: dict[str, Any]) -> list[TextContent]:
    arguments = arguments or {}
    repo_path = arguments.get("repo_path") or os.getcwd()

    if name == "apply":
        cli_args = ["apply"]
        if arguments.get("project_name"):
            cli_args.append(f"--name={arguments['project_name']}")
        if arguments.get("license"):
            cli_args.append(f"--license={arguments['license']}")
        if arguments.get("author"):
            cli_args.append(f"--author={arguments['author']}")
        if arguments.get("gh_user"):
            cli_args.append(f"--gh-user={arguments['gh_user']}")
        if arguments.get("force"):
            cli_args.append("--force")
        if arguments.get("dry_run"):
            cli_args.append("--dry-run")
        rc, out, err = _run(cli_args, cwd=repo_path)
        return [TextContent(type="text", text=_fmt(rc, out, err))]

    if name == "audit":
        rc, out, err = _run(["audit"], cwd=repo_path)
        return [TextContent(type="text", text=_fmt(rc, out, err))]

    if name == "protect":
        cli_args = ["protect"]
        if arguments.get("repo"):
            cli_args.append(arguments["repo"])
        rc, out, err = _run(cli_args, cwd=repo_path)
        return [TextContent(type="text", text=_fmt(rc, out, err))]

    if name == "signing_setup":
        rc, out, err = _run(["signing"], cwd=repo_path)
        return [TextContent(type="text", text=_fmt(rc, out, err))]

    if name == "list_templates":
        rc, out, err = _run(["templates"])
        return [TextContent(type="text", text=_fmt(rc, out, err))]

    return [TextContent(type="text", text=f"unknown tool: {name}")]


async def main() -> None:
    if not GUARDRAIL_BIN.exists():
        sys.stderr.write(f"guardrail mcp: bin not found at {GUARDRAIL_BIN}\n")
        sys.exit(1)
    async with stdio_server() as (read, write):
        await server.run(read, write, server.create_initialization_options())


if __name__ == "__main__":
    asyncio.run(main())
