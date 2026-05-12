#!/usr/bin/env bash
# apply.sh — render every template into the current repo.

set -euo pipefail
source "$GUARDRAIL_HOME/lib/common.sh"

INTERACTIVE=false
LICENSE="AGPL-3.0"
PROJECT_NAME=""
AUTHOR=""
GH_USER=""
DRY_RUN=false
FORCE=false

while [ $# -gt 0 ]; do
  case "$1" in
    --interactive)   INTERACTIVE=true; shift ;;
    --license=*)     LICENSE="${1#*=}"; shift ;;
    --name=*)        PROJECT_NAME="${1#*=}"; shift ;;
    --author=*)      AUTHOR="${1#*=}"; shift ;;
    --gh-user=*)     GH_USER="${1#*=}"; shift ;;
    --dry-run)       DRY_RUN=true; shift ;;
    --force)         FORCE=true; shift ;;
    -h|--help)
      cat <<'EOF'
usage: guardrail apply [flags]
       guardrail init   (alias for `apply --interactive`)

flags:
  --license=AGPL-3.0|MIT|Apache-2.0   default AGPL-3.0
  --name=<project>                     default: directory basename
  --author='<Name>'                    default: git config user.name
  --gh-user=<login>                    default: gh api user (if signed in)
  --force                              overwrite existing files
  --dry-run                            show what would happen
EOF
      exit 0
      ;;
    *) die "unknown flag: $1" ;;
  esac
done

require_repo
require_cmd git

ROOT="$(repo_root)"
cd "$ROOT"

[ -z "$PROJECT_NAME" ] && PROJECT_NAME="$(basename "$ROOT")"
[ -z "$AUTHOR" ] && AUTHOR="$(git config user.name 2>/dev/null || echo 'Unknown')"
if [ -z "$GH_USER" ] && command -v gh >/dev/null; then
  GH_USER="$(gh api user --jq '.login' 2>/dev/null || echo '')"
fi

if $INTERACTIVE; then
  echo ""
  read -r -p "Project name [$PROJECT_NAME]: " r;  PROJECT_NAME="${r:-$PROJECT_NAME}"
  echo "Licenses: AGPL-3.0 (default), MIT, Apache-2.0"
  read -r -p "License [$LICENSE]: " r;            LICENSE="${r:-$LICENSE}"
  read -r -p "Author [$AUTHOR]: " r;              AUTHOR="${r:-$AUTHOR}"
  read -r -p "GitHub username [$GH_USER]: " r;    GH_USER="${r:-$GH_USER}"
  echo ""
fi

# Normalise the license string.
case "$(echo "$LICENSE" | tr '[:lower:]' '[:upper:]')" in
  AGPL-3.0|AGPLV3|AGPL)   LICENSE="AGPL-3.0" ;;
  MIT)                    LICENSE="MIT" ;;
  APACHE-2.0|APACHE)      LICENSE="Apache-2.0" ;;
  *) die "unsupported license: $LICENSE (expected AGPL-3.0, MIT, or Apache-2.0)" ;;
esac

PROJECT_LOWER="$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')"
PROJECT_TITLE="$(echo "$PROJECT_NAME" | awk '{ for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2) } 1')"

export GR_PROJECT="$PROJECT_NAME"
export GR_PROJECT_LOWER="$PROJECT_LOWER"
export GR_PROJECT_TITLE="$PROJECT_TITLE"
export GR_LICENSE="$LICENSE"
export GR_AUTHOR="$AUTHOR"
export GR_GH_USER="$GH_USER"
export GR_YEAR="$(date +%Y)"

note "Target:     $ROOT"
note "Project:    $PROJECT_NAME"
note "License:    $LICENSE"
note "Author:     $AUTHOR"
note "GH user:    ${GH_USER:-<none>}"
$DRY_RUN && note "Mode:       dry-run (no files will be written)"
$FORCE   && note "Mode:       --force (existing files will be overwritten)"
echo ""

apply_file() {
  # apply_file <source-in-templates> <destination-in-repo>
  local src="$GUARDRAIL_HOME/templates/$1"
  local dst="$2"
  if [ ! -f "$src" ]; then
    warn "template missing in guardrail: $1 (skipping)"
    return
  fi
  if [ -e "$dst" ] && ! $FORCE; then
    dim "  skip (exists): $dst"
    return
  fi
  if $DRY_RUN; then
    note "  would write:   $dst"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  bash "$GUARDRAIL_HOME/lib/render.sh" "$src" > "$dst"
  ok "  wrote:         $dst"
}

# License files may carry ${GR_YEAR} / ${GR_AUTHOR} placeholders (MIT
# and Apache-2.0 do; AGPL is verbatim with no placeholders).
copy_license() {
  local src="$GUARDRAIL_HOME/templates/LICENSE/${LICENSE}.txt"
  [ -f "$src" ] || die "license file missing: $src"
  if [ -e "LICENSE" ] && ! $FORCE; then
    dim "  skip (exists): LICENSE"
    return
  fi
  $DRY_RUN && { note "  would write:   LICENSE"; return; }
  bash "$GUARDRAIL_HOME/lib/render.sh" "$src" > "LICENSE"
  ok "  wrote:         LICENSE"
}

note "Writing root governance files..."
copy_license
apply_file "NOTICE.tmpl"                          "NOTICE"
apply_file "TRADEMARK.md.tmpl"                    "TRADEMARK.md"
apply_file "CODE_OF_CONDUCT.md.tmpl"              "CODE_OF_CONDUCT.md"
apply_file "CONTRIBUTING.md.tmpl"                 "CONTRIBUTING.md"
apply_file "SECURITY.md.tmpl"                     "SECURITY.md"
apply_file "CODEOWNERS.tmpl"                      "CODEOWNERS"
apply_file "CHANGELOG.md.tmpl"                    "CHANGELOG.md"

echo ""
note "Writing .github/..."
apply_file "workflows/dco.yml"                    ".github/workflows/dco.yml"
apply_file "workflows/lint.yml"                   ".github/workflows/lint.yml"
apply_file "workflows/auto-merge-dependabot.yml"  ".github/workflows/auto-merge-dependabot.yml"
apply_file "dependabot.yml.tmpl"                  ".github/dependabot.yml"
apply_file "PULL_REQUEST_TEMPLATE.md.tmpl"        ".github/PULL_REQUEST_TEMPLATE.md"
apply_file "ISSUE_TEMPLATE/config.yml.tmpl"       ".github/ISSUE_TEMPLATE/config.yml"
apply_file "ISSUE_TEMPLATE/bug_report.yml.tmpl"   ".github/ISSUE_TEMPLATE/bug_report.yml"
apply_file "ISSUE_TEMPLATE/feature_request.yml.tmpl" ".github/ISSUE_TEMPLATE/feature_request.yml"
apply_file "ISSUE_TEMPLATE/trademark.yml.tmpl"    ".github/ISSUE_TEMPLATE/trademark.yml"
apply_file "FUNDING.yml.tmpl"                     ".github/FUNDING.yml"

# Persist the config so subsequent `guardrail audit` / `apply` use the same
# values.
if ! $DRY_RUN; then
  mkdir -p .guardrail
  cat > .guardrail/config <<EOF
GR_PROJECT="$PROJECT_NAME"
GR_LICENSE="$LICENSE"
GR_AUTHOR="$AUTHOR"
GR_GH_USER="$GH_USER"
GR_YEAR="$GR_YEAR"
EOF
fi

echo ""
ok "guardrail apply complete."
echo ""
note "Next steps:"
note "  1. Review TRADEMARK.md and NOTICE — they reference your project name and author."
note "  2. Stage and commit:  git add -A && git commit -s -m 'chore(governance): adopt guardrail pattern'"
note "  3. Local SSH signing: guardrail signing"
note "  4. Configure GitHub:  guardrail protect"
note "  5. Audit anytime:     guardrail audit"
