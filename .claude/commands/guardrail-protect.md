---
description: Configure GitHub repo settings + branch protection via gh API.
allowed-tools: [Bash]
---

Run `guardrail protect` to apply the GitHub-side configuration.

```bash
guardrail protect              # current repo
guardrail protect owner/repo   # an explicit repo
```

The CLI tries every layer and reports what worked / what wasn't
available on this plan:

- Repo defaults (no wiki, no projects, no rebase-merge; auto-delete
  branch on merge; auto-merge on)
- Dependabot vulnerability alerts + automated security fixes
- Actions allowlist (GitHub-owned + verified + gitleaks +
  dependabot/fetch-metadata + peter-evans/*)
- Workflows default to read-only; can't auto-approve PRs
- Forks can't trigger workflows (private only)
- Secret scanning + push protection (public OR Pro private)
- Branch protection on `main` (public OR Pro private)
- Required signed commits (when branch protection is available)

## Prerequisites

- `gh` is installed and authenticated.
- The workflow files (`dco.yml`, `lint.yml`,
  `auto-merge-dependabot.yml`) are already on `main`. If they aren't,
  ask the user to commit + push them first, then re-run protect.

## After protect

If branch protection went on, also recommend:

> Register your SSH key as a signing key on GitHub so commits show
> "Verified":
>
> ```bash
> gh auth refresh -s admin:ssh_signing_key
> gh api -X POST /user/ssh_signing_keys \
>   -f title='guardrail' -f key="$(cat ~/.ssh/id_ed25519.pub)"
> ```

If branch protection wasn't available (free private), say so
explicitly so the user understands the limit and can decide whether
to upgrade to GitHub Pro or make the repo public.
