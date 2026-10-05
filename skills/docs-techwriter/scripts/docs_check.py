#!/usr/bin/env python3
"""Mechanical checks on documentation the assistant has just edited.

Run by a hook after every file edit, in all three assistants:

    Claude Code  PostToolUse, matcher Edit|Write|MultiEdit   (JSON on stdin)
    Codex        PostToolUse, matcher Edit|Write — aliases of apply_patch
    Opencode     plugins/opencode/docs-check.ts, tool.execute.after, --text

It reads the edit, decides whether the file is documentation, and runs the
greps of the skill on the lines the edit wrote — not on the whole file, so a
defect that was already there does not come back after every edit. Found
anything or not, it ends with one line asking for the reading pass, because
the defects that matter most (meaning, a pointer left hanging, a paragraph
nobody needs) are not visible to a grep.

Exit status is always 0: the hook informs, it never blocks an edit. Output:
the JSON Claude Code and Codex read as additionalContext, or plain text with
--text. Nothing is printed for a file that is not documentation.
"""
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

DOC_NAME = re.compile(r"(^README[^/]*\.md$|^CHANGELOG[^/]*\.md$|\.(RU|ru|en)\.md$)")
CYR = re.compile(r"[А-Яа-яЁё]")

# (label, regex, languages it applies to, also in a changelog?)
CHECKS = [
    ("check 16, a pointer to a place instead of content",
     r"как (сказано|описано|говорилось) (выше|ранее)|см\. (выше|ниже)|(^|\. )(ниже|далее) — ", "ru", True),
    ("check 16, a pointer to a place instead of content",
     r"\bas (said|mentioned|described|noted) (above|earlier|before)\b|\bwhat follows\b", "en", True),
    ("check 18, a dangling «так»", r"(даже|тоже|именно) так([.,;:)!?]|$)", "ru", True),
    ("check 18, a dangling “that way”", r"\beven (that|this) way\b", "en", True),
    ("check 17, version history in a README — does the reader's own install depend on it?",
     r"исправлен[а-я]* в [0-9]|(до|с) [0-9]+\.[0-9]+\.[0-9]|в версии [0-9]", "ru", False),
    ("check 17, version history in a README — does the reader's own install depend on it?",
     r"fixed in [0-9]|\b(since|until|before) v?[0-9]+\.[0-9]+", "en", False),
    ("lexicon, a calque of meaning",
     r"суммир|откатыва[а-я]* к |судит?ся по|в открытую сторону|побеждает перв|хребет|"
     r"(читател|пользовател|автор|человек)[а-яё]* по умолчанию|по умолчанию (читател|пользовател|автор|человек)",
     "ru", True),
    ("lexicon, канцелярит",
     r"осуществл|производится (запуск|настройка|проверка)|явля[ею]тся (необходим|ключев|важн)|"
     r"в целях|на предмет|в случае возникновения|по причине того|в связи с тем|имеет место", "ru", True),
    ("lexicon, a machine formula",
     r"важно отметить|стоит отметить|в современном мире|широкий спектр|бесшовн|прокладыва|"
     r"открывает новые|подводя итог|в заключение", "ru", True),
    ("en-side.md, inflated vocabulary",
     r"\b(delve|tapestry|testament|leverage|streamline|seamless|robust|pivotal|crucial|"
     r"transformative|comprehensive|paving the way|important to note)\b", "en", True),
    ("en-side.md, a guide rule", r"\b(e\.g\.|i\.e\.)|\ballows? you to\b", "en", True),
]

# ASD-STE100, "80% of the way" (en-side.md): only the replacements that keep
# the meaning whole. (regex, the word, the approved word)
STE_WORDS = [
    (r"\butiliz(e|es|ed|ing|ation)\b", "utilize", "use"),
    (r"\bprior to\b", "prior to", "before"),
    (r"\bin order to\b", "in order to", "to"),
    (r"\bapproximately\b", "approximately", "about"),
    (r"\bcommenc(e|es|ed|ing|ement)\b", "commence", "start"),
    (r"\breplenish(es|ed|ing)?\b", "replenish", "fill"),
    (r"\bin the event that\b", "in the event that", "if"),
    (r"\bdue to the fact that\b", "due to the fact that", "because"),
]
STE_STEP_WORDS = 20
# A numbered item is a procedure step only when it gives a command: it opens
# with one of these verbs, or with a condition followed by one. Measured on
# nine READMEs: most numbered lists describe ("Writes…", "Otherwise the
# model…") and checked as steps they were noise.
STE_VERBS = (
    "add append apply attach build cd change check choose clear click clone close commit "
    "configure connect copy create delete disable download edit enable enter export extract "
    "fill find generate go import init initialize install keep launch log make merge move "
    "open pass paste point press pull push put read reboot register reload remove rename "
    "replace restart restore review run save select set sign start stop switch tag test "
    "turn type uninstall unpack update upgrade use verify wait write").split()
STE_CONDITION = r"(if|when|while|after|before|once|to|in|on|from)\b[^,]*,\s*"
STE_STEP = re.compile(rf"^(\*\*)?({STE_CONDITION})?({'|'.join(STE_VERBS)})\b", re.I)
STE_PASSIVE = r"\b(is|are|was|were|be|been|being)\s+(\w{2,}ed|built|made|run|sent|set|shown|written|given|taken|kept|found)\b"
STE_PROGRESSIVE = r"\b(is|are|was|were|be|been)\s+(?!\w*thing\b)\w{2,}ing\b"


def payload_edits(data):
    """Return [(path, [written text, ...] or None for the whole file)]."""
    tool = str(data.get("tool_name", ""))
    ti = data.get("tool_input", {})
    cwd = data.get("cwd") or os.getcwd()
    if isinstance(ti, dict) and ti.get("file_path"):
        if "content" in ti:                                  # Write
            return [(ti["file_path"], None)]
        if "edits" in ti:                                    # MultiEdit
            return [(ti["file_path"], [e.get("new_string", "") for e in ti["edits"]])]
        return [(ti["file_path"], [ti.get("new_string", "")])]  # Edit
    patch = ti if isinstance(ti, str) else next(
        (v for k, v in (ti or {}).items() if k in ("command", "patch", "patchText", "input")
         and isinstance(v, str)), "")
    if not patch or "*** " not in patch:
        return []
    out, cur = [], None
    for line in patch.splitlines():
        m = re.match(r"^\*\*\* (Add|Update) File: (.+)$", line)
        if m:
            cur = (os.path.join(cwd, m.group(2).strip()), [])
            out.append(cur)
            continue
        if line.startswith("*** "):
            cur = None
        elif cur is not None and line.startswith("+"):
            cur[1].append(line[1:])
    return [(p, ["\n".join(t)] if t else None) for p, t in out]


def language(text):
    letters = re.findall(r"[A-Za-zА-Яа-яЁё]", text)
    return "ru" if letters and len(CYR.findall(text)) > 0.2 * len(letters) else "en"


def is_doc(path, text):
    base = os.path.basename(path)
    if not base.endswith(".md") or base.startswith("review-") or "/.git/" in path:
        return False
    # the skill's own pages list the very words the greps look for
    if "/docs-techwriter/references/" in path:
        return False
    if DOC_NAME.search(base) or "/docs/" in path:
        return True
    # Russian prose in any .md; an English SKILL.md or rule quoting a Russian
    # phrase is text for a model, which the trigger rule leaves out
    return language(text) == "ru"


def changed_lines(text, written):
    lines = text.split("\n")
    if written is None:
        return set(range(1, len(lines) + 1))
    found = set()
    for piece in written:
        piece = piece.strip("\n")
        if not piece.strip():
            continue
        start = 0
        while True:
            i = text.find(piece, start)
            if i < 0:
                break
            first = text.count("\n", 0, i) + 1
            found.update(range(first, first + piece.count("\n") + 1))
            start = i + len(piece)
    return found


def prose(lines):
    """Line number -> text with code blocks, inline code and tables removed."""
    out, fence = {}, False
    front = bool(lines) and lines[0].strip() == "---"   # YAML front matter
    for n, line in enumerate(lines, 1):
        if front:
            front = not (n > 1 and line.strip() == "---")
            continue
        if re.match(r"^ {0,3}(```|~~~)", line):
            fence = not fence
            continue
        if fence or line.lstrip().startswith("|") or re.match(r"^( {4}|\t)", line):
            continue
        out[n] = re.sub(r"`[^`\n]*`", "CODE", line)
    return out


def long_sentences(pl, wanted, limit):
    """Sentences over the limit in the paragraphs the edit touched."""
    # List items and their indented continuations are not running text: a
    # list of four items without full stops is not a 60-word sentence (check 9).
    pl = dict(pl)
    in_list = False
    for n in sorted(pl):
        line = pl[n]
        if re.match(r"^\s*([-*+]|\d+[.)])\s", line):
            in_list = True
        elif not line.startswith((" ", "\t")):
            in_list = False          # a blank or unindented line ends the list
        if in_list:
            pl[n] = ""
    paras, cur = [], []
    for n in sorted(pl):
        line = pl[n]
        if not line.strip() or line.lstrip().startswith("#") or (cur and n != cur[-1][0] + 1):
            if cur:
                paras.append(cur)
            cur = []
            if not line.strip() or line.lstrip().startswith("#"):
                continue
        cur.append((n, line))
    if cur:
        paras.append(cur)
    hits = []
    for para in paras:
        if not any(n in wanted for n, _ in para):
            continue
        for s in re.split(r"(?<=[.!?])\s+", " ".join(l.strip() for _, l in para)):
            if len(s.split()) > limit:
                hits.append((para[0][0], f"sentence of {len(s.split())} words: {s[:60]}…"))
    return hits


def procedure_steps(pl, wanted):
    """ASD-STE100 on numbered steps the edit touched: length, passive, -ing.

    Only a numbered item that gives a command is a procedure step (STE_STEP);
    a bullet list, or a numbered list that describes, is not. Descriptive
    text keeps its passive, as STE itself allows.
    """
    steps, cur = [], None
    for n in sorted(pl):
        line = pl[n]
        m = re.match(r"^\s*\d+[.)]\s+(.*)$", line)
        if m:
            cur = [n, [n], m.group(1)]
            steps.append(cur)
        elif cur and line.strip() and line.startswith((" ", "\t")) and n == cur[1][-1] + 1:
            cur[1].append(n)
            cur[2] += " " + line.strip()
        else:
            cur = None
    hits = []
    for first, nums, text in steps:
        if not wanted.intersection(nums) or not STE_STEP.match(text):
            continue
        words = len(text.split())
        if words > STE_STEP_WORDS:
            hits.append((first, f"STE100, a procedure step of {words} words "
                                f"(limit {STE_STEP_WORDS}): {text[:60]}…"))
        if re.search(STE_PASSIVE, text, re.I):
            hits.append((first, f"STE100, passive in a procedure step — name who acts: {text[:70]}"))
        if re.search(STE_PROGRESSIVE, text, re.I):
            hits.append((first, f"STE100, progressive in a procedure step — simple tense: {text[:70]}"))
    return hits


def typograf(path, lang, wanted):
    script = os.path.join(HERE, "typograf_check.py")
    try:
        r = subprocess.run([sys.executable, script, "--lang", lang, path],
                           capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return []
    if r.returncode != 1:
        return []
    hits = []
    for m in re.finditer(r"^.+:(\d+)\n  - .*\n  \+ (.*)$", r.stdout, re.M):
        if int(m.group(1)) in wanted:
            hits.append((int(m.group(1)), f"check 15, typography → {m.group(2)[:70]}"))
    return hits


def check(path, written):
    try:
        text = open(path, encoding="utf-8").read()
    except (OSError, UnicodeDecodeError):
        return None
    if not is_doc(path, text):
        return None
    lines = text.split("\n")
    wanted = changed_lines(text, written)
    if not wanted:
        return None
    pl = prose(lines)
    lang = language(text)
    changelog = os.path.basename(path).upper().startswith("CHANGELOG")
    hits = []
    for n in sorted(wanted):
        line = pl.get(n)
        if line is None:
            continue
        for label, rx, langs, in_cl in CHECKS:
            if (lang not in langs) or (changelog and not in_cl):
                continue
            if re.search(rx, line, re.I):
                hits.append((n, f"{label}: {line.strip()[:90]}"))
        if lang == "en":
            for rx, word, alt in STE_WORDS:
                if re.search(rx, line, re.I):
                    hits.append((n, f"STE100 dictionary, {word} → {alt}: {line.strip()[:70]}"))
    hits += long_sentences(pl, wanted, 30 if lang == "ru" else 25)
    if lang == "en":
        hits += procedure_steps(pl, wanted)
    hits += typograf(path, lang, wanted)
    return lang, wanted, sorted(set(hits))


def report(path, lang, wanted, hits):
    name = path.replace(os.path.expanduser("~"), "~", 1)
    span = f"{min(wanted)}–{max(wanted)}" if len(wanted) > 1 else str(min(wanted))
    head = f"[docs-check] {name}, line{'s' if len(wanted) > 1 else ''} {span} written"
    pages = "patterns.md 4, 7, 9, 10, 17" if lang == "ru" else "en-side.md, its structures table"
    tail = (f"Now read the changed paragraphs against {pages}: greps do not see "
            "meaning, a pointer left hanging, or a paragraph nobody needs.")
    if not hits:
        return f"{head}: the docs-techwriter greps found nothing. {tail}"
    body = "\n".join(f"  {name}:{n} {msg}" for n, msg in hits)
    return f"{head}; docs-techwriter found:\n{body}\n{tail}"


def main(argv):
    text_mode = "--text" in argv
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return 0
    notes = []
    for path, written in payload_edits(data):
        res = check(path, written)
        if res:
            notes.append(report(path, *res))
    if not notes:
        return 0
    msg = "\n\n".join(notes)
    if text_mode:
        print(msg)
    else:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse",
                                                 "additionalContext": msg}}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Exception:          # the hook informs; it must never break an edit
        sys.exit(0)
