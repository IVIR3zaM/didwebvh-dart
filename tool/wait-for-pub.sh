#!/usr/bin/env bash
#
# wait-for-pub.sh — block until <package> <version> is listed on pub.dev.
#
# Used by .github/workflows/publish.yml so a dependent package is only
# published once its dependency's new version is actually resolvable from
# pub.dev (the server validates `^x.y.z` constraints against published
# versions). curl + jq are preinstalled on GitHub's ubuntu-latest runners.
#
# Usage: tool/wait-for-pub.sh <package> <version>
set -euo pipefail

pkg="${1:?package name required}"
version="${2:?version required}"

attempts=30
delay=10

for i in $(seq 1 "$attempts"); do
  if curl -fsSL "https://pub.dev/api/packages/$pkg" \
       | jq -e --arg v "$version" '.versions[]?.version | select(. == $v)' \
       >/dev/null 2>&1; then
    echo "$pkg $version is available on pub.dev"
    exit 0
  fi
  echo "waiting for $pkg $version on pub.dev ($i/$attempts)..."
  sleep "$delay"
done

echo "timed out waiting for $pkg $version on pub.dev" >&2
exit 1
