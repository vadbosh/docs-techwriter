#!/usr/bin/env python3
"""Install the ru-tech-docs trigger rule into one assistant.

    wire.py <claude|opencode|codex> --src <repo> [--dry-run]

  claude    ~/.claude/rules/ru-tech-docs-trigger.md
  opencode  ~/.config/opencode/instructions/ru-tech-docs-trigger.md
            + an entry in opencode.json instructions[]
  codex     ~/.codex/memories/ru-tech-docs-trigger.md
            + an @-reference in ~/.codex/AGENTS.md

Writing the file is not enough for Opencode and Codex: each loads only what its
config points at, and an unreferenced rule is dead without saying so.

Exit codes: 0 done (or nothing to do), 1 failed, 3 assistant not installed.
Existing entries are never rewritten or reordered; a file this script is about
to change is copied to <file>.bak.<timestamp> first.
"""
import argparse
import json
import os
import shutil
import sys
import time

RULE = "ru-tech-docs-trigger.md"
H = os.path.expanduser("~")
STAMP = time.strftime("%Y%m%d-%H%M%S")
DRY = False

IDE = {
    "claude": {"home": f"{H}/.claude", "rule_dir": f"{H}/.claude/rules"},
    "opencode": {"home": f"{H}/.config/opencode",
                 "rule_dir": f"{H}/.config/opencode/instructions",
                 "config": f"{H}/.config/opencode/opencode.json"},
    "codex": {"home": f"{H}/.codex", "rule_dir": f"{H}/.codex/memories",
              "agents_md": f"{H}/.codex/AGENTS.md"},
}


def say(msg):
    print(f"    {'would ' if DRY else ''}{msg}")


def tilde(path):
    return path.replace(H, "~", 1) if path.startswith(H) else path


def backup(path):
    if os.path.exists(path):
        shutil.copy2(path, f"{path}.bak.{STAMP}")


def copy_if_changed(src, dst):
    new = open(src, "rb").read()
    if os.path.exists(dst) and open(dst, "rb").read() == new:
        print(f"    = {tilde(dst)}")
        return
    say(f"write {tilde(dst)}")
    if DRY:
        return
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, "wb") as fh:
        fh.write(new)
    os.chmod(dst, 0o644)


def wire_opencode_instruction(cfg):
    path, entry = cfg["config"], f"~/.config/opencode/instructions/{RULE}"
    if not os.path.exists(path):
        raise ValueError(f"{tilde(path)} not found — add {entry} to instructions[] by hand")
    data = json.load(open(path, encoding="utf-8"))
    arr = data.setdefault("instructions", [])
    if entry in arr:
        return
    say(f"add {entry} to {tilde(path)} instructions[]")
    if DRY:
        return
    backup(path)
    arr.append(entry)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    os.replace(tmp, path)


def wire_codex_ref(cfg):
    # Matched by basename: a reference may legitimately live under another
    # directory, and a second @-line would load the same rule twice.
    path, ref = cfg["agents_md"], f"@{cfg['rule_dir']}/{RULE}"
    text = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
    if any(line.strip().startswith("@") and line.strip().endswith("/" + RULE)
           for line in text.splitlines()):
        return
    say(f"add {ref} to {tilde(path)}")
    if DRY:
        return
    backup(path)
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(("" if text.endswith("\n") or not text else "\n") + ref + "\n")


def main():
    global DRY
    ap = argparse.ArgumentParser()
    ap.add_argument("ide", choices=sorted(IDE))
    ap.add_argument("--src", required=True)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    DRY = a.dry_run
    cfg = IDE[a.ide]
    if not os.path.isdir(cfg["home"]):
        return 3
    try:
        copy_if_changed(os.path.join(a.src, "rules", RULE),
                        os.path.join(cfg["rule_dir"], RULE))
        if a.ide == "opencode":
            wire_opencode_instruction(cfg)
        elif a.ide == "codex":
            wire_codex_ref(cfg)
    except (OSError, ValueError) as exc:
        print(f"    ! {a.ide}: {exc} — not wired", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
