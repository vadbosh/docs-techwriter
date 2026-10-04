# ru-tech-docs

A skill for AI coding assistants (Claude Code, Opencode, Codex) that writes the
Russian version of English technical documentation — README, manuals, CLI help,
release notes, skill files — and reviews an existing Russian version for calques
and sentences nobody would say.

The one principle: **a good Russian version is not a translation.** It is the
same content stated the way a Russian technical writer would state it. When a
phrase resists translation, the skill stops translating and describes the
mechanism instead.

Every rule comes from one of two places: a defect a reader caught on a real
document, or a measured study of how professional editors repair
machine-written text (LAMP, CHI 2025; Shaib et al., 2025). Nothing is invented.

## What a run does

1. Reads 2–3 Russian documents from the same project to take the register from.
2. Writes the Russian from the meaning of the English, not from its sentences.
3. Greps for known calques and канцелярит — `references/lexicon.md`.
4. Checks sixteen structures that break in Russian — `references/patterns.md`.
5. Runs fourteen mechanical checks — `references/checks.md`: facts that drifted
   between the versions, links and anchors, real paths leaking into examples,
   sentence length, HTML entities.

Steps 3–5 run one at a time. A combined pass sees the one or two loudest defects
and misses the rest.

The English side has a page of its own, `references/en-side.md`, loaded only
when the English text is being written or repaired.

## Install

```bash
git clone <this repository> && cd ru-tech-docs
./install.sh --dry-run    # what would be written
./install.sh
```

`install.sh` copies the skill into every assistant it finds
(`~/.claude/skills`, `~/.config/opencode/skills`, `~/.codex/skills`) and
installs the trigger rule `rules/ru-tech-docs-trigger.md` beside it. The rule is
what makes the skill fire: writing Russian next to English reads as ordinary
work and never matches the skill's description on its own. Opencode and Codex
read a rule only when their config points at it, so the installer adds the
entry to `opencode.json` `instructions[]` and the `@`-reference to
`~/.codex/AGENTS.md`. A file it is about to change is backed up first.

`--no-rule` installs the skill alone. `--skills-dir D` installs the skill into
`D` and wires nothing.

## Layout

```
skills/ru-tech-docs/SKILL.md        the workflow and the guard rails
skills/ru-tech-docs/references/     lexicon, patterns, checks, en-side
rules/ru-tech-docs-trigger.md       the rule that loads the skill
lib/wire.py                         installs the rule into one assistant
install.sh, release.sh              install; release checks
kb/                                 work notes: why the skill is shaped this way
```

## Releasing

Bump `version:` in `SKILL.md`, add the section to `CHANGELOG.md`, commit, then:

```bash
./release.sh check    # version, changelog, tag, HEAD and every installed copy agree
./release.sh tag
```

## Sending a change

A new rule needs the document it broke: the sentence, what was wrong, what
replaced it. A rule argued by analogy with English does not go in.

Commit messages are written in English, body included. A message that quotes
Russian keeps the quotation — there the Russian is the subject.

## Russian

[README.RU.md](README.RU.md)
