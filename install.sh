#!/usr/bin/env bash
# Install the docs-techwriter skill and its trigger rule — Linux / macOS.
#
# The skill is Markdown files and nothing else: no binary, no PATH entry, no
# runtime. Installing it is a copy into each assistant's skills directory, plus
# the trigger rule (rules/docs-techwriter-trigger.md) wired into each assistant.
#
#   ./install.sh                 install into every assistant found
#   ./install.sh --dry-run       print what would happen, change nothing
#   ./install.sh --no-rule       the skill only, without the trigger rule
#   ./install.sh --skills-dir D  install the skill into D, no rule
#   ./install.sh --with-typograf install typograf-cli without asking
#   ./install.sh --no-typograf   never offer it
#
# typograf-cli is the one external program the skill uses (check 15, quotes,
# dashes, spaces). It is optional: asked about on a terminal, skipped otherwise.
# It goes into ~/.local (npm --prefix, no sudo) and needs Node.js 18.19+ or 20.6+;
# without Node the installer prints the package-manager command and offers to
# run it — apt (Debian, Ubuntu), dnf/yum (RHEL, Fedora, CentOS), brew (macOS).
# Windows is not supported.
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
TYPOGRAF=ask
SKILLS_DIR=""
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)    DRY_RUN=1 ;;
        --no-rule)    NO_RULE=1 ;;
        --with-typograf) TYPOGRAF=yes ;;
        --no-typograf)   TYPOGRAF=no ;;
        --skills-dir) SKILLS_DIR="${2:-}"; shift ;;
        -h|--help)    sed -n '2,27p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
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
# Not ${1/#$HOME/\~}: bash 3.2, the one macOS ships, keeps the backslash and
# prints \~/.claude — measured in the bash:3.2 image.
tilde() { case "$1" in "$HOME"*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }

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

say "── docs-techwriter ──"
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
        install_file "$SRC/skills/docs-techwriter/$f" "$dir/docs-techwriter/$f"
    done < <(cd "$SRC/skills/docs-techwriter" && find . -type f ! -name '*.bak.*' \
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
        say "  would verify $(tilde "$dir/docs-techwriter")"
        continue
    fi
    if grep -q '^name: docs-techwriter$' "$dir/docs-techwriter/SKILL.md" 2>/dev/null; then
        ok "  ok — $(tilde "$dir/docs-techwriter")"
    else
        warn "  FAILED — $(tilde "$dir/docs-techwriter/SKILL.md") is not the docs-techwriter skill"
        rc=1
    fi
done < <(detect_skill_dirs)

# Before 2.0.0 the skill was called ru-tech-docs. A copy under the old name
# keeps its own trigger rule, which sends the assistant to a skill that no
# longer updates. Named here, never removed: deleting is the person's call.
old=""
for d in "$HOME/.claude/skills/ru-tech-docs" "$HOME/.config/opencode/skills/ru-tech-docs" \
         "$HOME/.codex/skills/ru-tech-docs" "$HOME/.claude/rules/ru-tech-docs-trigger.md" \
         "$HOME/.config/opencode/instructions/ru-tech-docs-trigger.md" \
         "$HOME/.codex/memories/ru-tech-docs-trigger.md"; do
    [ -e "$d" ] && old="$old $d"
done
if [ -n "$old" ]; then
    say "── old name ──"
    warn "  copies of ru-tech-docs (the name before 2.0.0) are still installed:"
    for d in $old; do warn "    $(tilde "$d")"; done
    warn "  remove them, and their entries in opencode.json instructions[] and"
    warn "  ~/.codex/AGENTS.md — two trigger rules would point at two skills"
fi

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

# ── typograf-cli: optional, for check 15 ────────────────────────────────────
TYPOGRAF_VERSION="6.2.1"   # the version the wrapper's rule list was measured on
TY_PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/docs-techwriter/typograf"
TY_LINK="$HOME/.local/bin/typograf"

os_family() {
    case "$(uname -s)" in
        Darwin) echo macos ;;
        MINGW*|MSYS*|CYGWIN*) echo windows ;;
        Linux)
            local ids
            ids=" $( . /etc/os-release 2>/dev/null; echo "${ID:-} ${ID_LIKE:-}" ) "
            case "$ids" in
                *" debian "*|*" ubuntu "*) echo debian ;;
                *" rhel "*|*" fedora "*|*" centos "*) echo rhel ;;
                *) echo linux ;;
            esac ;;
        *) echo other ;;
    esac
}

node_install_cmd() {
    # root needs no sudo, and a container usually has none
    local sudo="sudo "
    [ "$(id -u)" -eq 0 ] && sudo=""
    case "$1" in
        # a fresh system or container has empty package lists: install alone
        # fails with "Unable to locate package nodejs" (measured, debian:stable-slim)
        debian) echo "${sudo}apt-get update && ${sudo}apt-get install -y nodejs npm" ;;
        # RHEL 8/9 and clones ship Node 16 by default — too old (see node_ok);
        # their module stream nodejs:20 is new enough. Fedora has no modules.
        rhel)   if command -v dnf >/dev/null 2>&1 && dnf -q module list nodejs 2>/dev/null | grep -q '^nodejs  *20 '; then
                    echo "${sudo}dnf module install -y nodejs:20/common"
                elif command -v dnf >/dev/null 2>&1; then echo "${sudo}dnf install -y nodejs npm"
                else echo "${sudo}yum install -y nodejs npm"; fi ;;
        macos)  command -v brew >/dev/null 2>&1 && echo "brew install node" ;;
    esac
}

# yes/no from the person; "no" when nobody is there to answer
confirm() {
    [ "$TYPOGRAF" = yes ] && return 0
    [ -t 0 ] || return 1
    local a
    printf '%s [y/N] ' "$1"
    read -r a || return 1
    case "$a" in y|Y|yes|д|да) return 0 ;; *) return 1 ;; esac
}

# typograf-cli 6.2.1 calls import.meta.resolve() synchronously. Measured in
# node:*-slim images: 18.19.0 and 20.6.0 run it, 18.18.2 and 20.5.1 fail with
# "import.meta.resolve is not a function"; Node 16 (RHEL 9's default) fails too.
# The package's own "engines" (>= 14) is wrong. 19.x was not measured — refused.
NODE_MIN="18.19 or 20.6+"
node_ok() {
    command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 || return 1
    local v major minor
    v="$(node --version 2>/dev/null)"; v="${v#v}"
    major="${v%%.*}"; minor="${v#*.}"; minor="${minor%%.*}"
    case "${major:-0}" in
        18) [ "${minor:-0}" -ge 19 ] ;;
        20) [ "${minor:-0}" -ge 6 ] ;;
        *)  [ "${major:-0}" -ge 21 ] ;;
    esac
}

typograf_step() {
    say "── typograf (optional: check 15 — quotes, dashes, spaces) ──"
    local fam cmd a
    if command -v typograf >/dev/null 2>&1; then
        ok "  ok — $(typograf --version 2>/dev/null) at $(tilde "$(command -v typograf)")"
        return 0
    fi
    fam="$(os_family)"
    if [ "$fam" = windows ]; then
        warn "  Windows is not supported — check 15 will be skipped"
        return 0
    fi
    if [ "$TYPOGRAF" = no ]; then
        say "  skipped (--no-typograf) — check 15 will be skipped"
        return 0
    fi
    if [ "$TYPOGRAF" = ask ] && [ ! -t 0 ]; then
        say "  not installed; skipped without a terminal to ask — ./install.sh --with-typograf"
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        say "  would offer typograf-cli@$TYPOGRAF_VERSION into $(tilde "$TY_PREFIX"), linked as $(tilde "$TY_LINK")"
        node_ok || say "  would first offer Node.js: ${cmd:-$(node_install_cmd "$fam")}"
        return 0
    fi
    confirm "  Install typograf-cli $TYPOGRAF_VERSION into $(tilde "$TY_PREFIX") (Node.js, no sudo)?" || {
        say "  skipped — check 15 will be skipped; ./install.sh --with-typograf later"
        return 0
    }
    if ! node_ok; then
        cmd="$(node_install_cmd "$fam")"
        if [ -z "$cmd" ]; then
            warn "  Node.js $NODE_MIN with npm is needed. Install it with your package manager"
            warn "  (macOS without Homebrew: https://nodejs.org), then re-run ./install.sh --with-typograf"
            return 1
        fi
        say "  Node.js $NODE_MIN with npm is needed:  $cmd"
        # A system package and sudo: only on a yes typed now, never from a flag.
        if [ ! -t 0 ]; then
            warn "  run it, then ./install.sh --with-typograf"
            return 1
        fi
        printf '  Run it now? [y/N] '
        read -r a || a=""
        case "$a" in y|Y|yes|д|да) ;; *) say "  skipped — run it, then ./install.sh --with-typograf"; return 0 ;; esac
        sh -c "$cmd" || { warn "  FAILED — $cmd"; return 1; }
        node_ok || {
            warn "  Node.js $(node --version 2>/dev/null || echo missing) from the package manager is too old ($NODE_MIN needed)."
            warn "  Newer builds: https://nodejs.org, NodeSource, or nvm; then ./install.sh --with-typograf"
            return 1; }
    fi
    npm install --prefix "$TY_PREFIX" --no-fund --no-audit --loglevel=error \
        "typograf-cli@$TYPOGRAF_VERSION" >/dev/null || { warn "  FAILED — npm install typograf-cli"; return 1; }
    mkdir -p "$(dirname "$TY_LINK")"
    ln -sfn "$TY_PREFIX/node_modules/.bin/typograf" "$TY_LINK"
    if "$TY_LINK" --version >/dev/null 2>&1; then
        ok "  ok — typograf $("$TY_LINK" --version) at $(tilde "$TY_LINK")"
    else
        warn "  FAILED — $(tilde "$TY_LINK") does not run"; return 1
    fi
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) warn "  ~/.local/bin is not on PATH — the check finds it there anyway; add it for the shell" ;;
    esac
}

if ! typograf_step && [ "$TYPOGRAF" = yes ]; then
    rc=1   # asked for explicitly and not delivered
fi

say ""
say "  In your assistant: write or edit Russian docs as usual — the rule loads"
say "  the skill. By name: '/docs-techwriter' or 'сделай RU версию README'."
exit $rc
