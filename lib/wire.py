#!/usr/bin/env python3
"""Install the docs-techwriter trigger rule and the docs-check hook into one
assistant.

    wire.py <claude|opencode|codex> --src <repo> [--dry-run] [--no-hook]

The docs-check hook runs scripts/docs_check.py after every file edit and gives
the model what the docs-techwriter greps found in the lines it wrote:

  claude    ~/.claude/settings.json  hooks.PostToolUse, matcher Edit|Write|MultiEdit
  codex     ~/.codex/hooks.json      hooks.PostToolUse, matcher apply_patch|Edit|Write
  opencode  ~/.config/opencode/plugins/docs-check.ts (tool.execute.after)

The rule:

  claude    ~/.claude/rules/docs-techwriter-trigger.md
  opencode  ~/.config/opencode/instructions/docs-techwriter-trigger.md
            + an entry in opencode.json instructions[]
  codex     ~/.codex/memories/docs-techwriter-trigger.md
            + an @-reference in ~/.codex/AGENTS.md

Writing the file is not enough for Opencode and Codex: each loads only what its
config points at, and an unreferenced rule is dead without saying so.

Exit codes: 0 done (or nothing to do), 1 failed, 3 assistant not installed.
Existing entries are never rewritten or reordered; a file this script is about
to change is copied to ~/.local/state/docs-techwriter-backups first, the
three newest per file kept — never beside it, where Codex or Opencode would
find it.
"""
import argparse
import json
import os
import shutil
import sys
import time

RULE = "docs-techwriter-trigger.md"
H = os.path.expanduser("~")
STAMP = time.strftime("%Y%m%d-%H%M%S")
BACKUP_DIR = os.environ.get("DOCS_TECHWRITER_BACKUP_DIR") or os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.join(H, ".local", "state"),
    "docs-techwriter-backups")
DRY = False

IDE = {
    "claude": {"home": f"{H}/.claude", "rule_dir": f"{H}/.claude/rules",
               "hooks_file": f"{H}/.claude/settings.json",
               "matcher": "Edit|Write|MultiEdit",
               "check": f"{H}/.claude/skills/docs-techwriter/scripts/docs_check.py"},
    "opencode": {"home": f"{H}/.config/opencode",
                 "rule_dir": f"{H}/.config/opencode/instructions",
                 "config": f"{H}/.config/opencode/opencode.json",
                 "plugin_dir": f"{H}/.config/opencode/plugins"},
    "codex": {"home": f"{H}/.codex", "rule_dir": f"{H}/.codex/memories",
              "agents_md": f"{H}/.codex/AGENTS.md",
              "hooks_file": f"{H}/.codex/hooks.json",
              "matcher": "^(apply_patch|Edit|Write)$",
              "check": f"{H}/.codex/skills/docs-techwriter/scripts/docs_check.py"},
}


def say(msg):
    print(f"    {'would ' if DRY else ''}{msg}")


def tilde(path):
    return path.replace(H, "~", 1) if path.startswith(H) else path


def backup(path):
    if not os.path.exists(path):
        return
    os.makedirs(BACKUP_DIR, exist_ok=True)
    os.chmod(BACKUP_DIR, 0o700)
    rel = os.path.relpath(path, H) if path.startswith(H + os.sep) else path.lstrip(os.sep)
    base = os.path.join(BACKUP_DIR, rel.replace(os.sep, "_") + ".bak.")
    shutil.copy2(path, base + STAMP)
    old = sorted((f for f in os.listdir(BACKUP_DIR)
                  if os.path.join(BACKUP_DIR, f).startswith(base)), reverse=True)
    for f in old[3:]:
        os.remove(os.path.join(BACKUP_DIR, f))


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


def wire_hook(cfg):
    """One PostToolUse entry running docs_check.py; kept, never duplicated."""
    path, cmd = cfg["hooks_file"], f"python3 {cfg['check']}"
    data = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
    post = data.setdefault("hooks", {}).setdefault("PostToolUse", [])
    for group in post:
        for h in group.get("hooks", []):
            if "docs_check.py" in str(h.get("command", "")):
                if h["command"] == cmd:
                    return
                say(f"update the docs-check hook path in {tilde(path)}")
                if not DRY:
                    backup(path)
                    h["command"] = cmd
                    _save_json(path, data)
                return
    say(f"add a PostToolUse docs-check hook to {tilde(path)}")
    if DRY:
        return
    backup(path)
    post.append({"matcher": cfg["matcher"], "hooks": [{
        "type": "command", "command": cmd, "timeout": 30}]})
    _save_json(path, data)
    if "codex" in path:
        say("Codex runs the new hook only once trusted: at its next start choose "
            "\"Trust all and continue\"")


def _save_json(path, data):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    os.replace(tmp, path)


def main():
    global DRY
    ap = argparse.ArgumentParser()
    ap.add_argument("ide", choices=sorted(IDE))
    ap.add_argument("--src", required=True)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-hook", action="store_true")
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
        if not a.no_hook:
            if a.ide == "opencode":
                copy_if_changed(os.path.join(a.src, "plugins/opencode/docs-check.ts"),
                                os.path.join(cfg["plugin_dir"], "docs-check.ts"))
            else:
                wire_hook(cfg)
    except (OSError, ValueError) as exc:
        print(f"    ! {a.ide}: {exc} — not wired", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
