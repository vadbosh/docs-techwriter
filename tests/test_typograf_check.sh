#!/usr/bin/env bash
# Tests for skills/docs-techwriter/scripts/typograf_check.py.
# Needs typograf (./install.sh --with-typograf); without it, says SKIP and exits 0.
set -uo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
W="$SRC/skills/docs-techwriter/scripts/typograf_check.py"
T="$(mktemp -d)"
pass=0 fail=0

if ! command -v typograf >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/typograf" ]; then
    echo "SKIP — typograf not installed"; exit 0
fi

expect() {   # name, expected exit, args...
    local name="$1" want="$2"; shift 2
    (cd "$T" && python3 "$W" "$@" >"$T/out" 2>&1); local got=$?
    if [ "$got" = "$want" ]; then pass=$((pass + 1)); else
        fail=$((fail + 1)); echo "FAIL $name: exit $got, want $want"; sed 's/^/    /' "$T/out"; fi
}

# The defects the check exists for: straight quotes, hyphen as dash, double space.
printf 'Запусти "скрипт" - он  проверит файлы.\n' > "$T/bad.md"
expect "defects found" 1 bad.md

# What must stay untouched: code, inline code, links, emphasis, lists, ISO dates,
# tables, front matter, "так что то, что" (ru/dash/to guesses wrong there).
cat > "$T/clean.md" <<'MD'
---
title: "x" - y
---

# Установка

Это **важно?** Дата выпуска 2026-10-04, так что то, что не влезло, не теряется.

- первый пункт
1. второй пункт

| ключ   | значение |
|--------|----------|
| `a`    | b        |

См. [руководство](guide.md "Заголовок") и `rg -n "foo" -- x`.

```bash
echo "hello" -- x
```

    echo "indented" -- y
MD
expect "clean document" 0 clean.md
expect "unexpanded glob is an empty list" 1 bad.md 'docs/*.ru.md'
expect "missing file" 2 missing.md
TYPOGRAF=/nonexistent expect "typograf cannot run" 2 bad.md

# English mode: a hyphen for a dash and a doubled space are found; straight
# quotes are not a finding in English Markdown, and an unknown language is refused.
printf 'Run the script - it checks files.  Then wait.\n' > "$T/en-bad.md"
printf 'Say "draw the architecture" and run `rg -n "x" -- y`.\n' > "$T/en-clean.md"
expect "english defects found" 1 --lang en en-bad.md
expect "english quotes left alone" 0 --lang en en-clean.md
expect "unknown language refused" 2 --lang xx en-bad.md

# The line numbers must survive masking: the finding is on line 3.
printf '```\ncode\n```\nЗапусти "x" - сейчас.\n' > "$T/lines.md"
out="$(cd "$T" && python3 "$W" lines.md 2>&1)"; [ "${out%%$'\n'*}" = "lines.md:4" ] \
    && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL line number: want lines.md:4"; }

# GitHub alert markers: "[!IMPORTANT]" must never become "[! IMPORTANT]", in both
# languages, while a real defect on the next line is still found.
for kind in NOTE TIP IMPORTANT WARNING CAUTION; do
    printf '> [!%s]\n> **Установите `x`.** текст\n' "$kind" > "$T/alert-$kind.md"
    expect "alert $kind ru" 0 "alert-$kind.md"
    printf '> [!%s]\n> **Install `x`.** text\n' "$kind" > "$T/alert-en-$kind.md"
    expect "alert $kind en" 0 --lang en "alert-en-$kind.md"
done
printf '> [!NOTE]\n> Запусти "x" - сейчас.\n' > "$T/alert-bad.md"
expect "alert block still checked" 1 alert-bad.md

# An "x" between digits is a hash, a resolution or a version far more often
# than a multiplication, and an identifier does not have to sit in backticks to
# be one. Real case: on an advisory page the check offered
# GHSA-2fmv-rv2c-59x7 -> GHSA-2fmv-rv2c-59×7, which breaks the link. The
# identifier was in a plain <td>, where typograf's own protection for <pre> and
# <code> does not reach, so the rule itself has to be off.
printf '<td>GHSA-2fmv-rv2c-59x7</td>\n<td>1920x1080</td>\n' > "$T/ident.html"
expect "digits around x are not a multiplication" 0 ident.html
expect "digits around x are not a multiplication, en" 0 --lang en ident.html

# Prose in an unprotected element is still checked.
printf '<td>Запусти "скрипт" - сейчас.</td>\n' > "$T/td-bad.html"
expect "prose in a td still checked" 1 td-bad.html

echo "typograf_check: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
