# Changelog

Versions are the `version:` field in `skills/ru-tech-docs/SKILL.md`, and each is
tagged at the commit that introduced it.

Releasing, in one commit: bump `version:`, add the section here, commit, then
`./release.sh tag` and `git push --tags origin`. The tag carries this file's
section for that version, so `git tag -n99 v1.4.0` answers "what changed"
without leaving git.

A tag is not edited afterwards. Anything needing correction later belongs here.

## 2.2.5

**macOS, simulated.** The installer was run in the `bash:3.2` image — the bash
macOS ships — with a stand-in `uname` answering `Darwin` and a stand-in `brew`.

- **Fixed: bash 3.2 printed every path as `\~/.claude`.** `${d/#$HOME/\~}`
  keeps the backslash before bash 4.3; `install.sh` and `release.sh` use a
  `tilde` function that works in both.
- **Fixed: the Russian-file selector in `lexicon.md` used `grep -P`**, which the
  BSD `grep` of macOS does not have. It uses `rg` now; on seven repositories it
  picks exactly the files GNU `grep -rlP` picked.
- Both READMEs describe the expected macOS path step by step, each step marked
  as read from the code, simulated, or not run.

## 2.2.4

- **Both READMEs: the platform paragraph says what was tried, not what is
  "supported".** Windows was not planned for and not tried; the installer
  skips `typograf` under Git Bash or Cygwin, and the skill can be copied there
  by hand. macOS was called supported one line after "macOS was not tried"; it
  is "written for, not tried" now.

## 2.2.3

- **Both READMEs: Node.js has a row of its own** in the requirements table,
  saying it is needed only for `typograf-cli` and by nothing else in the skill.
  It shared a row with `typograf-cli` before, which left that unsaid.

## 2.2.2

- **Both READMEs: the requirements table says what happens without
  typograf-cli.** "No — the check is skipped without it" read as if the skill
  might not work; it is "no: the skill works without it, but nothing checks
  quotes, dashes and spaces".

## 2.2.1

- **Check 5 no longer flags a legitimate emoji.** `U+FE0F` after a symbol is
  part of it («⚠️»); only a selector left alone — at the start of a line or
  after an ASCII character, as in `>️` — is debris. Before, the restored «⚠️» in
  jira-op's READMEs showed up as a finding. The selector is printed as `0xfe0f`
  now, like the other invisible characters.

## 2.2.0

**English documentation is a first-class part of the skill.** Until now the
skill was described, triggered and mostly written for the Russian version; the
English side was one condensed page loaded on demand.

- **The trigger fires on English documentation for people** — `README*.md`,
  `docs/`, manuals, `CHANGELOG.md`, release notes, CLI `--help` — as well as on
  Russian prose. English text written for a model (`SKILL.md`, rules files,
  `AGENTS.md`, `CLAUDE.md`) does not trigger it on its own.
- **`references/en-side.md` holds the English rules**: the Google developer
  documentation style guide, the Microsoft Writing Style Guide, Write the Docs
  and the Vale packages for the first two (all read 2026-10-04), next to the
  existing `sepia` checklist. Every guide rule carries its count on the English
  READMEs of eight projects, so a rule that found nothing says so.
- **Structures from real English sentences**: a 63-word chain of clauses, a
  dangling participle ("Replayed over every reply…, it would have fired"), a
  garden path, and a category error ("the oldest session is simply the day…")
  that the Russian version had inherited word for word.
- **Twelve greps from the Vale packages, each run on those READMEs** before it
  went in. The contraction check is left out: it found 180 deliberate "do not",
  a register the projects chose for non-native readers.
- **`typograf_check.py --lang en`**: English rules, straight quotes left alone.
  Zero lines on nine English READMEs; a hyphen for a dash and a doubled space
  are still found. Three new tests.
- `SKILL.md`, both READMEs and the GitHub description say the skill covers
  English and Russian. They also stop claiming that every rule comes from a
  real defect or a study: since 1.5.0 some come from style guides, and the
  pages now name all three sources.

## 2.1.0

Real examples, from a review of the `README.RU.md` of eight neighbouring
repositories (2026-10-04, 2965 lines; the defect list is
`review-2026-10-04-readme-ru.md`, not tracked).

- **The rules taken from style guides in 1.5.0 found nothing there**: «ваш» had
  18 hits, all legitimate contrasts («ваш инстанс, а не этот репозиторий»);
  «Для + verbal noun», error formulas, lost prepositions and genitive chains —
  none. `lexicon.md` now says so beside each rule.
- **A calque of meaning is the most frequent defect left**: a word correct by
  the dictionary that means something else in Russian. Seven real cases join
  `lexicon.md` («суммируют сессии», «откатывается к архиву», «судится по
  пути», «падает в открытую сторону», «побеждает первое сработавшее», …) with
  a grep that finds all of them and nothing else on the eight files; also
  «воркстрим» and «синий хребет». `SKILL.md` step 3 names the class.
- `patterns.md`: real cases for the ellipsis («Мягче — когда…»), an ambiguous
  case («сообщает ID модели»), telegraph style and dangling «это».
- `checks.md`: **check 6 finds `---` right under a line of text**, which
  Markdown renders as an `<h2>` of the whole paragraph — found in a README,
  confirmed with `pandoc -f commonmark`. Check 1 notes a fact that diverges
  inside one file («девятнадцать шаблонов» vs «вместо десяти»); check 5 names
  the `U+FE0F` an emoji leaves behind.
- `SKILL.md` step 2: a real sentence that only the meaning test catches.

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
