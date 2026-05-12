#!/usr/bin/env bash
# protect.sh — configure GitHub repo settings & branch protection
#               via the gh API. Graceful on free private repos.

set -euo pipefail
source "$GUARDRAIL_HOME/lib/common.sh"
require_cmd gh

REPO="${1:-}"
if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo '')"
fi
[ -z "$REPO" ] && die "could not determine repo. Pass owner/repo as the first arg, or run from inside a linked repo."

VIS="$(gh repo view "$REPO" --json visibility --jq '.visibility' 2>/dev/null || echo 'UNKNOWN')"

note "Target:     $REPO"
note "Visibility: $VIS"
echo ""

# -------- 1. repo defaults (always available) --------
note "Repo defaults..."
gh repo edit "$REPO" \
  --enable-wiki=false \
  --enable-discussions=true \
  --enable-issues=true \
  --enable-projects=false \
  --enable-squash-merge \
  --enable-merge-commit \
  --enable-rebase-merge=false \
  --delete-branch-on-merge \
  --enable-auto-merge \
  --allow-update-branch >/dev/null 2>&1 \
  && ok "  no wiki, no projects, no rebase-merge; auto-delete on merge; auto-merge on" \
  || warn "  some repo settings failed; continuing"

# -------- 2. Dependabot (always available) --------
echo ""
note "Dependabot..."
gh api -X PUT "/repos/$REPO/vulnerability-alerts" --silent 2>/dev/null \
  && ok "  vulnerability alerts enabled" \
  || warn "  vulnerability alerts: not enabled"
gh api -X PUT "/repos/$REPO/automated-security-fixes" --silent 2>/dev/null \
  && ok "  automated security fixes enabled" \
  || warn "  automated security fixes: not enabled"

# -------- 3. Actions permissions (works on free private) --------
echo ""
note "Actions permissions..."
if gh api -X PUT "/repos/$REPO/actions/permissions" -F enabled=true -f allowed_actions=selected --silent 2>/dev/null; then
  ok "  allowed_actions=selected"
  tmp=$(mktemp)
  cat > "$tmp" <<'JSON'
{
  "github_owned_allowed": true,
  "verified_allowed": true,
  "patterns_allowed": [
    "gitleaks/gitleaks-action@*",
    "dependabot/fetch-metadata@*",
    "peter-evans/*@*"
  ]
}
JSON
  gh api -X PUT "/repos/$REPO/actions/permissions/selected-actions" --input "$tmp" --silent 2>/dev/null \
    && ok "  allowlist: github-owned + verified + (gitleaks, dependabot/fetch-metadata, peter-evans/*)"
  rm -f "$tmp"
else
  warn "  could not set actions allowlist"
fi

gh api -X PUT "/repos/$REPO/actions/permissions/workflow" \
  -F default_workflow_permissions=read -F can_approve_pull_request_reviews=false --silent 2>/dev/null \
  && ok "  workflows default to read-only; can't auto-approve PRs"

if [ "$VIS" = "PRIVATE" ]; then
  gh api -X PUT "/repos/$REPO/actions/permissions/access" -f access_level=none --silent 2>/dev/null \
    && ok "  forks cannot trigger workflows"
fi

# -------- 4. Secret scanning (public OR Pro private) --------
echo ""
note "Secret scanning..."
if gh api -X PATCH "/repos/$REPO" \
     -F security_and_analysis[secret_scanning][status]=enabled \
     -F security_and_analysis[secret_scanning_push_protection][status]=enabled --silent 2>/dev/null; then
  ok "  secret scanning + push protection enabled"
else
  warn "  not available on this plan (free private has no secret scanning)"
fi

# -------- 5. Branch protection (public OR Pro private) --------
echo ""
note "Branch protection on main..."
tmp=$(mktemp)
cat > "$tmp" <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["DCO sign-off", "Conventional commit titles", "Pre-commit secret scan (gitleaks)"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 0,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": true,
  "required_signatures": false
}
JSON
if gh api -X PUT "/repos/$REPO/branches/main/protection" --input "$tmp" --silent 2>/dev/null; then
  ok "  branch protection: PR-only, no force-push, no delete, conversation resolution"
  if gh api -X POST "/repos/$REPO/branches/main/protection/required_signatures" --silent 2>/dev/null; then
    ok "  required signed commits"
  fi
else
  warn "  not available on this plan (free private — branch protection is Pro/public)"
  warn "  → workflows still run on every PR (DCO, lint, gitleaks) but they're advisory"
fi
rm -f "$tmp"

echo ""
ok "Done configuring $REPO"
