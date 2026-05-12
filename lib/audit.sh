#!/usr/bin/env bash
# audit.sh — report which guardrail files are present and which are missing.

set -euo pipefail
source "$GUARDRAIL_HOME/lib/common.sh"
require_repo

cd "$(repo_root)"

EXPECTED=(
  "LICENSE"
  "NOTICE"
  "TRADEMARK.md"
  "CODE_OF_CONDUCT.md"
  "CONTRIBUTING.md"
  "SECURITY.md"
  "CODEOWNERS"
  "CHANGELOG.md"
  ".github/workflows/dco.yml"
  ".github/workflows/lint.yml"
  ".github/workflows/auto-merge-dependabot.yml"
  ".github/dependabot.yml"
  ".github/PULL_REQUEST_TEMPLATE.md"
  ".github/ISSUE_TEMPLATE/config.yml"
  ".github/ISSUE_TEMPLATE/bug_report.yml"
  ".github/ISSUE_TEMPLATE/feature_request.yml"
  ".github/ISSUE_TEMPLATE/trademark.yml"
  ".github/FUNDING.yml"
)

note "Auditing $(pwd)"
echo ""
present=0; missing=0
for f in "${EXPECTED[@]}"; do
  if [ -f "$f" ]; then
    ok "$f"
    present=$((present+1))
  else
    warn "missing: $f"
    missing=$((missing+1))
  fi
done

echo ""
note "Summary: $present present / $missing missing (of ${#EXPECTED[@]} total)"

if [ $missing -gt 0 ]; then
  echo ""
  note "To add the missing files:  guardrail apply"
  exit 1
fi

# Extra checks once everything is present.
echo ""
note "Extra hygiene checks..."

if [ -f .gitignore ] && grep -qE '(^|/)\.env(\s|$)' .gitignore; then
  ok ".env is gitignored"
else
  warn ".env is NOT in .gitignore (consider adding it)"
fi

if git ls-files | grep -qE '(^|/)\.env$'; then
  warn ".env file appears to be tracked (it should not be)"
else
  ok "no .env file tracked"
fi

if [ -f .git/hooks/pre-commit ] || [ -f .pre-commit-config.yaml ]; then
  ok "a pre-commit setup is present"
else
  dim "  no pre-commit hook configured (optional)"
fi

# Check git signing config
fmt=$(git config gpg.format 2>/dev/null || echo "")
sign=$(git config commit.gpgsign 2>/dev/null || echo "")
if [ "$fmt" = "ssh" ] && [ "$sign" = "true" ]; then
  ok "SSH commit signing is configured"
else
  warn "SSH commit signing is not configured (run 'guardrail signing')"
fi

echo ""
ok "Audit complete."
