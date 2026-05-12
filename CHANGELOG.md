# Changelog

All notable changes to guardrail are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-05-12

### Added
- **Bash CLI** (`bin/guardrail`) with six commands: `init`, `apply`,
  `audit`, `protect`, `signing`, `templates`. No runtime deps beyond
  `bash`, `git`, and `gh`.
- **18 templates** in `templates/` covering legal (LICENSE x3, NOTICE,
  TRADEMARK), community (CODE_OF_CONDUCT, CONTRIBUTING, SECURITY,
  CODEOWNERS, CHANGELOG), and CI (DCO, lint, auto-merge workflows,
  Dependabot, PR + 4 issue templates, FUNDING).
- **Agent integrations**: Claude Code slash commands
  (`.claude/commands/`), Cursor rules (`.cursor/rules/`), and Codex
  doctrine via `AGENTS.md`.
- **Optional MCP server** (`mcp/server.py`) exposing `apply`,
  `audit`, `protect`, `signing_setup`, `list_templates` as MCP tools.
- **Production-tested fixes** baked in:
  - DCO workflow skips merge commits and Bot-authored PRs.
  - Lint workflow has Bot author bypass for Dependabot's
    double-scope titles.
  - Lint workflow declares `pull-requests: read` for private-repo
    gitleaks support.
  - Auto-merge workflow handles both protected (native auto-merge)
    and unprotected (polling fallback) main branches.
- **`install.sh` one-liner** that clones, symlinks the CLI, and
  wires up agent integrations when matching dot-dirs exist.
- **Docker image** published to `ghcr.io/nyongesa637/guardrail`
  (linux/amd64, linux/arm64). `latest` and per-tag SemVer.
- **GitHub Release** with a versioned tarball + sha256.

### Notes
- `guardrail protect` degrades gracefully on free private repos —
  it applies Actions allowlist + read-only workflow permissions +
  Dependabot but flags branch protection and secret scanning as
  unavailable on that plan.

## Release process

When cutting a release:

1. Move everything in `[Unreleased]` under a new `[X.Y.Z] — YYYY-MM-DD`
   heading.
2. Tag with `vX.Y.Z` on a signed annotated tag
   (`git tag -s -a vX.Y.Z -m "Release X.Y.Z"`).
3. Push the tag — a GitHub Release is created and a Security Advisory
   draft is opened for anything in the **Security** section.
4. Open a new empty `[Unreleased]` section on `main`.

Version bumps follow SemVer strictly. Define your project's
MAJOR-breaking surfaces (API contracts, data formats, on-disk
schemas) in this file once the project stabilises.

[Unreleased]: https://github.com/nyongesa637/guardrail/compare/HEAD...HEAD
