#!/usr/bin/env bash
# Release checks for the docs-techwriter skill.
#
#   ./release.sh check     version ↔ changelog ↔ tag ↔ HEAD ↔ installed copies
#                          of the skill and of the trigger rule
#   ./release.sh tag       create the tag for the current version
#
# The three sources of "which version is this" drift independently — the field
# that ships, the section a reader looks at, and the tag `git checkout` needs —
# and a release where they disagree is worse than an untagged one: each looks
# authoritative and nothing says which is right.
set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$SRC/skills/docs-techwriter/SKILL.md"
LOG="$SRC/CHANGELOG.md"
COPIES=0

# Paths that belong to this machine — a mirror this repository does not own.
# Untracked on purpose: a clone has its own answer or none.
# shellcheck disable=SC1091
[ -f "$SRC/.release.local" ] && . "$SRC/.release.local"

# Not ${d/#$HOME/\~}: bash 3.2 (macOS) keeps the backslash.
tilde() { case "$1" in "$HOME"*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }

version() { grep -m1 '^version:' "$SKILL" | sed 's/version: *"//; s/"//'; }

installed_dirs() {
    local d
    for d in "$HOME/.claude/skills/docs-techwriter" \
             "$HOME/.config/opencode/skills/docs-techwriter" \
             "$HOME/.codex/skills/docs-techwriter" \
             ${RU_TECH_DOCS_MIRRORS:-}; do
        [ -f "$d/SKILL.md" ] && printf '%s\n' "$d"
    done
}

# Ask the source what it ships instead of listing files here. A reference page
# added to the skill and forgotten in a hand-written list would let a copy
# differ in that file and still be called a match.
shipped() {
    (cd "$SRC/skills/docs-techwriter" && find . -type f ! -name '*.bak.*' \
        | sed 's|^\./||' | sort)
}

copies() {
    local v="$1" d behind=0 n=0 iv same f
    while read -r d; do
        [ -n "$d" ] || continue
        n=$((n + 1))
        iv="$(grep -m1 '^version:' "$d/SKILL.md" | sed 's/version: *"//; s/"//')"
        same=1
        while read -r f; do
            cmp -s "$SRC/skills/docs-techwriter/$f" "$d/$f" || same=0
        done < <(shipped)
        [ "$iv" = "$v" ] && [ "$same" -eq 1 ] && continue
        [ "$behind" -eq 0 ] && echo "  installed copies behind the source:"
        behind=$((behind + 1))
        echo "    $(tilde "$d")  version $iv$([ "$same" -eq 0 ] && echo ", content differs")"
    done < <(installed_dirs)

    if [ "$behind" -gt 0 ]; then
        echo "                    ./install.sh refreshes the assistant directories;"
        echo "                    a mirror is refreshed by whatever owns it"
        return 1
    fi
    # "0, all at 1.0.0" reads as a check that passed while nothing was checked.
    if [ "$n" -eq 0 ]; then
        echo "  installed copies:  none on this machine — nothing to compare"
        return 0
    fi
    COPIES=$n
    echo "  installed copies:  $n, all at $v"
}

# The rule ships with the skill and drifts on its own: an edit in one
# assistant's copy changes when the skill fires there and nowhere else.
rule_copies() {
    local r="$SRC/rules/docs-techwriter-trigger.md" d n=0 bad=0
    for d in "$HOME/.claude/rules" "$HOME/.config/opencode/instructions" "$HOME/.codex/memories"; do
        [ -f "$d/docs-techwriter-trigger.md" ] || continue
        n=$((n + 1))
        cmp -s "$r" "$d/docs-techwriter-trigger.md" && continue
        [ "$bad" -eq 0 ] && echo "  rule copies differing from rules/:"
        bad=1
        echo "    $(tilde "$d")/docs-techwriter-trigger.md"
    done
    if [ "$bad" -eq 1 ]; then
        echo "                    ./install.sh refreshes them"
        return 1
    fi
    echo "  rule copies:       $n, all match rules/"
}

# A machine path inside a shipped file reaches every clone. Three landed in
# published skills on this machine before anything looked for them.
# `/home/user` is the placeholder checks.md tells writers to use instead, so
# it is the one home directory that is not a leak. A path continues with a
# name: "/root/…" in prose describing a pattern is not one.
shipped_leaks() {
    local hits
    hits="$(grep -n -P "\Q$HOME\E/[A-Za-z0-9._-]|/home/(?!user\b)[a-z]|/Users/(?!user\b)[a-z]" $(shipped_paths) 2>/dev/null || true)"
    if [ -n "$hits" ]; then
        echo "  shipped files:    a path of this machine is named in them:"
        echo "$hits" | sed 's/^/    /'
        return 1
    fi
    echo "  shipped files:    nothing local named in them"
}

shipped_paths() { while read -r f; do printf '%s ' "$SRC/skills/docs-techwriter/$f"; done < <(shipped); }

check() {
    local v problems=0
    v="$(version)"
    [ -n "$v" ] || { echo "no version: field in $SKILL" >&2; return 3; }
    echo "  SKILL.md version: $v"

    if grep -q "^## $v\( \|$\)" "$LOG"; then
        echo "  CHANGELOG.md:     has a section for $v"
    else
        echo "  CHANGELOG.md:     NO section for $v — add one before tagging"
        problems=1
    fi

    if git -C "$SRC" rev-parse -q --verify "refs/tags/v$v" >/dev/null; then
        echo "  tag v$v:          exists"
        # `^{commit}` and not the bare name: an annotated tag is an object of
        # its own, so comparing the two raw ids said HEAD had moved past a tag
        # created one second earlier.
        if [ "$(git -C "$SRC" rev-parse "v$v^{commit}")" = "$(git -C "$SRC" rev-parse HEAD)" ]; then
            echo "  HEAD:             at v$v"
        else
            echo "  HEAD:             moved past v$v — release again or reset"
            problems=1
        fi
    else
        echo "  tag v$v:          missing — ./release.sh tag creates it"
        problems=1
    fi

    # Both directions. A tag with no section describes a release nobody
    # records; a section with no tag describes one that never happened.
    local orphan
    orphan="$(git -C "$SRC" tag | while read -r tg; do
        grep -q "^## ${tg#v}\( \|$\)" "$LOG" || echo "$tg"
    done)"
    if [ -n "$orphan" ]; then
        echo "  tags with no changelog section:"
        echo "$orphan" | sed 's/^/    /'
        problems=1
    fi
    local untagged
    untagged="$(grep -o '^## [0-9][0-9.]*' "$LOG" | sed 's/^## //' | while read -r s; do
        git -C "$SRC" rev-parse -q --verify "refs/tags/v$s" >/dev/null || echo "$s"
    done)"
    if [ -n "$untagged" ]; then
        echo "  changelog sections with no tag:"
        echo "$untagged" | sed 's/^/    /'
        problems=1
    else
        echo "  changelog sections:  every one has its tag"
    fi

    shipped_leaks || problems=1
    copies "$v" || problems=1
    rule_copies || problems=1

    if [ "$problems" -eq 0 ]; then
        echo "  agreed and released$([ "$COPIES" -gt 0 ] && echo ", and all $COPIES copies here match")"
        return 0
    fi
    return 3
}

tag() {
    local v
    v="$(version)"
    if git -C "$SRC" rev-parse -q --verify "refs/tags/v$v" >/dev/null; then
        echo "  tag v$v already exists — a tag is never moved; release a new version" >&2
        return 1
    fi
    grep -q "^## $v\( \|$\)" "$LOG" || {
        echo "  CHANGELOG.md has no section for $v — write it first" >&2
        return 1
    }
    # The tag carries the changelog section, so `git tag -n99` answers
    # "what changed" without leaving git.
    local body
    body="$(awk -v v="## $v" '$0 == v {f=1; next} f && /^## / {exit} f' "$LOG")"
    git -C "$SRC" tag -a "v$v" -m "$v"$'\n\n'"$body"
    echo "  tagged v$v at $(git -C "$SRC" rev-parse --short HEAD)"
    echo "  push it: git push --tags origin"
}

case "${1:-check}" in
    check) check ;;
    tag)   tag ;;
    *)     echo "usage: $0 {check|tag}" >&2; exit 2 ;;
esac
