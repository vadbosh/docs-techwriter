#!/usr/bin/env python3
"""Typography check for Russian Markdown through typograf-cli.

    typograf_check.py [--nbsp] [--lang ru|en] FILE...

Prints every line typograf would change, as `file:line` with the line before
and after. Exit: 0 nothing to change, 1 lines to change, 2 typograf missing or
failed, or a file unreadable.

Why not `typograf --lint`: measured on typograf-cli 6.2.1, lint reports one
position per rule (the second wrong quote in a file is never shown) and exits 0
with findings. And typograf has no notion of Markdown: run on a raw file it
turns `echo "x" -- y` inside a code block into `echo «x» — y`. So code is masked
first — fenced and indented blocks, inline code, link targets, autolinks, HTML
comments, front matter — and the text is fed through `typograf --stdin`, one
call per file, with line numbers kept.

Non-breaking-space rules are off by default: in Markdown source U+00A0 is
invisible and turns every edit near it into a puzzle. `--nbsp` turns them on,
for documents rendered to HTML or print. A non-breaking space in the output is
shown as `⍽`.
"""
import json
import os
import re
import shutil
import subprocess
import sys

NBSP_RULES = "common/nbsp/*,ru/nbsp/*"
# Rules that rewrite Markdown structure, not text: blank-line runs, leading
# indentation of list continuations, the final newline, tabs, trailing spaces
# (a hard line break in Markdown).
ALWAYS_OFF = ",".join("common/space/" + r for r in (
    "delRepeatN", "delLeadingBlanks", "delTrailingBlanks", "insertFinalNewline",
    "replaceTab", "trimLeft", "trimRight")) + (
    # ISO dates are the norm in technical text; typograf rewrites them to 04.10.2026
    ",ru/date/fromISO"
    # These two guess at meaning and guess wrong: "так что то, что не влезло"
    # became "так что-то, что не влезло" on a real README.
    ",ru/dash/to,ru/dash/kakto"
    # "host:port", "key:value", "arXiv:2409.14509" are not a missing space
    ",common/space/afterColon"
    # resolve'ит → resolve'ит treats the wrong problem: the apostrophe ending is
    # itself the defect (lexicon.md), and its grep looks for a straight '
    ",common/punctuation/apostrophe"
    # "59x7" inside an identifier is not a multiplication: this rule offered
    # GHSA-2fmv-rv2c-59x7 -> GHSA-2fmv-rv2c-59×7 on an advisory page, which
    # breaks the link. Digits around an "x" are a hash, a resolution or a
    # version far more often than they are dimensions, and an identifier does
    # not have to sit in backticks to be one.
    ",common/number/times")
MARK = "{}"   # private-use characters: typograf leaves them alone
TOKEN = re.compile("(\\d+)")
INLINE = re.compile(
    r"`+[^`\n]*?`+"                       # inline code, any number of backticks
    r"|\]\([^)\s]*(?:\s+\"[^\"]*\")?\)"   # link target, with an optional title
    r"|<https?://[^>\s]+>"                # autolink
    r"|https?://\S+"                      # bare URL
    r"|<!--.*?-->"                        # one-line HTML comment
    r"|\[!(?:NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]"  # GitHub alert marker: "[!" stays glued
    r"|\*+|__"                            # emphasis markers: typograf reads ** as a word
)


def find_typograf():
    exe = os.environ.get("TYPOGRAF") or shutil.which("typograf")
    if not exe:
        local = os.path.expanduser("~/.local/bin/typograf")
        exe = local if os.access(local, os.X_OK) else None
    return exe


def mask(text):
    """Return (masked lines, saved segments). The line count never changes."""
    saved, out = [], []
    fence = None
    front = text.startswith("---\n")
    prev_blank, in_indent = True, False

    def keep(mo):
        saved.append(mo.group(0))
        return MARK.format(len(saved) - 1)

    for line in text.split("\n"):
        if front:
            out.append("")
            if len(out) > 1 and line == "---":
                front = False
            continue
        m = re.match(r"^ {0,3}(`{3,}|~{3,})", line)
        if fence:
            out.append("")
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence):
                fence = None
            continue
        if m:
            fence = m.group(1)
            out.append("")
            continue
        # Indented code: 4 spaces or a tab after a blank line, and what follows
        # it. A list continuation looks the same and is skipped too — a missed
        # line is cheaper than code reported as text.
        if re.match(r"^( {4}|\t)", line) and (prev_blank or in_indent):
            in_indent = True
            out.append("")
            continue
        in_indent = False
        # Padding inside a table row is alignment, not a doubled space.
        if line.lstrip().startswith("|"):
            line = re.sub(r" {2,}", " ", line)
        # A list marker is syntax: typograf reads "- item" as direct speech.
        lm = re.match(r"^(\s*(?:>\s*)*(?:(?:[-*+]|\d+[.)])\s+)?)", line)
        lead = ""
        if lm:
            lead = MARK.format(len(saved))
            saved.append(lm.group(1))
            line = line[lm.end():]
        out.append(lead + INLINE.sub(keep, line))
        prev_blank = not line.strip()
    return out, saved


def unmask(line, saved):
    return TOKEN.sub(lambda mo: saved[int(mo.group(1))], line)


def show(line):
    return line.replace(" ", "⍽")


def _run_typograf_batch(exe, input_json, locale, rules_off):
    """Run typograf on a batch of paragraphs. Returns list of fixed paragraphs or None."""
    try:
        proc = subprocess.Popen(
            [exe, "--stdin", "--stdin-filename", "paragraphs.json", "--no-color",
             "-l", locale, "-d", rules_off],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout_bytes, stderr_bytes = proc.communicate(input=input_json.encode('utf-8'))
        if proc.returncode != 0:
            print(f"typograf failed: {stderr_bytes.decode('utf-8', errors='replace').strip()}", file=sys.stderr)
            return None
        return json.loads(stdout_bytes.decode('utf-8', errors='replace'))
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"typograf error: {exc}", file=sys.stderr)
        return None


def check(path, exe, rules_off, nbsp, locale="ru,en-US"):
    try:
        text = open(path, encoding="utf-8").read()
    except (OSError, UnicodeDecodeError) as exc:
        print(f"{path}: cannot read: {exc}", file=sys.stderr)
        return None
    masked, saved = mask(text)
    # One paragraph per JSON string. typograf counts quote nesting across the
    # whole text it is given, so one unpaired quote early in a file turned every
    # later «…» into „…" (75 false lines on this skill's own pages). Strings of
    # a JSON array are processed one by one — still one typograf call per file.
    paras, start = [], None
    for i, line in enumerate(masked + [""]):
        if line.strip() and start is None:
            start = i
        elif not line.strip() and start is not None:
            paras.append((start, i))
            start = None

    fixed = list(masked)
    try:
        input_json = json.dumps(["\n".join(masked[a:b]) for a, b in paras])
        # Workaround for typograf bug: it truncates output at 64KB on large files.
        # Process in batches if input is large enough to risk this issue.
        if len(input_json) > 50000:
            # Process in batches of 10 paragraphs to keep each call under 50KB
            for batch_start in range(0, len(paras), 10):
                batch_end = min(batch_start + 10, len(paras))
                batch_paras = paras[batch_start:batch_end]
                batch_input = json.dumps(["\n".join(masked[a:b]) for a, b in batch_paras])
                out = _run_typograf_batch(exe, batch_input, locale, rules_off)
                if out is None:
                    return None
                if len(out) != len(batch_paras):
                    print(f"{path}: typograf output not comparable: {len(batch_paras)} paragraphs sent, {len(out)} returned", file=sys.stderr)
                    return None
                for (a, b), para in zip(batch_paras, out):
                    lines = para.split("\n")
                    if len(lines) != b - a:
                        print(f"{path}: typograf output not comparable: line count of lines {a + 1}–{b} changed", file=sys.stderr)
                        return None
                    fixed[a:b] = lines
        else:
            # Small input: single call
            out = _run_typograf_batch(exe, input_json, locale, rules_off)
            if out is None:
                return None
            if len(out) != len(paras):
                print(f"{path}: typograf output not comparable: {len(paras)} paragraphs sent, {len(out)} returned", file=sys.stderr)
                return None
            for (a, b), para in zip(paras, out):
                lines = para.split("\n")
                if len(lines) != b - a:
                    print(f"{path}: typograf output not comparable: line count of lines {a + 1}–{b} changed", file=sys.stderr)
                    return None
                fixed[a:b] = lines
    except OSError as exc:
        print(f"{path}: cannot run {exe}: {exc}", file=sys.stderr)
        return None

    hits = 0
    for n, (before, after) in enumerate(zip(masked, fixed), 1):
        if not nbsp:
            # Rules outside the nbsp group still insert U+00A0 (before a dash);
            # with nbsp off such a change is not a finding.
            after = after.replace(" ", " ")
        # typograf puts a space after "?" or ":" when a masked segment follows —
        # it cannot see that the segment is a closing "**" or a link.
        for mo in re.finditer("([?!:;,.])(\\d+)", before):
            after = after.replace(mo.group(1) + " " + mo.group(2), mo.group(0))
        if before != after:
            hits += 1
            print(f"{path}:{n}")
            print(f"  - {show(unmask(before, saved))}")
            print(f"  + {show(unmask(after, saved))}")
    return hits


def main(argv):
    nbsp = "--nbsp" in argv
    lang = "ru"
    if "--lang" in argv:
        i = argv.index("--lang")
        lang = argv[i + 1] if i + 1 < len(argv) else ""
        argv = argv[:i] + argv[i + 2:]
    if lang not in ("ru", "en"):
        print("--lang takes ru or en", file=sys.stderr)
        return 2
    # English text gets English quotes and dashes; Russian text may carry
    # English words, so it keeps both rule sets.
    locale = "en-US" if lang == "en" else "ru,en-US"
    if lang == "en":
        rules_extra = ",common/punctuation/quote"
    else:
        rules_extra = ""
    files = [a for a in argv if a != "--nbsp"]
    if not files:
        print("usage: typograf_check.py [--nbsp] [--lang ru|en] FILE...", file=sys.stderr)
        return 2
    exe = find_typograf()
    if not exe:
        print("typograf not found — install it with the docs-techwriter installer "
              "(./install.sh --with-typograf) or `npm install -g typograf-cli`; "
              "TYPOGRAF=<path> points at another copy", file=sys.stderr)
        return 2
    rules_off = (ALWAYS_OFF if nbsp else f"{ALWAYS_OFF},{NBSP_RULES}") + rules_extra
    total, failed = 0, False
    for f in files:
        # An unexpanded glob — `docs/*.ru.md` in a project without docs/ — is
        # an empty list, not a missing file.
        if not os.path.exists(f) and re.search(r"[*?\[]", f):
            continue
        hits = check(f, exe, rules_off, nbsp, locale)
        if hits is None:
            failed = True
        else:
            total += hits
    print(f"строк к правке: {total}")
    if failed:
        return 2
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
