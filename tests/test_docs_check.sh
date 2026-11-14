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

# «молча» about a mechanism is a calque of "silently"; about a person it is Russian
printf 'Ссылка на прежний якорь ломается молча.\n' > "$T/README.RU.md"
has "edit: «ломается молча»" "calque of meaning" "$(edit "$T/README.RU.md" 'Ссылка на прежний якорь ломается молча.')"
printf 'Оператор молча кивнул и закрыл тикет.\n' > "$T/README.RU.md"
out="$(edit "$T/README.RU.md" 'Оператор молча кивнул и закрыл тикет.' | run)"
case "$out" in *"calque of meaning"*) bad "edit: «молча кивнул» flagged" "$out" ;; *) ok ;; esac

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

# ASD-STE100, 80% of the way: English only, hints only
S27='The installer copies the skill into each assistant directory it finds on this machine and then adds the trigger rule and the hook that runs after every edit.'
printf '# tool\n\n%s\n' "$S27" > "$T/README.md"
has "STE100: an English sentence over 25 words" "sentence of 28 words" "$(edit "$T/README.md" "$S27")"

R27='Установщик копирует скилл в каталог каждого ассистента, который он находит на этой машине, а затем добавляет правило-триггер и хук, который запускается после каждой правки документации в любом ассистенте.'
printf '# tool\n\n%s\n' "$R27" > "$T/README.RU.md"
out="$(edit "$T/README.RU.md" "$R27" | run)"
case "$out" in *"sentence of"*) bad "STE100: Russian keeps its own limit of 30" "$out" ;; *) ok ;; esac

STEP='1. Open the configuration file in the editor of your choice and set the value of the timeout field to the number of seconds you need.'
printf '# tool\n\n%s\n' "$STEP" > "$T/README.md"
has "STE100: a procedure step over 20 words" "procedure step of 25 words" "$(edit "$T/README.md" "$STEP")"

printf '# tool\n\n1. Open the file. The value is set to 30.\n' > "$T/README.md"
has "STE100: passive in a procedure step" "STE100, passive" "$(edit "$T/README.md" '1. Open the file. The value is set to 30.')"

# a numbered list that describes rather than instructs is not a procedure
DESC='1. Writes the Russian from the meaning of the English, not from its word order, and keeps every command, path and error string as it is written.'
printf '# tool\n\n%s\n' "$DESC" > "$T/README.md"
out="$(edit "$T/README.md" "$DESC" | run)"
case "$out" in *"procedure step"*) bad "STE100: a descriptive numbered item is not a step" "$out" ;; *) ok ;; esac
DESC='2. Otherwise the model Codex is configured with is used, which is set in its own config file.'
printf '# tool\n\n%s\n' "$DESC" > "$T/README.md"
out="$(edit "$T/README.md" "$DESC" | run)"
case "$out" in *"STE100, passive"*) bad "STE100: passive in a descriptive numbered item" "$out" ;; *) ok ;; esac

printf '# tool\n\n1. While the installer is running, open a new terminal.\n' > "$T/README.md"
has "STE100: progressive in a procedure step" "STE100, progressive" "$(edit "$T/README.md" '1. While the installer is running, open a new terminal.')"

printf '# tool\n\nThe file is copied to the skills directory.\n' > "$T/README.md"
out="$(edit "$T/README.md" 'The file is copied to the skills directory.' | run)"
case "$out" in *"STE100, passive"*) bad "STE100: passive in descriptive text is allowed" "$out" ;; *) ok ;; esac

printf '# tool\n\nUtilize the flag prior to the first run.\n' > "$T/README.md"
has "STE100 dictionary: utilize -> use" "utilize → use" "$(edit "$T/README.md" 'Utilize the flag prior to the first run.')"
has "STE100 dictionary: prior to -> before" "prior to → before" "$(edit "$T/README.md" 'Utilize the flag prior to the first run.')"

printf '# tool\n\nRun `in_order_to --approximately` first.\n' > "$T/README.md"
out="$(edit "$T/README.md" 'Run `in_order_to --approximately` first.' | run)"
case "$out" in *"STE100 dictionary"*) bad "STE100 dictionary: inline code is not prose" "$out" ;; *) ok ;; esac

# a full stop inside closing markup still ends the sentence: two of 13 and 15
# words, not one of 28
s='For Russian, the one principle: **a good Russian version is not a translation.** It is the same content stated the way a Russian technical writer would state it.'
printf '# t\n\n%s\n' "$s" > "$T/README.md"
out="$(edit "$T/README.md" "$s" | run)"
case "$out" in *"sentence of"*) bad "sentence ends inside **…**" "$out" ;; *) ok ;; esac

# garbage on stdin never breaks the edit
out="$(printf 'not json' | run)"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "garbage input: exit 0, no output" "rc=$rc $out"

# By hand: file paths, no JSON.
byhand() {  # name, expected exit, expected text, files...
    local name="$1" want="$2" text="$3" out rc; shift 3
    out="$(timeout 5 python3 "$C" "$@" 2>&1 </dev/null)"; rc=$?
    if [ "$rc" -eq "$want" ] && [[ "$out" == *"$text"* ]]; then ok; else bad "$name" "rc=$rc $out"; fi
}
printf 'Начало.\n\nКак сказано выше, установщик ставит всё сам.\n' > "$T/hand.RU.md"
printf 'Обычный абзац без ошибок.\n' > "$T/clean.RU.md"
printf 'x = 1\n' > "$T/code.py"
byhand "by hand: a defect found, exit 1" 1 "check 16" "$T/hand.RU.md"
byhand "by hand: the whole file is checked" 1 "lines 1–4 checked" "$T/hand.RU.md"
byhand "by hand: a clean file, exit 0" 0 "found nothing" "$T/clean.RU.md"
byhand "by hand: not documentation is said, not silent" 0 "not checked" "$T/code.py"
byhand "by hand: a missing file, exit 2" 2 "cannot read" "$T/missing.md"
# an English page under docs/, given by a relative path from the project: it is
# documentation, not "not checked" (the /docs/ test once needed a leading slash)
mkdir -p "$T/proj/docs"; printf 'As mentioned above, it installs everything.\n' > "$T/proj/docs/guide.md"
out="$(cd "$T/proj" && timeout 5 python3 "$C" docs/guide.md 2>&1 </dev/null)"; rc=$?
if [ "$rc" -eq 1 ] && [[ "$out" == *"check 16"* ]]; then ok; else bad "by hand: docs/x.md by a relative path is checked" "rc=$rc $out"; fi
# stdin left open, as in an assistant's shell: reading it for JSON used to wait forever
out="$(sleep 3 | timeout 2 python3 "$C" "$T/hand.RU.md" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ]; then ok; else bad "by hand, stdin open: no wait" "rc=$rc $out"; fi
if command -v script >/dev/null 2>&1; then
    out="$(script -qec "timeout 5 python3 '$C'" /dev/null 2>&1)"; rc=$?
    if [ "$rc" -eq 2 ] && [[ "$out" == *usage* ]]; then ok; else bad "no file, a terminal on stdin: usage, exit 2" "rc=$rc $out"; fi
fi

echo "docs_check: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
