#!/usr/bin/env bash
#
# verify.sh — one-shot quality gate for the didwebvh-dart workspace.
# The Dart analog of the Java project's `./mvnw clean verify`:
#
#   1. dart pub get          (resolves the whole pub workspace)
#   2. dart analyze          (workspace-wide, infos are fatal — very_good_analysis)
#   3. dart test             (every package that has a test/ dir)
#
# `dart test` is per-package in a pub workspace, so this script discovers each
# package under packages/ that has a test/ directory and runs its suite. Coverage
# is collected for didwebvh_core (the package that carries the 80% gate); pass
# --coverage to also write packages/didwebvh_core/coverage/lcov.info.
#
# Usage:
#   tool/verify.sh             # pub get + analyze + all tests
#   tool/verify.sh --coverage  # also emit lcov for didwebvh_core
set -euo pipefail

# Resolve repo root from this script's location so it works from any cwd.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

WITH_COVERAGE=0
if [[ "${1:-}" == "--coverage" ]]; then
  WITH_COVERAGE=1
fi

bold() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

bold "dart pub get (workspace)"
dart pub get

bold "dart analyze --fatal-infos (workspace)"
dart analyze --fatal-infos

failed=0
ran_any=0
for pkg in packages/*/; do
  [[ -d "${pkg}test" ]] || continue
  name="$(basename "$pkg")"
  ran_any=1
  if [[ "$name" == "didwebvh_core" && "$WITH_COVERAGE" -eq 1 ]]; then
    bold "dart test --coverage ($name)"
    if ( cd "$pkg" && dart test --coverage=coverage ); then
      ( cd "$pkg"
        dart pub global activate coverage >/dev/null 2>&1 || true
        dart pub global run coverage:format_coverage \
          --lcov --in=coverage --out=coverage/lcov.info \
          --report-on=lib --package=. )
    else
      failed=1
    fi
  else
    bold "dart test ($name)"
    ( cd "$pkg" && dart test ) || failed=1
  fi
done

if [[ "$ran_any" -eq 0 ]]; then
  echo "No package under packages/ has a test/ directory." >&2
fi

if [[ "$failed" -ne 0 ]]; then
  bold "VERIFY FAILED"
  exit 1
fi

bold "VERIFY OK"
