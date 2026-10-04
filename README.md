# docs-techwriter

A skill for AI coding assistants (Claude Code, Opencode, Codex) that writes and
reviews technical documentation in English and Russian — README, manuals, CLI
help, release notes, changelogs. Three kinds of work: an English document on its
own, the Russian version of an English one, and a Russian document with no
English source.

For Russian, the one principle: **a good Russian version is not a translation.**
It is the same content stated the way a Russian technical writer would state it.
When a phrase resists translation, the skill stops translating and describes the
mechanism instead.

For English, the reader is assumed not to be a native speaker: one idea per
sentence, the actor named, no idiom that has to be decoded.

Every rule comes from one of three places, and says which:

- a defect a reader caught on a real document;
- a measured study of how professional editors repair machine-written text
  (LAMP, CHI 2025; Shaib et al., 2025);
- a published style guide: Google developer documentation, Microsoft Writing
  Style Guide, Microsoft Russian Style Guide.

Each rule from a guide carries its count on real READMEs, and one that has
found nothing says so. For the assistant this means such a rule is a reason to
look at a sentence, not a reason to rewrite it.

## What a run does

For a Russian version:

1. Reads 2–3 Russian documents from the same project to take the register from.
2. Writes the Russian from the meaning of the English, not from its sentences,
   then covers the English and checks that each paragraph still tells the
   reader the same thing to do.
3. Greps for known calques and канцелярит — `references/lexicon.md`.
4. Checks fourteen structures that break in Russian — `references/patterns.md`.
5. Runs fifteen mechanical checks — `references/checks.md`: facts that drifted
   between the versions, links and anchors, real paths leaking into examples,
   sentence length, HTML entities, typography.

Steps 3–5 run one at a time. A combined pass sees the one or two loudest defects
and misses the rest.

For an English document the order is the same, without the translation. Read
the venue and test the meaning of each paragraph. Then run the English rules in
`references/en-side.md` and the shared mechanical checks, one pass at a time.

## Requirements

| What | Needed for | Required |
|---|---|---|
| an assistant: Claude Code, Opencode or Codex | the skill itself | yes |
| `python3` | the installer wiring the rule; checks 1, 3, 5, 6, 9, 12, 13, 15 | yes |
| `rg` (ripgrep), `awk` | the greps in checks 2, 4, 7, 14 and in the lexicon | yes |
| `typograf-cli` 6.2.1 | check 15: quotes, dashes, spaces | no: the skill works without it, but nothing checks quotes, dashes and spaces |
| Node.js 18.19+ or 20.6+ with `npm` | only to install and run `typograf-cli`; nothing else in the skill uses Node | only with `typograf-cli` |

`typograf-cli` is the one external program. `install.sh` offers it on a
terminal and installs it into `~/.local/share/docs-techwriter/typograf`, linked as
`~/.local/bin/typograf` — `npm --prefix`, no `sudo`. Without Node.js it prints
the command for the system package manager and offers to run it: `apt-get`
(Debian, Ubuntu), `dnf` or `yum` (RHEL, Fedora, CentOS), `brew` (macOS). That
command needs `sudo` on Linux and runs only on a "yes" typed at the prompt.

The Node minimum is measured, not taken from the package: `typograf-cli` 6.2.1
declares Node 14, but calls `import.meta.resolve()`, which 18.18 and 20.5 do not
have. RHEL 8/9 and their clones ship Node 16 by default, so the installer picks
the `nodejs:20` module stream there. Ubuntu 22.04's `nodejs` is 12 — too old;
the installer says so and points at nodejs.org, NodeSource or nvm.

Tried in containers: Debian 13, Fedora 44 and AlmaLinux 9 (the full path, from
no Node to passing tests). The installer has not run on a real Mac, only in a
simulation — see [macOS: the expected path](#macos-the-expected-path).

Written for Linux (Debian/Ubuntu and RHEL-like) and macOS; the macOS branch of
the installer has run only in a simulation. Windows was not planned for and has
not been tried even that way. The installer is a bash script:
under Git Bash or Cygwin it skips `typograf`, and nobody has run the rest there.
The skill itself is Markdown and one Python script, so on Windows it can be
tried by copying `skills/docs-techwriter/` into the assistant's skills
directory by hand. The trigger rule then has to be wired by hand as well.

### macOS: the expected path

Nobody has run the installer on a Mac. This path is read from `install.sh`, and
part of it was simulated on Linux: in the `bash:3.2` image, with `uname` answering
`Darwin` and a stand-in `brew` that only logs its arguments.

Why 3.2: it is still the system `/bin/bash` of current macOS — `3.2.57` on
macOS Tahoe 26.4.1 in May 2026 (github.com/nitefood/asn/issues/108). Apple
keeps it because later bash is GPLv3, and made zsh the default shell instead.
The installer starts with `#!/usr/bin/env bash`, so a Homebrew bash 5 that
comes first in `PATH` runs it instead; that case is the one tested on Linux.

1. The skill is copied into each assistant directory found. Simulated: works.
2. The trigger rule is wired with `python3`. Without `python3` the installer
   says so and leaves the rule out; the skill then loads only when asked by
   name.
3. When `typograf-cli` is wanted and Node.js is missing, the installer offers
   `brew install node` if Homebrew is there, and runs it only after a "yes"
   typed at the prompt. Without Homebrew it points at nodejs.org. Both branches
   were simulated; a real `brew` run was not.
4. `typograf-cli` goes into `~/.local/share/docs-techwriter/typograf`, linked as
   `~/.local/bin/typograf`. That directory is not on the default `PATH` of
   macOS; the installer warns, and check 15 finds the program there anyway.

## Install

```bash
git clone <this repository> && cd docs-techwriter
./install.sh --dry-run    # what would be written
./install.sh
```

`install.sh` copies the skill into every assistant it finds
(`~/.claude/skills`, `~/.config/opencode/skills`, `~/.codex/skills`) and
installs the trigger rule `rules/docs-techwriter-trigger.md` beside it. The rule is
what makes the skill fire: writing Russian next to English reads as ordinary
work and never matches the skill's description on its own. Opencode and Codex
read a rule only when their config points at it, so the installer adds the
entry to `opencode.json` `instructions[]` and the `@`-reference to
`~/.codex/AGENTS.md`. A file it is about to change is backed up first.

`--no-rule` installs the skill alone. `--skills-dir D` installs the skill into
`D` and wires nothing. `--with-typograf` installs `typograf-cli` without asking;
`--no-typograf` never offers it. Without a terminal and without either flag,
`typograf` is skipped.

## Layout

```
skills/docs-techwriter/SKILL.md     the workflow and the guard rails
skills/docs-techwriter/references/  lexicon, patterns, checks, en-side
skills/docs-techwriter/scripts/     typograf_check.py — check 15
rules/docs-techwriter-trigger.md    the rule that loads the skill
lib/wire.py                         installs the rule into one assistant
install.sh, release.sh              install; release checks
tests/                              tests of typograf_check.py
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
