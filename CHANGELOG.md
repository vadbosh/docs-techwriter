# Changelog

Versions are the `version:` field in `skills/ru-tech-docs/SKILL.md`, and each is
tagged at the commit that introduced it.

Releasing, in one commit: bump `version:`, add the section here, commit, then
`./release.sh tag` and `git push --tags origin`. The tag carries this file's
section for that version, so `git tag -n99 v1.4.0` answers "what changed"
without leaving git.

A tag is not edited afterwards. Anything needing correction later belongs here.

## 2.0.0

**Breaking: the skill is now `docs-techwriter`**, and so is the repository
(github.com/vadbosh/docs-techwriter; the old URL redirects). The command is
`/docs-techwriter`, the trigger rule `rules/docs-techwriter-trigger.md`, the
typograf prefix `~/.local/share/docs-techwriter/typograf`. The content is that
of 1.5.2.

Moving from `ru-tech-docs`: install this version, then remove the old copies —
`install.sh` names any it finds and removes none:

```bash
rm -r ~/.claude/skills/ru-tech-docs ~/.config/opencode/skills/ru-tech-docs ~/.codex/skills/ru-tech-docs
rm ~/.claude/rules/ru-tech-docs-trigger.md ~/.config/opencode/instructions/ru-tech-docs-trigger.md \
   ~/.codex/memories/ru-tech-docs-trigger.md
# and the line ~/.config/opencode/instructions/ru-tech-docs-trigger.md in opencode.json
# instructions[], and the @…/ru-tech-docs-trigger.md line in ~/.codex/AGENTS.md
```

## 1.5.2

Found by running the installer in containers (Debian 13, Fedora 44,
AlmaLinux 9):

- **The Node minimum was wrong.** `typograf-cli` 6.2.1 declares Node 14 but
  calls `import.meta.resolve()`; measured in `node:*-slim` images, 18.19.0 and
  20.6.0 run it, 18.18.2 and 20.5.1 do not. `install.sh` required 12.20 and let
  AlmaLinux's Node 16 through to a `typograf` that did not start. Now: 18.19+
  in 18.x, 20.6+ in 20.x, or 21+.
- **RHEL 8/9 and clones** get the `nodejs:20` module stream instead of the
  default Node 16. Fedora, which has no modules, keeps `dnf install`.
- A Node from the package manager that is still too old (Ubuntu 22.04 ships
  12.22) is reported with where to get a newer one, not installed past.
- `typograf_check.py` used `zip(strict=True)`, Python 3.10+; RHEL 9 has 3.9.

## 1.5.1

Repository only; the skill's text is unchanged. `.gitignore` carries the
canonical `ai-gitignore` block, and `AGENTS.md`, `CLAUDE.md` and `kb/` are no
longer tracked — they are the assistant's local notes, as in `ide-sessions`.
They stay on disk; the earlier commits still contain them.

## 1.5.0

Fixes from the cold review of 2026-10-04 (`review-2026-10-04-ru-tech-docs.md`,
not tracked), a typography check, and rules taken from the Microsoft Russian
Style Guide.

**The trigger rule loads everywhere.** It lost its `paths:` front matter. Claude
Code loads a path-scoped rule only when it reads a matching file inside the
session's project: a session started in one directory and editing docs in
another never matched, and neither did a file written without a prior read.
Measured in the session that found it: ten `.md` reads and writes, zero loads.
The cost is about 1.2 KB in every Claude Code session.

**Checks that missed silently:**

- check 1 now pairs `X.md` with `X.ru.md` — before, such a pair printed nothing,
  which read as "no divergence";
- check 7 finds `/root/…`, `/Users/…` and `C:\Users\…`, not only `/home/…`;
- check 5 finds zero-width spaces, soft hyphens, BOM, and a Latin letter inside
  a Russian word («сеpвер»);
- check 13 lists globs with the star anywhere (`/proc/*/environ`, `~/.aws/*`,
  `**/*.pem`), not only at the ends;
- check 3 no longer reports a link with a title or a link inside a code block
  as broken;
- checks 2, 4 and 9 no longer exit 2 or crash in a project without `docs/`;
- `en-side.md` searches with `rg`: `grep -rnoiE` there was blocked by this
  machine's `rg-guard` — the defect `lexicon.md` lost on 2026-09-18.

**Check 15, typography**, through `scripts/typograf_check.py` and
[typograf-cli](https://github.com/typograf/typograf-cli) 6.2.1 — the one external
program in the skill, optional. The wrapper exists because typograf knows no
Markdown (it rewrote `echo "x" -- y` inside a code block) and its `--lint` shows
one place per rule and exits 0. Rules that are wrong on technical text are off:
ISO dates, `ru/dash/to` and `ru/dash/kakto` ("так что то, что" became "так
что-то"), the space after a colon (`host:port`), the curly apostrophe
(`resolve'ит` is a lexicon defect, not a typography one); non-breaking spaces
unless `--nbsp`. Paragraphs go to typograf one by one as a JSON array: one
unpaired quote early in a file had turned every later «…» into „…“. On ten Russian READMEs of
neighbouring projects: zero lines to change. `tests/test_typograf_check.sh`.

**`install.sh` offers typograf**: `--with-typograf`, `--no-typograf`, or a
question on a terminal. It installs into `~/.local/share/ru-tech-docs/typograf`
with `npm --prefix` and no `sudo`. Without Node.js it prints the command for
`apt-get`, `dnf`/`yum` or `brew` and runs it only on a "yes" typed at the
prompt, never from a flag; as root it drops `sudo`. Windows is not supported.
Both READMEs now list every requirement.

**New rules**, from the Microsoft Russian Style Guide (2011) and Travinov's
handbook — taken from the guides, not yet from a broken document of these
projects:

- `lexicon.md`: «ваш»/«вы» as a calque of *your*/*you*; «Для активации…» →
  «Чтобы активировать…»; standard error wording («Не удаётся…» / «Не
  удалось…», «Дополнительные сведения см. в…»); a term or title stays a
  genitive chain, with the meaning restated by a verb beside it; greps for the
  first two;
- `patterns.md`: the lost preposition («запрос обслуживания» → «запрос на
  обслуживание») under pattern 6; patterns 3 and 13 merged into 9 and 4, their
  numbers kept as pointers — fourteen structures under sixteen numbers;
- `SKILL.md`: the meaning test after writing — cover the English, say in one
  sentence what the reader must do, compare.

Also: three English headings in `lexicon.md` are Russian now; the example in
pattern 4 no longer uses another project's file names.

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
