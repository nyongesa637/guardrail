---
description: Audit the current repo for missing guardrail governance files.
allowed-tools: [Bash]
---

Run `guardrail audit` in the user's current repository and surface
the result.

```bash
guardrail audit
```

The CLI:
- prints a checkmark per present file, a warning per missing file,
- runs extra hygiene checks (`.env` gitignored, no `.env` tracked,
  pre-commit hook present, SSH signing configured),
- exits 0 when everything is present and 1 otherwise.

## After the audit

If files are missing, suggest exactly one follow-up:

> Run `guardrail apply` to add the missing files.

If a hygiene check warned about `.env` or signing, suggest the
specific fix:

- `.env` not gitignored → append it to `.gitignore`.
- `.env` tracked → `git rm --cached .env` + add to `.gitignore`.
- SSH signing not configured → `guardrail signing`.

Don't run any of these without explicit user confirmation. Audit is
read-only.
