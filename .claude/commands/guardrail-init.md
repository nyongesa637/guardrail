---
description: Bootstrap a repo with the guardrail governance pattern (interactive).
allowed-tools: [Bash, AskUserQuestion]
---

You are about to run `guardrail init` in the user's current
repository. The CLI is interactive but you can pre-fill its answers
based on what you already know.

## Step 1 — confirm we're in a repo

```bash
git rev-parse --is-inside-work-tree
```

If that fails, ask the user to `cd` to the target repo first, then
stop.

## Step 2 — gather the four inputs

Defaults:
- Project name → `basename $(git rev-parse --show-toplevel)`
- License → AGPL-3.0 (offer MIT or Apache-2.0 if the user wants
  something more permissive)
- Author → `git config user.name`
- GitHub username → `gh api user --jq '.login'`

Use **AskUserQuestion** to confirm the license choice (it's the only
one that's hard to reverse later):

> Pick a license:
> - AGPL-3.0 (network copyleft — recommended for SaaS-protective projects)
> - MIT (maximally permissive)
> - Apache-2.0 (permissive + explicit patent grant)

Skip AskUserQuestion for the other three values — accept the
detected defaults unless they're empty.

## Step 3 — run apply

```bash
guardrail apply \
  --license=<chosen> \
  --name="<project>" \
  --author="<author>" \
  --gh-user=<login>
```

Capture the output and surface any warnings to the user.

## Step 4 — offer the follow-ups

Tell the user what to do next, but do NOT auto-run any of these
without their explicit confirmation:

```
1. Review TRADEMARK.md and NOTICE.
2. git add -A && git commit -s -m "chore(governance): adopt guardrail pattern"
3. guardrail signing      # local SSH commit signing
4. guardrail protect      # GitHub repo settings + branch protection
5. guardrail audit        # final verification
```

If the repo is on GitHub and the user wants the full bootstrap,
sequence `commit → push → protect`. Otherwise stop after the apply.

## Don't

- Don't overwrite existing files. `guardrail apply` skips them by
  default; that's the safe behaviour.
- Don't run `protect` before the workflow files are on `main` — the
  branch-protection rule needs them to exist first.
- Don't bypass user confirmation on irreversible steps (license
  choice, pushing to remote).
