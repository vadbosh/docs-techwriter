# Changelog

Versions are the `version:` field in `skills/ru-tech-docs/SKILL.md`, and each is
tagged at the commit that introduced it.

Releasing, in one commit: bump `version:`, add the section here, commit, then
`./release.sh tag` and `git push --tags origin`. The tag carries this file's
section for that version, so `git tag -n99 v1.4.0` answers "what changed"
without leaving git.

A tag is not edited afterwards. Anything needing correction later belongs here.

## 1.4.0

The skill leaves the config canon (`~/ai-config-source`) for a repository of its
own, like `audit`, `kb` and `jira-op` before it. Content is unchanged: the files
under `skills/ru-tech-docs/` are byte-identical to the canon's copy at
`886f77a`.

- **New here:** `install.sh` writes the skill into Claude Code, Opencode and
  Codex, and installs the trigger rule `rules/ru-tech-docs-trigger.md` with it —
  including the `opencode.json` `instructions[]` entry and the `@`-reference in
  `~/.codex/AGENTS.md`, without which those two never read the rule.
  `release.sh check` compares the rule copies as well as the skill copies.
- The history up to 1.4.0 lives in the canon's git log
  (`git log -- skills/ru-tech-docs` there), from `897b9c2` (2026-08-09, the
  skill joins the canon) to `0694074` (2026-09-18, 1.4.0: the check "a glob in a
  list is really a glob"). The three cold reviews of 2026-09-18 and the note on
  what they fixed moved here: `kb/06-ru-tech-docs-audit.md`.
