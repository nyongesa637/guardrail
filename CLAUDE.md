# guardrail — instructions for Claude Code

> **Read this first if you are Claude Code operating inside this repo
> or being asked to apply guardrail to another repo.**

## What this repo is

**guardrail** is a single-binary toolkit (`bin/guardrail`) that drops a
vetted set of governance / security / CI files into any repository.
It also configures the corresponding GitHub repo settings via the gh
API. The pattern was extracted from two real projects (verda and somo)
after solving these surface problems in production:

- Free private repos can't have GitHub branch protection — workflows
  fill the gap.
- Dependabot's `chore(deps)(deps-dev): …` titles break naive
  Conventional-Commits regexes.
- Auto-generated `Update branch` merge commits never carry
  `Signed-off-by:` so DCO checks must skip merges.
- Lint workflows must declare `pull-requests: read` so gitleaks works
  on private repos.

Each of those is baked into the templates this repo ships.

## When the user asks you to set up a new repo

Don't reimplement. Run guardrail.

```bash
cd <their-repo>
# Interactive (preferred — asks 4 questions):
guardrail init

# Non-interactive (use this when scripting):
guardrail apply --license=AGPL-3.0 --name=<project> --author='<Name>' --gh-user=<login>

# Then:
guardrail signing            # local SSH commit signing
guardrail protect            # GitHub repo settings + branch protection
guardrail audit              # verify everything is in place
```

The commands are idempotent: existing files are skipped unless
`--force` is passed. The user's in-progress work in the target repo
is not touched.

If `guardrail` isn't on the user's PATH yet, point them at
`$GUARDRAIL_HOME/install.sh` first.

## When the user asks "what's missing" in a repo

```bash
cd <their-repo>
guardrail audit
```

Reports which guardrail files are present / missing, plus extra
hygiene checks (`.env` gitignored, no `.env` tracked, signing
configured).

## When working on this repo (guardrail itself)

The MUST-NOT-BREAK invariants:

1. **`bin/guardrail` stays bash, no runtime deps beyond `git`, `gh`,
   and `bash`.** Don't introduce Python or Node deps in the core CLI.
   The optional MCP server in `mcp/` is allowed Python deps; the CLI
   is not.

2. **Templates use only `${GR_*}` variables.** Allowed:
   `GR_PROJECT`, `GR_PROJECT_LOWER`, `GR_PROJECT_TITLE`, `GR_LICENSE`,
   `GR_AUTHOR`, `GR_GH_USER`, `GR_YEAR`. Adding a new variable
   requires updating `lib/render.sh` AND `lib/apply.sh`.

3. **`apply.sh` skips existing files by default.** `--force` is the
   only way to overwrite. Never change that default.

4. **`audit.sh` exits non-zero when files are missing.** The exit
   code is part of the contract for CI integrations.

5. **`protect.sh` degrades gracefully.** Every GitHub API call is
   wrapped in `|| warn`. A free-private repo running `protect` should
   end with workflow guards in place and a clear notice about what
   wasn't available.

## When adding a new template

1. Drop the file in `templates/` (`.tmpl` extension if it carries
   `${GR_*}` placeholders; plain name if verbatim).
2. Add the destination path to the `apply_file` calls in
   `lib/apply.sh`.
3. Add the destination path to the `EXPECTED` array in `lib/audit.sh`.
4. Run `bash bin/guardrail apply --dry-run` in a scratch dir to
   confirm.
5. Document in `README.md` under "Templates shipped".

## Slash commands (this repo ships them at `.claude/commands/`)

Users who want guardrail to be one slash command in their projects
can copy or symlink these to `~/.claude/commands/`. The commands
shell out to `bin/guardrail`.

- `/guardrail-init` — interactive setup (the front door)
- `/guardrail-audit` — what's missing
- `/guardrail-protect` — GitHub side configuration
- `/guardrail-signing` — local SSH signing

## MCP server (`mcp/server.py`)

stdio MCP server exposing the same operations as tools:
`apply`, `audit`, `protect`, `signing_setup`, `list_templates`.
This is the path for agents that prefer tool calls over shell
invocation. Configure in Claude Code with:

```bash
guardrail mcp install   # prints the JSON snippet
```

## Don't do

- Don't add a license other than AGPL-3.0, MIT, or Apache-2.0 unless
  the user asks. Three is a deliberate menu, not an oversight.
- Don't push directly to `main`. guardrail eats its own dogfood —
  branch + PR + signed commit.
- Don't bypass DCO sign-off. The `dco.yml` we ship is configured to
  catch unsigned commits; the same workflow is in *this* repo.
