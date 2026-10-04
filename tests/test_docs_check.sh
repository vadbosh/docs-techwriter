#!/usr/bin/env bash
# Tests for skills/docs-techwriter/scripts/docs_check.py — the hook that checks
# documentation right after an edit. One case per line; a throwaway directory.
set -uo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
C="$SRC/skills/docs-techwriter/scripts/docs_check.py"
T="$(mktemp -d)"
pass=0 fail=0

ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/    /'; }

run() { python3 "$C" "$@" 2>&1; }   # stdin: the payload

has() {  # name, expected text, payload, [args]
    local out; out="$(printf '%s' "$3" | run "${@:4}")"
    case "$out" in *"$2"*) ok ;; *) bad "$1" "$out" ;; esac
}
silent() {  # name, payload
    local out; out="$(printf '%s' "$2" | run)"
    [ -z "$out" ] && ok || bad "$1" "$out"
}

edit() { python3 -c 'import json,sys; print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":sys.argv[1],"old_string":"x","new_string":sys.argv[2]},"cwd":sys.argv[3]}))' "$1" "$2" "$T"; }

# Claude Code, Edit: a pointer to a place in a Russian README
printf 'Начало.\n\nКак сказано выше, установщик ставит всё сам.\n' > "$T/README.RU.md"
has "edit: check 16 in Russian" "check 16" "$(edit "$T/README.RU.md" 'Как сказано выше, установщик ставит всё сам.')"
has "edit: JSON for Claude Code" '"hookEventName": "PostToolUse"' "$(edit "$T/README.RU.md" 'Как сказано выше, установщик ставит всё сам.')"

# a dangling «так»
printf 'Windows не проверялась даже так.\n' > "$T/README.RU.md"
has "edit: check 18" "check 18" "$(edit "$T/README.RU.md" 'Windows не проверялась даже так.')"

# a defect that was already in the file and is not in the edit stays out
printf 'Как сказано выше, старое.\n\nНовая фраза без дефектов.\n' > "$T/README.RU.md"
out="$(edit "$T/README.RU.md" 'Новая фраза без дефектов.' | run)"
case "$out" in *"check 16"*) bad "edit: old defect reported" "$out" ;; *"found nothing"*) ok ;; *) bad "edit: clean edit" "$out" ;; esac

# Claude Code, Write of a clean English README: the reminder only
printf '# tool\n\nRun the installer. It copies the skill.\n' > "$T/README.md"
has "write: clean file gets the reading reminder" "found nothing" \
    "$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":"x"}}))' "$T/README.md")"

# Codex, apply_patch: the path is relative to cwd, the + lines are the edit
printf '# tool\n\nAs said above, it installs everything.\n' > "$T/README.md"
P=$'*** Begin Patch\n*** Update File: README.md\n@@\n+As said above, it installs everything.\n*** End Patch'
has "codex apply_patch: check 16 in English" "check 16" \
    "$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"apply_patch","tool_input":{"command":sys.argv[1]},"cwd":sys.argv[2]}))' "$P" "$T")"

# Opencode: plain text, not JSON
printf 'Windows не проверялась даже так.\n' > "$T/README.RU.md"
out="$(edit "$T/README.RU.md" 'Windows не проверялась даже так.' | run --text)"
case "$out" in "[docs-check]"*"check 18"*) ok ;; *) bad "--text: plain output" "$out" ;; esac

# not documentation: silent
printf 'print("как сказано выше")\n' > "$T/tool.py"
silent "a .py file is not documentation" "$(edit "$T/tool.py" 'print("как сказано выше")')"
printf 'Как сказано выше.\n' > "$T/review-2026-10-04-x.md"
silent "review-*.md is a work order, not documentation" "$(edit "$T/review-2026-10-04-x.md" 'Как сказано выше.')"
printf '# notes\n\nplain english text, as said above\n' > "$T/notes.md"
silent "an English .md that is not README/docs" "$(edit "$T/notes.md" 'plain english text, as said above')"

# a version in a changelog is what a changelog is for
printf '## 1.2.0\n\n- fixed in 1.1.9 the parser\n' > "$T/CHANGELOG.md"
out="$(edit "$T/CHANGELOG.md" '- fixed in 1.1.9 the parser' | run)"
case "$out" in *"check 17"*) bad "changelog: check 17 must stay out" "$out" ;; *) ok ;; esac

# an English SKILL.md quoting Russian is text for a model, not documentation
printf -- '---\nname: x\ndescription: long words here and there, as said above\n---\n\nUse when asked to "переведи доку".\n' > "$T/SKILL.md"
silent "an English SKILL.md with a Russian quote" "$(edit "$T/SKILL.md" 'Use when asked to "переведи доку".')"

# YAML front matter is not prose
printf -- '---\nname: x\ndescription: Как сказано выше, это поле.\n---\n\nТекст README.\n' > "$T/README.RU.md"
out="$(edit "$T/README.RU.md" 'description: Как сказано выше, это поле.' | run)"
case "$out" in *"check 16"*) bad "front matter: must not be checked" "$out" ;; *) ok ;; esac

# garbage on stdin never breaks the edit
out="$(printf 'not json' | run)"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "garbage input: exit 0, no output" "rc=$rc $out"

echo "docs_check: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
