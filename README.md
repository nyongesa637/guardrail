# guardrail

> Drop a vetted **governance / security / CI** pattern into any repo
> in one command. Works with Claude Code, Cursor, Codex, or a plain
> terminal.

`guardrail` is the missing bootstrap step every project should run
on day zero. It ships eighteen files (license, NOTICE, trademark
policy, code of conduct, contributing, security policy, CODEOWNERS,
changelog, six issue/PR templates, three GitHub Actions workflows,
Dependabot config, FUNDING) and configures your GitHub repo via the
`gh` API to match. Everything is opinionated, every default has been
production-tested on real projects.

```bash
cd my-new-repo
guardrail init
```

That's the whole thing.

## What you get

The 18 files in three buckets:

| Bucket    | Files                                                                       |
| --------- | --------------------------------------------------------------------------- |
| Legal     | `LICENSE` (AGPL-3.0 / MIT / Apache-2.0), `NOTICE`, `TRADEMARK.md`           |
| Community | `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md` (DCO), `SECURITY.md`, `CODEOWNERS`, `CHANGELOG.md` |
| CI/CD     | `.github/workflows/dco.yml`, `lint.yml`, `auto-merge-dependabot.yml`, `.github/dependabot.yml`, four issue templates, PR template, FUNDING |

Three CI checks fire on every PR:

- **DCO sign-off** — every commit must carry `Signed-off-by:`. Merge
  commits and bot PRs are auto-skipped (Dependabot's signoff is
  trusted; auto-merge commits never have a real author).
- **Conventional commit titles** — `feat(scope): summary` etc.
  Dependabot's double-scope `chore(deps)(deps-dev): …` titles bypass
  the regex automatically.
- **Pre-commit secret scan (gitleaks)** — scans the PR diff. Has
  `pull-requests: read` baked in so it works on private repos.

An additional **auto-merge-dependabot** workflow lands every passing
Dependabot PR automatically — uses GitHub's branch-protection
auto-merge where available, polling fallback on free private.

`guardrail protect` then configures the GitHub side:

- Repo defaults (no wiki, no rebase merge, delete branch on merge,
  auto-merge on)
- Dependabot vulnerability alerts + auto security fixes
- Actions allowlist (GitHub-owned + verified + a few named patterns)
- Workflows default to read-only with no auto-approval
- Fork-PR access disabled (private repos)
- Secret scanning + push protection (public OR Pro private)
- Branch protection on `main` with required signed commits (public
  OR Pro private)

When a feature isn't available on the user's plan, `protect` says
so clearly instead of failing silently.

## Install

Three paths — pick whichever fits.

### 1. Docker (zero install)

The published image at `ghcr.io/nyongesa637/guardrail:latest`
bundles bash, git, gh, and the toolkit. Mount your repo and run:

```bash
docker run --rm -v "$PWD:/work" -w /work \
  ghcr.io/nyongesa637/guardrail:latest init

# Configure GitHub (needs a token):
docker run --rm -v "$PWD:/work" -w /work \
  -e GH_TOKEN="$(gh auth token)" \
  ghcr.io/nyongesa637/guardrail:latest protect
```

Tags follow the repo's [SemVer releases](https://github.com/nyongesa637/guardrail/releases):
`latest`, `v0.1.0`, `0.1`, `0`. Built for `linux/amd64` and
`linux/arm64`.

### 2. Curl one-liner (clones to `~/.local/share/guardrail`)

```bash
curl -fsSL https://raw.githubusercontent.com/nyongesa637/guardrail/main/install.sh | bash
```

The script clones the repo, symlinks `bin/guardrail` to
`~/.local/bin/guardrail`, and (if `~/.claude/` or `~/.cursor/`
exists) symlinks the agent integrations.

### 3. Release tarball

```bash
LATEST=$(gh release view --repo nyongesa637/guardrail --json tagName --jq '.tagName')
curl -fsSL "https://github.com/nyongesa637/guardrail/releases/download/${LATEST}/guardrail-${LATEST#v}.tar.gz" \
  | tar -xz -C ~/.local/share/
ln -sf "$HOME/.local/share/guardrail-${LATEST#v}/bin/guardrail" "$HOME/.local/bin/guardrail"
```

Each release ships a `guardrail-<ver>.tar.gz` and a `.sha256`.

### Dependencies

All standard: `bash`, `git`, `gh`. Optional: `envsubst` (cleaner
template rendering; falls back to `sed`), and Python 3.10+ +
`mcp` package if you want the MCP server.

## Use

```bash
guardrail init           # interactive — asks 4 questions
guardrail apply --license=MIT --name=foo --author='Jane' --gh-user=jane
guardrail audit          # what's present, what's missing
guardrail signing        # local SSH commit signing
guardrail protect        # gh API config
guardrail templates      # list the templates
guardrail mcp install    # print MCP config snippets
guardrail help
```

`init` is the front door. `audit` is idempotent and read-only.
`apply --force` is the only way to overwrite existing files.

## Use it with your AI coding agent

### Claude Code

Two options:

**1. Slash commands.** Copy or symlink the `.claude/commands/` from
this repo to `~/.claude/commands/`. Now `/guardrail-init`,
`/guardrail-audit`, `/guardrail-protect`, and `/guardrail-signing`
are available in any Claude Code session.

```bash
ln -s ~/guardrail/.claude/commands/* ~/.claude/commands/
```

**2. MCP server.** Add to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "guardrail": {
      "command": "/home/you/guardrail/bin/guardrail",
      "args": ["mcp", "run"]
    }
  }
}
```

Claude can then call `apply`, `audit`, `protect`, `signing_setup`,
`list_templates` as native tools.

### Cursor

Drop `.cursor/rules/guardrail.mdc` and `.cursor/rules/repo-governance.mdc`
into your projects (or symlink to this repo's copy). Cursor will
read them whenever the matching globs hit and learn the guardrail
commands.

For the MCP server, create `.cursor/mcp.json` with the same JSON as
Claude, or use the global `~/.cursor/mcp.json`.

### Codex

`AGENTS.md` in this repo is the operating contract. Codex picks it
up automatically when working inside the guardrail repo. To use
guardrail from inside another repo Codex is working on, the user
just types:

```bash
guardrail init
```

or asks Codex to run it.

## Why guardrail exists

It was extracted from two real projects (one public, one private)
after solving these specific problems in production:

- Free private repos can't have branch protection — workflows have
  to fill the gap.
- Dependabot's `chore(deps)(deps-dev): …` titles break naive
  Conventional-Commits regexes. The fix is a one-line bot-bypass.
- `Update branch` auto-merge commits never carry `Signed-off-by:` —
  the DCO check has to skip merge commits via `git rev-list
  --no-merges`.
- `lint.yml` needs `pull-requests: read` to call the PR commits API
  on private repos (works on public without it).
- "Auto-merge when checks pass" needs two paths: GitHub's native
  auto-merge for protected branches, polling fallback for free
  private.

All of those are baked in. You get the fixes for free.

## Templates

Variables available inside `.tmpl` files:

| Variable                 | What it is                                          |
| ------------------------ | --------------------------------------------------- |
| `${GR_PROJECT}`          | project name as entered                             |
| `${GR_PROJECT_LOWER}`    | lowercase project name (used in URLs)               |
| `${GR_PROJECT_TITLE}`    | Title Case project name (used in headings)          |
| `${GR_LICENSE}`          | AGPL-3.0, MIT, or Apache-2.0                        |
| `${GR_AUTHOR}`           | author's full name                                  |
| `${GR_GH_USER}`          | GitHub username                                     |
| `${GR_YEAR}`             | current year                                        |

To list the templates this guardrail ships:

```bash
guardrail templates
```

## Contributing

This project follows its own pattern. See [`CONTRIBUTING.md`](./CONTRIBUTING.md).

In short:

- Branch with a `feat/`, `fix/`, `chore/`, `docs/`, `test/`, `ci/`,
  `refactor/`, or `perf/` prefix.
- Commit with `-s` (DCO sign-off).
- Commits must be SSH/GPG-signed.
- PR title in Conventional Commits format.

## License

[`AGPL-3.0`](./LICENSE) — see [`NOTICE`](./NOTICE) and
[`TRADEMARK.md`](./TRADEMARK.md).

## Security

[`SECURITY.md`](./SECURITY.md) — please don't open public issues for
security findings.
