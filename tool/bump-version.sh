#!/usr/bin/env bash
#
# bump-version.sh — interactive version-bump wizard for the didwebvh-dart workspace.
#
# All three packages (didwebvh, didwebvh_signing_local, didwebvh_wizard) are
# released in lockstep, so a bump touches every place the version appears:
#
#   1. version:        in each packages/*/pubspec.yaml
#   2. ^X constraints  (interdependencies in pubspecs + README install snippet)
#   3. version.g.dart  (regenerated from the wizard pubspec)
#   4. CHANGELOGs      (root + per-package): the Unreleased section is promoted
#                      to the new version with today's date, and a fresh empty
#                      Unreleased section is added on top
#
# The wizard asks how to bump (patch / minor / major) or accepts an explicit
# version, explains what the jump means, and always asks for confirmation.
# A downgrade triggers a loud red double-confirmation.
#
# Usage:
#   tool/bump-version.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# ---- colors -----------------------------------------------------------------
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  BLUE=$'\033[34m'; CYAN=$'\033[36m'; BG_RED=$'\033[41m\033[97m'
else
  BOLD=''; DIM=''; RESET=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BG_RED=''
fi

say()  { printf '%s\n' "$*"; }
hr()   { printf '%s\n' "${DIM}────────────────────────────────────────────────────────${RESET}"; }
die()  { printf '%s\n' "${RED}${BOLD}error:${RESET} $*" >&2; exit 1; }

# ---- semver helpers ---------------------------------------------------------
SEMVER_RE='^([0-9]+)\.([0-9]+)\.([0-9]+)(-[0-9A-Za-z.-]+)?$'

is_semver() { [[ "$1" =~ $SEMVER_RE ]]; }

# Echoes "major minor patch" core numbers for a semver string.
core() {
  [[ "$1" =~ $SEMVER_RE ]] || die "not a valid semver: $1"
  printf '%s %s %s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
}

# Returns 0 if $1 < $2 (by core numbers only), 1 otherwise.
is_lower() {
  read -r a1 a2 a3 <<<"$(core "$1")"
  read -r b1 b2 b3 <<<"$(core "$2")"
  (( a1 != b1 )) && { (( a1 < b1 )); return; }
  (( a2 != b2 )) && { (( a2 < b2 )); return; }
  (( a3 != b3 )) && { (( a3 < b3 )); return; }
  return 1
}

# Describes the relationship of $2 relative to current $1.
describe_jump() {
  local cur="$1" new="$2"
  read -r c1 c2 c3 <<<"$(core "$cur")"
  read -r n1 n2 n3 <<<"$(core "$new")"
  if   (( n1 > c1 )); then
    printf '%sMAJOR%s bump — signals %sbreaking changes%s to the public API.' "$RED$BOLD" "$RESET" "$BOLD" "$RESET"
  elif (( n1 == c1 && n2 > c2 )); then
    printf '%sMINOR%s bump — new backwards-compatible functionality.' "$YELLOW$BOLD" "$RESET"
  elif (( n1 == c1 && n2 == c2 && n3 > c3 )); then
    printf '%sPATCH%s bump — backwards-compatible bug fixes only.' "$GREEN$BOLD" "$RESET"
  elif [[ "$cur" == "$new" ]]; then
    printf 'the %ssame%s version (no change).' "$BOLD" "$RESET"
  else
    printf '%sa DOWNGRADE%s from the current version.' "$RED$BOLD" "$RESET"
  fi
}

confirm() { # confirm "question" -> 0 yes / 1 no
  local ans
  read -r -p "$1 ${DIM}[y/N]${RESET} " ans
  [[ "$ans" == [yY] || "$ans" == [yY][eE][sS] ]]
}

# Returns 0 (true) if the Unreleased section of $1 (delimited by header $2 and
# the next "## " heading) has no non-blank content lines.
unreleased_empty() { # file header
  awk -v hdr="$2" '
    $0 == hdr { grab = 1; next }
    grab && index($0, "## ") == 1 { exit }
    grab && /[^[:space:]]/ { found = 1; exit }
    END { exit (found ? 1 : 0) }
  ' "$1"
}

# ---- gather current state ---------------------------------------------------
PKG_PUBSPECS=(packages/*/pubspec.yaml)
SOURCE_PUBSPEC="packages/didwebvh/pubspec.yaml"

CURRENT="$(grep -E '^version:' "$SOURCE_PUBSPEC" | head -1 | sed -E 's/^version:[[:space:]]*//' | tr -d '[:space:]')"
is_semver "$CURRENT" || die "could not read a valid version from $SOURCE_PUBSPEC (got '$CURRENT')"

read -r CM Cm Cp <<<"$(core "$CURRENT")"
NEXT_PATCH="${CM}.${Cm}.$((Cp + 1))"
NEXT_MINOR="${CM}.$((Cm + 1)).0"
NEXT_MAJOR="$((CM + 1)).0.0"

clear 2>/dev/null || true
say ""
say "${BOLD}${CYAN}  didwebvh-dart — version bump wizard${RESET}"
hr
say "  current version: ${BOLD}${GREEN}${CURRENT}${RESET}"
say "  packages (lockstep): ${DIM}$(printf '%s ' "${PKG_PUBSPECS[@]%/pubspec.yaml}" | sed 's#packages/##g')${RESET}"
hr
say ""
say "  How do you want to bump the version?"
say ""
say "    ${BOLD}1${RESET}) ${GREEN}patch${RESET}  (hotfix / bug fix)        ${CURRENT} → ${BOLD}${NEXT_PATCH}${RESET}"
say "    ${BOLD}2${RESET}) ${YELLOW}minor${RESET}  (new features)            ${CURRENT} → ${BOLD}${NEXT_MINOR}${RESET}"
say "    ${BOLD}3${RESET}) ${RED}major${RESET}  (breaking changes)        ${CURRENT} → ${BOLD}${NEXT_MAJOR}${RESET}"
say "    ${BOLD}4${RESET}) ${CYAN}custom${RESET} (type an exact version)"
say "    ${BOLD}q${RESET}) quit"
say ""

NEW=""
while [[ -z "$NEW" ]]; do
  read -r -p "  ${BOLD}choice${RESET} ${DIM}[1/2/3/4/q]${RESET} " choice
  case "$choice" in
    1) NEW="$NEXT_PATCH" ;;
    2) NEW="$NEXT_MINOR" ;;
    3) NEW="$NEXT_MAJOR" ;;
    4)
      read -r -p "  enter version ${DIM}(e.g. 1.2.3 or 1.0.0-rc1)${RESET}: " typed
      typed="${typed#v}"  # tolerate a leading 'v'
      if ! is_semver "$typed"; then
        say "  ${RED}'$typed' is not a valid semantic version (expected X.Y.Z).${RESET}"
        continue
      fi
      if [[ "$typed" == "$CURRENT" ]]; then
        say "  ${RED}that is the current version — nothing to bump.${RESET}"
        continue
      fi
      NEW="$typed"
      ;;
    q|Q) say "  aborted."; exit 0 ;;
    *) say "  ${RED}please choose 1, 2, 3, 4 or q.${RESET}" ;;
  esac
done

# ---- explain + confirm ------------------------------------------------------
say ""
hr
say "  ${CURRENT}  →  ${BOLD}${GREEN}${NEW}${RESET}"
say "  This is $(describe_jump "$CURRENT" "$NEW")"
hr

if is_lower "$NEW" "$CURRENT"; then
  say ""
  say "  ${BG_RED}${BOLD} WARNING: THIS IS A DOWNGRADE ${RESET}"
  say "  ${RED}${BOLD}GOING FROM ${CURRENT} DOWN TO ${NEW} SHOULD NOT HAPPEN NORMALLY.${RESET}"
  say "  ${RED}Published versions are immutable; a downgrade will break consumers.${RESET}"
  say ""
  confirm "  ${RED}${BOLD}Are you absolutely sure you want to DOWNGRADE?${RESET}" || { say "  aborted."; exit 0; }
  confirm "  ${RED}${BOLD}Confirm once more — really downgrade to ${NEW}?${RESET}" || { say "  aborted."; exit 0; }
fi

# Warn about changelogs whose Unreleased section is empty — releasing them means
# shipping a version with no notes. Root uses "## [Unreleased]", packages "## Unreleased".
empty_changelogs=()
unreleased_empty "CHANGELOG.md" "## [Unreleased]" && empty_changelogs+=("CHANGELOG.md")
for cl in packages/*/CHANGELOG.md; do
  unreleased_empty "$cl" "## Unreleased" && empty_changelogs+=("$cl")
done

if (( ${#empty_changelogs[@]} > 0 )); then
  say ""
  say "  ${RED}${BOLD}WARNING: the Unreleased section is EMPTY in:${RESET}"
  for cl in "${empty_changelogs[@]}"; do
    say "    ${RED}• ${cl}${RESET}"
  done
  say "  ${RED}These will be released as ${NEW} with no changelog notes.${RESET}"
  say ""
  confirm "  ${RED}${BOLD}Continue anyway?${RESET}" || { say "  aborted — add your notes under Unreleased, then re-run."; exit 0; }
fi

say ""
confirm "  Apply version ${BOLD}${NEW}${RESET} across the workspace?" || { say "  aborted."; exit 0; }

# ---- apply ------------------------------------------------------------------
DATE="$(date +%F)"
say ""
hr

# sed -i.bak works on both GNU and BSD/macOS sed.
sed_inplace() { sed -i.bak "$@" && rm -f "${@: -1}.bak"; }

# 1) version: line in every package pubspec
for ps in "${PKG_PUBSPECS[@]}"; do
  sed_inplace -E "s/^version:[[:space:]]*${CURRENT}$/version: ${NEW}/" "$ps"
  say "  ${GREEN}✓${RESET} version → ${NEW}  ${DIM}${ps}${RESET}"
done

# 2) ^CURRENT constraints (interdependencies + README). CURRENT is specific
#    enough that a literal ^CURRENT match never touches unrelated constraints.
ESC_CUR="${CURRENT//./\\.}"
for f in "${PKG_PUBSPECS[@]}" README.md; do
  [[ -f "$f" ]] || continue
  if grep -q "\^${ESC_CUR}" "$f"; then
    sed_inplace "s/\^${ESC_CUR}/^${NEW}/g" "$f"
    say "  ${GREEN}✓${RESET} ^${CURRENT} → ^${NEW}  ${DIM}${f}${RESET}"
  fi
done

# 3) regenerate version.g.dart
( cd packages/didwebvh_wizard && dart run tool/generate_version.dart >/dev/null )
say "  ${GREEN}✓${RESET} regenerated  ${DIM}packages/didwebvh_wizard/lib/src/version.g.dart${RESET}"

# 4) CHANGELOGs — promote the Unreleased section to the new version (keeping its
#    accumulated notes) and leave a fresh, empty Unreleased section on top. Two
#    styles by design (see docs/AGENTS.md): the root CHANGELOG uses Keep a
#    Changelog ("## [Unreleased]" / "## [X.Y.Z] - DATE"); the per-package
#    CHANGELOGs use the plain Dart-idiomatic style ("## Unreleased" / "## X.Y.Z
#    - DATE"). The Unreleased header is matched exactly (no regex) and the new
#    version header is inserted right after it, so the notes that were under
#    Unreleased end up under the released version.
promote_changelog() { # $1 file, $2 style: "root" | "pkg"
  local file="$1" style="$2" header new_line tmp
  [[ -f "$file" ]] || return 0
  if [[ "$style" == "root" ]]; then
    header="## [Unreleased]"
    new_line="## [${NEW}] - ${DATE}"
  else
    header="## Unreleased"
    new_line="## ${NEW} - ${DATE}"
  fi
  tmp="$(mktemp)"
  awk -v hdr="$header" -v line="$new_line" '
    !done && $0 == hdr { print; print ""; print line; done=1; next }
    { print }
    END { if (!done) exit 3 }
  ' "$file" >"$tmp" || {
    rm -f "$tmp"
    say "  ${YELLOW}!${RESET} no \"${header}\" section in ${DIM}${file}${RESET} — skipped"
    return 0
  }
  mv "$tmp" "$file"
  say "  ${GREEN}✓${RESET} changelog → ${NEW} (${DATE})  ${DIM}${file}${RESET}"
}

promote_changelog "CHANGELOG.md" root
for cl in packages/*/CHANGELOG.md; do
  promote_changelog "$cl" pkg
done

# ---- done -------------------------------------------------------------------
say ""
hr
say "  ${BOLD}${GREEN}Bumped ${CURRENT} → ${NEW}.${RESET}"
say ""
say "  ${BOLD}Next steps:${RESET}"
say "    ${DIM}# review the changes, including the promoted CHANGELOG sections${RESET}"
say "    git diff"
say "    ${DIM}# run the gate${RESET}"
say "    tool/verify.sh"
say "    ${DIM}# commit and tag to trigger pub.dev publishing${RESET}"
say "    git commit -am \"chore(release): cut v${NEW}\""
say "    git tag v${NEW}"
say "    git push origin v${NEW}"
say ""
