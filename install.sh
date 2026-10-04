#!/usr/bin/env bash
# Install the ru-tech-docs skill and its trigger rule — Linux / macOS.
#
# The skill is Markdown files and nothing else: no binary, no PATH entry, no
# runtime. Installing it is a copy into each assistant's skills directory, plus
# the trigger rule (rules/ru-tech-docs-trigger.md) wired into each assistant.
#
#   ./install.sh                 install into every assistant found
#   ./install.sh --dry-run       print what would happen, change nothing
#   ./install.sh --no-rule       the skill only, without the trigger rule
#   ./install.sh --skills-dir D  install the skill into D, no rule
#
# Idempotent: re-running replaces only what changed. A file it overwrites is
# copied to <file>.bak.<timestamp> ONLY when that content is not already in the
# source repository — a hand edit is the one thing git cannot give back.
# Nothing outside $HOME is touched.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
NO_RULE=0
SKILLS_DIR=""
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)    DRY_RUN=1 ;;
        --no-rule)    NO_RULE=1 ;;
        --skills-dir) SKILLS_DIR="${2:-}"; shift ;;
        -h|--help)    sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

# Colour only when stdout is a terminal — piping into a log must stay clean.
if [ -t 1 ]; then
    C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_OFF=$'\033[0m'
else
    C_OK=''; C_WARN=''; C_OFF=''
fi

say()  { printf '%s\n' "$*"; }
ok()   { printf '%s%s%s\n' "$C_OK"   "$*" "$C_OFF"; }
warn() { printf '%s%s%s\n' "$C_WARN" "$*" "$C_OFF"; }
tilde() { printf '%s' "${1/#$HOME/\~}"; }

# Is this exact content already in the source repository's object database?
# Then it is one `git checkout` away and a backup of it is worth nothing.
in_git_history() {
    local sha
    command -v git >/dev/null 2>&1 || return 1
    git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1 || return 1
    sha="$(git -C "$SRC" hash-object "$1" 2>/dev/null)" || return 1
    [ -n "$sha" ] && git -C "$SRC" cat-file -e "$sha" 2>/dev/null
}

install_file() {
    local src="$1" dst="$2"
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        say "    = $(tilde "$dst")"
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        say "    would write $(tilde "$dst")"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    if [ -f "$dst" ]; then
        if in_git_history "$dst"; then
            say "    ~ $(tilde "$dst")"
        else
            cp -p "$dst" "$dst.bak.$STAMP"
            say "    ~ $(tilde "$dst")  (backup .bak.$STAMP — edited by hand, not in git)"
        fi
    else
        say "    + $(tilde "$dst")"
    fi
    cp "$src" "$dst"
    chmod 644 "$dst"
}

# Only assistants already present are written to — creating a config tree for
# one the person does not have would just litter their home.
detect_skill_dirs() {
    if [ -n "$SKILLS_DIR" ]; then
        printf '%s\n' "$SKILLS_DIR"
        return
    fi
    local d
    for d in "$HOME/.claude/skills" \
             "$HOME/.config/opencode/skills" \
             "$HOME/.codex/skills"; do
        [ -d "$(dirname "$d")" ] && printf '%s\n' "$d"
    done
}

say "── ru-tech-docs ──"
[ "$DRY_RUN" -eq 1 ] && warn "  dry run — nothing will be written"

found=0
while read -r dir; do
    [ -n "$dir" ] || continue
    found=$((found + 1))
    say "  $(tilde "$dir")"
    # Ask the source what it ships rather than listing files here: a fourth
    # reference page added to the skill and forgotten in this list would be
    # missing from every install with nothing to say so.
    while read -r f; do
        install_file "$SRC/skills/ru-tech-docs/$f" "$dir/ru-tech-docs/$f"
    done < <(cd "$SRC/skills/ru-tech-docs" && find . -type f ! -name '*.bak.*' \
             | sed 's|^\./||' | sort)
done < <(detect_skill_dirs)

if [ "$found" -eq 0 ]; then
    warn "  no assistant directory found — nothing installed."
    warn "  Expected one of ~/.claude, ~/.config/opencode, ~/.codex."
    warn "  Point at one yourself: ./install.sh --skills-dir <path>"
    exit 1
fi

say "── verify ──"
rc=0
while read -r dir; do
    [ -n "$dir" ] || continue
    if [ "$DRY_RUN" -eq 1 ]; then
        say "  would verify $(tilde "$dir/ru-tech-docs")"
        continue
    fi
    if grep -q '^name: ru-tech-docs$' "$dir/ru-tech-docs/SKILL.md" 2>/dev/null; then
        ok "  ok — $(tilde "$dir/ru-tech-docs")"
    else
        warn "  FAILED — $(tilde "$dir/ru-tech-docs/SKILL.md") is not the ru-tech-docs skill"
        rc=1
    fi
done < <(detect_skill_dirs)

# The rule is what makes the skill fire: writing Russian next to English reads
# as ordinary work and never matches the skill's description on its own.
# Not with --skills-dir: a custom directory says nothing about which assistant
# reads it, so there is no configuration to wire.
if [ -z "$SKILLS_DIR" ] && [ "$NO_RULE" -eq 0 ]; then
    say "── trigger rule ──"
    if ! command -v python3 >/dev/null 2>&1; then
        warn "  python3 not found — rule not installed; the skill fires only when asked by name"
        rc=1
    else
        for ide in claude opencode codex; do
            args=("$ide" --src "$SRC")
            [ "$DRY_RUN" -eq 1 ] && args+=(--dry-run)
            set +e
            python3 "$SRC/lib/wire.py" "${args[@]}"
            wrc=$?
            set -e
            case "$wrc" in
                0) ok "  ok — $ide" ;;
                3) ;;  # assistant not installed
                *) warn "  FAILED — $ide, see the message above"; rc=1 ;;
            esac
        done
    fi
fi

say ""
say "  In your assistant: write or edit Russian docs as usual — the rule loads"
say "  the skill. By name: '/ru-tech-docs' or 'сделай RU версию README'."
exit $rc
