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
# is collected for didwebvh (the package that carries the 80% gate); pass
# --coverage to also write packages/didwebvh/coverage/lcov.info.
#
# Usage:
#   tool/verify.sh             # pub get + analyze + all tests
#   tool/verify.sh --coverage  # also emit lcov for didwebvh
set -euo pipefail

# Resolve repo root from this script's location so it works from any cwd.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

WITH_COVERAGE=0
if [[ "${1:-}" == "--coverage" ]]; then
  WITH_COVERAGE=1
fi

bold() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

bold "version.g.dart freshness"
WIZ_PUBSPEC="packages/didwebvh_wizard/pubspec.yaml"
WIZ_VERSION_FILE="packages/didwebvh_wizard/lib/src/version.g.dart"
expected_version="$(grep -E '^version:' "$WIZ_PUBSPEC" | head -1 | sed -E 's/^version:[[:space:]]*//' | tr -d '[:space:]')"
actual_version="$(sed -nE "s/.*packageVersion = '([^']+)'.*/\1/p" "$WIZ_VERSION_FILE")"
if [[ "$expected_version" != "$actual_version" ]]; then
  echo "version.g.dart is stale: pubspec is '$expected_version' but version.g.dart is '$actual_version'." >&2
  echo "Regenerate with: (cd packages/didwebvh_wizard && dart run tool/generate_version.dart)" >&2
  echo "or bump everything at once with: tool/bump-version.sh" >&2
  exit 1
fi
echo "version.g.dart matches pubspec ($expected_version)"

bold "README version honesty"
# The README install snippet pins "name: ^X" constraints; every such version
# must match that package's actual pubspec version, or the docs are lying.
readme_fail=0
for pkg in didwebvh didwebvh_signing_local didwebvh_wizard; do
  pkg_version="$(grep -E '^version:' "packages/$pkg/pubspec.yaml" | head -1 | sed -E 's/^version:[[:space:]]*//' | tr -d '[:space:]')"
  # Grep "name: ^X" — the colon+space guards against didwebvh matching as a
  # prefix of didwebvh_signing_local / didwebvh_wizard.
  while IFS= read -r readme_version; do
    [[ -z "$readme_version" ]] && continue
    if [[ "$readme_version" != "$pkg_version" ]]; then
      echo "README pins $pkg: ^$readme_version but packages/$pkg/pubspec.yaml is $pkg_version" >&2
      readme_fail=1
    fi
  done < <(grep -oE "${pkg}: \\^[0-9][0-9A-Za-z.+-]*" README.md | sed -E 's/.*\^//' | sort -u)
done
if [[ "$readme_fail" -ne 0 ]]; then
  echo "Fix the README install snippet (or run tool/bump-version.sh) so its versions match the pubspecs." >&2
  exit 1
fi
echo "README package versions match pubspecs"

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
  if [[ "$name" == "didwebvh" && "$WITH_COVERAGE" -eq 1 ]]; then
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
