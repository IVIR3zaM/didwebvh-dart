#!/usr/bin/env bash
#
# changelog-extract.sh — print one version's section from a CHANGELOG file.
#
# Used by CI to turn the CHANGELOG into GitHub release notes (the same way the
# didwebvh-java reference derives its release body from the changelog). Prints
# the body between the version's header and the next "## " header, with
# surrounding blank lines trimmed. Accepts both changelog styles used in this
# repo: the root's Keep a Changelog "## [VERSION] - DATE" and the per-package
# plain "## VERSION - DATE".
#
# Usage:
#   tool/changelog-extract.sh <version> [changelog-file]
#
#   tool/changelog-extract.sh 0.1.2                 # reads ./CHANGELOG.md
#   tool/changelog-extract.sh 0.1.2 CHANGELOG.md
set -euo pipefail

VERSION="${1:?usage: changelog-extract.sh <version> [changelog-file]}"
FILE="${2:-CHANGELOG.md}"
[[ -f "$FILE" ]] || { echo "changelog-extract: no such file: $FILE" >&2; exit 1; }

# Match the header line literally — either "## [VERSION]" (root, Keep a
# Changelog) or "## VERSION" (per-package, plain) — so no regex escaping of the
# dots/dashes in the version is needed. The plain prefix has a trailing space so
# it can't match a longer version (e.g. "## 0.1.1" must not match "0.1.10").
# Collect lines until the next "## " heading, then trim blank lines.
awk -v bpfx="## [${VERSION}]" -v ppfx="## ${VERSION} " '
  index($0, bpfx) == 1 || index($0 " ", ppfx) == 1 { grab = 1; next }
  grab && index($0, "## ") == 1 { exit }
  grab { buf[n++] = $0 }
  END {
    start = 0; end = n - 1
    while (start <= end && buf[start] ~ /^[[:space:]]*$/) start++
    while (end >= start && buf[end]   ~ /^[[:space:]]*$/) end--
    for (i = start; i <= end; i++) print buf[i]
  }
' "$FILE"
