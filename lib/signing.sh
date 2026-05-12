#!/usr/bin/env bash
# signing.sh — configure local SSH commit signing in the current repo.

set -euo pipefail
source "$GUARDRAIL_HOME/lib/common.sh"
require_repo

cd "$(repo_root)"

# Find an SSH key
SSH_KEY=""
for k in ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa.pub; do
  [ -f "$k" ] && SSH_KEY="$k" && break
done
if [ -z "$SSH_KEY" ]; then
  warn "no SSH key found in ~/.ssh/"
  note "Generate one with:  ssh-keygen -t ed25519 -C 'you@example.com'"
  exit 1
fi

EMAIL="$(git config user.email 2>/dev/null || true)"
if [ -z "$EMAIL" ]; then
  die "git user.email is not set in this repo (run: git config user.email 'you@example.com')"
fi

note "SSH key:  $SSH_KEY"
note "Email:    $EMAIL"
echo ""

git config --local gpg.format ssh
git config --local user.signingkey "$SSH_KEY"
git config --local commit.gpgsign true
git config --local tag.gpgsign true

# allowed_signers — the file git uses to verify signatures locally.
mkdir -p ~/.config/git
ALLOWED=~/.config/git/allowed_signers
KEY_PORTION="$(cut -d' ' -f1-2 "$SSH_KEY")"
if [ -f "$ALLOWED" ] && grep -Fq "$EMAIL $KEY_PORTION" "$ALLOWED"; then
  dim "  allowed_signers already contains this entry"
else
  printf '%s %s\n' "$EMAIL" "$KEY_PORTION" >> "$ALLOWED"
  ok "added $EMAIL to ~/.config/git/allowed_signers"
fi
git config --local gpg.ssh.allowedSignersFile "$ALLOWED"

echo ""
ok "Local SSH signing configured."
echo ""
note "To show 'Verified' on GitHub commits, register the same key as a"
note "SIGNING key (in addition to its authentication role) on GitHub:"
echo ""
echo "  gh auth refresh -h github.com -s admin:ssh_signing_key"
echo "  gh api -X POST /user/ssh_signing_keys \\"
echo "    -f title='guardrail-signing' -f key=\"\$(cat $SSH_KEY)\""
echo ""
note "Test that signing works:"
echo ""
echo "  git commit --allow-empty -m 'test signing' && git log -1 --show-signature"
