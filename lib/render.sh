#!/usr/bin/env bash
# render.sh — substitute ${GR_*} env vars in a template file.
#
# Usage: render.sh <template-path>
# Outputs to stdout.

set -euo pipefail

src="$1"
[ -f "$src" ] || { echo "render: source not found: $src" >&2; exit 1; }

# Use envsubst if available — restricts substitution to declared vars
# so accidental $VAR-like strings in the template aren't touched.
if command -v envsubst >/dev/null 2>&1; then
  envsubst '${GR_PROJECT} ${GR_LICENSE} ${GR_AUTHOR} ${GR_GH_USER} ${GR_YEAR} ${GR_PROJECT_LOWER} ${GR_PROJECT_TITLE}' < "$src"
else
  # Pure-sed fallback. Escapes for sed's left-hand side.
  esc() { printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'; }
  sed \
    -e "s/\${GR_PROJECT}/$(esc "${GR_PROJECT:-}")/g" \
    -e "s/\${GR_PROJECT_LOWER}/$(esc "${GR_PROJECT_LOWER:-}")/g" \
    -e "s/\${GR_PROJECT_TITLE}/$(esc "${GR_PROJECT_TITLE:-}")/g" \
    -e "s/\${GR_LICENSE}/$(esc "${GR_LICENSE:-}")/g" \
    -e "s/\${GR_AUTHOR}/$(esc "${GR_AUTHOR:-}")/g" \
    -e "s/\${GR_GH_USER}/$(esc "${GR_GH_USER:-}")/g" \
    -e "s/\${GR_YEAR}/$(esc "${GR_YEAR:-}")/g" \
    "$src"
fi
