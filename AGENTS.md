# guardrail — operating contract for autonomous agents

> **Read this first if you are an autonomous agent (Codex, Claude, or
> any other) opening this repository.**

guardrail is a single-binary bash toolkit that drops a vetted set of
governance / security / CI files into any repository, then configures
the corresponding GitHub repo settings via the gh API.

## Hard rules — every agent obeys these

1. **One CLI, no hidden state.** `bin/guardrail` is the entrypoint.
   Templates live in `templates/`. Helpers live in `lib/`. There is
   no daemon, no database, no remote service.

2. **No new runtime deps in the core CLI.** `bash`, `git`, `gh`. The
   optional MCP server (`mcp/`) is the only place Python is allowed.

3. **Templates use `${GR_*}` variables only** — `GR_PROJECT`,
   `GR_PROJECT_LOWER`, `GR_PROJECT_TITLE`, `GR_LICENSE`, `GR_AUTHOR`,
   `GR_GH_USER`, `GR_YEAR`. Substitution happens in `lib/render.sh`.

4. **`apply` is non-destructive by default.** Existing files are
   skipped. `--force` is required to overwrite. This is a guarantee,
   not a default that can be inverted.

5. **`protect` degrades gracefully.** Wrap every gh API call in
   `|| warn`. Free-private repos don't get branch protection — that
   is a known plan limitation, not a bug.

6. **DCO sign-off + signed commits on every commit to this repo.**
   guardrail eats its own dogfood. Use `git commit -s` and make sure
   `commit.gpgsign=true` is configured locally
   (`guardrail signing` does this).

7. **Templates are content-licensed, not code-licensed.** The
   `templates/LICENSE/AGPL-3.0.txt`, `MIT.txt`, and `Apache-2.0.txt`
   files carry the verbatim text of those licenses and must not be
   modified except to add `${GR_*}` placeholders where the license
   text expects a year/owner.

## How to add a new template

1. Place the file in `templates/` (`.tmpl` if it has `${GR_*}`
   placeholders; plain otherwise).
2. Wire it into `lib/apply.sh` (the `apply_file` calls).
3. Wire it into `lib/audit.sh` (the `EXPECTED` array).
4. Smoke-test:
   ```bash
   mkdir /tmp/test && cd /tmp/test && git init -b main
   bash $GUARDRAIL_HOME/bin/guardrail apply --license=MIT --name=test \
        --author='Test' --gh-user=test --dry-run
   ```
5. Document it in `README.md`.

## How to add a new gh API config to `protect`

1. Wrap the API call in `gh api ... --silent 2>/dev/null && ok "..." || warn "..."`.
2. If the call is plan-gated (e.g. only works on Pro/public), the
   `warn` branch should clearly say so — "not available on free
   private" / "needs Pro" — so the user knows what's missing rather
   than thinking the script failed.

## Where to write your notes

If you're an autonomous agent doing multi-step work in this repo:

- Multi-step plans → `docs/plans/YYYY-MM-DD-<slug>.md`
- Architectural decisions → `docs/decisions/NNN-<slug>.md`
- Research / scrapes → `docs/research/<topic>.md`

These directories don't have to exist; create them when needed.

## Tests / smoke

There is no formal test suite (yet). The smoke check is:

```bash
mkdir /tmp/gr-smoke && cd /tmp/gr-smoke && git init -b main --quiet
guardrail apply --license=AGPL-3.0 --name=smoke --author='Test' --gh-user=test
guardrail audit   # should exit 0
```

If you change `lib/`, run that smoke before opening a PR.

## Known invariants (don't break these)

- The three required CI status check names — `DCO sign-off`,
  `Conventional commit titles`, `Pre-commit secret scan (gitleaks)`
  — are baked into `templates/workflows/` AND into `protect.sh`'s
  branch-protection JSON. They must match exactly. If you rename a
  job, update both places.
- The MCP server's tool names — `apply`, `audit`, `protect`,
  `signing_setup`, `list_templates` — are the public surface for any
  agent integrated via MCP. Don't rename without bumping the major
  version.
- `bin/guardrail` is the only entrypoint other tools should invoke.
  Don't add a second binary; add a subcommand.
