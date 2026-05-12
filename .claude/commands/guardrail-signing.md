---
description: Configure local SSH commit signing in the current repo.
allowed-tools: [Bash]
---

Run `guardrail signing` to set up SSH commit signing locally.

```bash
guardrail signing
```

The CLI:

1. Finds an SSH key in `~/.ssh/` (prefers `id_ed25519`).
2. Sets `gpg.format=ssh`, `user.signingkey`, `commit.gpgsign=true`,
   `tag.gpgsign=true` in the local repo config.
3. Adds the user's email + key to `~/.config/git/allowed_signers` so
   `git log --show-signature` verifies locally.
4. Prints the two-line follow-up to register the same key as a
   SIGNING key on GitHub (gh auth refresh + gh api POST).

## After signing

Confirm signing works with an empty test commit (don't push):

```bash
git commit --allow-empty -m 'test signing' && git log -1 --show-signature
```

Then propose the gh registration step; only run it if the user
confirms. The OAuth scope `admin:ssh_signing_key` is required.
