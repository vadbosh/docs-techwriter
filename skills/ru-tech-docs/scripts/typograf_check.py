#!/usr/bin/env python3
"""Typography check for Russian Markdown through typograf-cli.

    typograf_check.py [--nbsp] FILE...

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
    # resolve'ит → resolve’ит treats the wrong problem: the apostrophe ending is
    # itself the defect (lexicon.md), and its grep looks for a straight '
    ",common/punctuation/apostrophe")
MARK = "\ue000{}\ue001"   # private-use characters: typograf leaves them alone
TOKEN = re.compile("\ue000(\\d+)\ue001")
INLINE = re.compile(
    r"`+[^`\n]*?`+"                       # inline code, any number of backticks
    r"|\]\([^)\s]*(?:\s+\"[^\"]*\")?\)"   # link target, with an optional title
    r"|<https?://[^>\s]+>"                # autolink
    r"|https?://\S+"                      # bare URL
    r"|<!--.*?-->"                        # one-line HTML comment
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
    return line.replace("\u00a0", "⍽")


def check(path, exe, rules_off, nbsp):
    try:
        text = open(path, encoding="utf-8").read()
    except (OSError, UnicodeDecodeError) as exc:
        print(f"{path}: cannot read: {exc}", file=sys.stderr)
        return None
    masked, saved = mask(text)
    # One paragraph per JSON string. typograf counts quote nesting across the
    # whole text it is given, so one unpaired quote early in a file turned every
    # later «…» into „…“ (75 false lines on this skill's own pages). Strings of
    # a JSON array are processed one by one — still one typograf call per file.
    paras, start = [], None
    for i, line in enumerate(masked + [""]):
        if line.strip() and start is None:
            start = i
        elif not line.strip() and start is not None:
            paras.append((start, i))
            start = None
    try:
        run = subprocess.run(
            [exe, "--stdin", "--stdin-filename", "paragraphs.json", "--no-color",
             "-l", "ru,en-US", "-d", rules_off],
            input=json.dumps(["\n".join(masked[a:b]) for a, b in paras]),
            capture_output=True, text=True)
    except OSError as exc:
        print(f"{path}: cannot run {exe}: {exc}", file=sys.stderr)
        return None
    if run.returncode != 0:
        print(f"{path}: typograf failed: {run.stderr.strip()}", file=sys.stderr)
        return None
    fixed = list(masked)
    try:
        for (a, b), para in zip(paras, json.loads(run.stdout), strict=True):
            lines = para.split("\n")
            if len(lines) != b - a:
                raise ValueError(f"line count of lines {a + 1}–{b} changed")
            fixed[a:b] = lines
    except ValueError as exc:
        print(f"{path}: typograf output not comparable: {exc}", file=sys.stderr)
        return None
    hits = 0
    for n, (before, after) in enumerate(zip(masked, fixed), 1):
        if not nbsp:
            # Rules outside the nbsp group still insert U+00A0 (before a dash);
            # with nbsp off such a change is not a finding.
            after = after.replace("\u00a0", " ")
        # typograf puts a space after "?" or ":" when a masked segment follows —
        # it cannot see that the segment is a closing "**" or a link.
        for mo in re.finditer("([?!:;,.])(\ue000\\d+\ue001)", before):
            after = after.replace(mo.group(1) + " " + mo.group(2), mo.group(0))
        if before != after:
            hits += 1
            print(f"{path}:{n}")
            print(f"  - {show(unmask(before, saved))}")
            print(f"  + {show(unmask(after, saved))}")
    return hits


def main(argv):
    nbsp = "--nbsp" in argv
    files = [a for a in argv if a != "--nbsp"]
    if not files:
        print("usage: typograf_check.py [--nbsp] FILE...", file=sys.stderr)
        return 2
    exe = find_typograf()
    if not exe:
        print("typograf not found — install it with the ru-tech-docs installer "
              "(./install.sh --with-typograf) or `npm install -g typograf-cli`; "
              "TYPOGRAF=<path> points at another copy", file=sys.stderr)
        return 2
    rules_off = ALWAYS_OFF if nbsp else f"{ALWAYS_OFF},{NBSP_RULES}"
    total, failed = 0, False
    for f in files:
        # An unexpanded glob — `docs/*.ru.md` in a project without docs/ — is
        # an empty list, not a missing file.
        if not os.path.exists(f) and re.search(r"[*?\[]", f):
            continue
        hits = check(f, exe, rules_off, nbsp)
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
