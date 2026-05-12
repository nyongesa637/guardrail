#!/usr/bin/env bash
# list.sh — list templates this guardrail ships.

set -euo pipefail
source "$GUARDRAIL_HOME/lib/common.sh"

note "Templates shipped with guardrail:"
echo ""

(cd "$GUARDRAIL_HOME/templates" && find . -type f \( -name '*.tmpl' -o -name '*.yml' -o -name '*.txt' -o -name '*.md' \) | sort) | while read -r f; do
  echo "  $f"
done

echo ""
note "Variables available inside .tmpl files:"
echo "  \${GR_PROJECT}        project name as entered"
echo "  \${GR_PROJECT_LOWER}  lowercase"
echo "  \${GR_PROJECT_TITLE}  Title Case"
echo "  \${GR_LICENSE}        AGPL-3.0 | MIT | Apache-2.0"
echo "  \${GR_AUTHOR}         author name"
echo "  \${GR_GH_USER}        GitHub username"
echo "  \${GR_YEAR}           current year"
