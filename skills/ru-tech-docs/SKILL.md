---
name: ru-tech-docs
description: Produce the Russian version of English technical documentation — README, manuals, CLI help, release notes, skill files. Use when asked to "переведи доку", "сделай RU версию", "translate the README to Russian", when writing Russian docs alongside English ones, or when reviewing an existing Russian version for calques and unreadable constructions. Covers the lexicon that must not be transliterated, the English structures that have no Russian equivalent, and the mechanical checks that catch drift between the two versions.
version: "1.5.1"
---

# Russian technical documentation from English

Rules here come from two places: defects caught by a reader on a real document —
someone who said "это не по-русски" or "о чём это вообще" — and measured studies
of how professional editors actually repair machine-written text. The second kind
carries its source inline. Nothing is invented.

Two studies are cited repeatedly, both by way of the `sepia` skill:

- **LAMP** — *Can AI writing be salvaged?*, CHI 2025, [arXiv:2409.14509](https://arxiv.org/abs/2409.14509).
  1057 LLM paragraphs edited by professional writers; a seven-category taxonomy of
  what they fixed and in what proportion.
- **Slop taxonomy** — Shaib et al., *Measuring AI "Slop" in Text*,
  [arXiv:2509.19163](https://arxiv.org/abs/2509.19163). Span-level annotation by 19
  professionals; where their judgements agree and where they collapse.

Neither studied Russian. What is imported from them is *process* — the order of
edits, how to read a checklist, what not to flag — never a word list. A Russian
lexicon rule earns its place in `references/lexicon.md` by having broken a real
document, not by analogy with an English one.

## The one principle

**A good Russian version is not a translation.** It is the same content stated
the way a Russian technical writer would state it.

The clearest evidence: the English sentence

> The list is updated by hand — until it isn't.

is good English. The Russian «Список правится руками — пока не перестаёт» is
broken: the verb has nothing to govern and the sentence does not finish. No
better *translation* exists, because the ellipsis is the problem. The fix was to
say what actually happens:

> После каждого такого изменения список надо править вручную — и в какой-то
> момент его перестают править.

Longer, and correct. When a phrase resists translation, stop translating and
describe the mechanism.

## Workflow

0. **Read the venue.** Before writing a line, open 2–3 recent Russian documents
   from the same place — the project's own RU manual, previous release notes, the
   team's runbooks — and take the register, the length norms and the formatting
   habits from them. The venue defines the target voice; this skill only defines
   the defects. Nothing comparable in the repository → the general technical
   register applies.
1. **Read the English for meaning**, not for sentences. What does this paragraph
   tell the reader to do or expect?
2. **Write the Russian from that meaning.** If you catch yourself preserving the
   English word order, you are translating, not writing.
   **Then test the meaning, before any check:** cover the English, read one
   Russian paragraph, and say in one sentence what the reader must do or
   expect. Compare with the answer from step 1. A different answer, or none, is
   a rewrite — no grep below finds a paragraph that is correct word by word and
   says something else.
3. **Run the lexicon check** — `references/lexicon.md`. Grep for the known
   calques; they reappear constantly — канцелярит, «ваш» from *your*, «Для
   активации…» instead of «Чтобы активировать…», and the standard wording of
   errors («Не удаётся…» / «Не удалось…»).
4. **Check the structures** — `references/patterns.md`, fourteen of them under
   sixteen numbers (two were merged; numbers are never reused). The
   subject named by hint instead of by word — the most frequent defect of all —
   actorless prose, headings and table cells that hide their content, metaphor
   with nothing to point at, plus ellipsis, dangling references, lost
   prepositions, rhetorical flourishes and the reader's first person.
5. **Run the mechanical pass** — `references/checks.md`, fifteen checks. Facts
   that diverged between versions, links and anchors, line widths, stray
   characters, **real paths leaking into examples** — that one is the only check
   here whose consequence is a public repository — sentence length by count,
   whether an edit reached both versions, whether a glob in a list is really a
   glob, HTML entities, and typography — quotes, dashes, spaces — through
   `scripts/typograf_check.py`. That last one needs `typograf` (Node.js); it is
   the only external program here, and without it the check is skipped, not
   failed.

Steps 3–5 are cheap and catch what re-reading does not.

**Writing Russian with no English source.** The same skill applies to an original
Russian document — a manual, a runbook, an RCA written in Russian from the start.
Skip steps 1–2, keep step 0 and steps 3–5. The two defects that dominate original
Russian technical prose are both in `references/lexicon.md`: **канцелярит**
(a verbal noun with an empty verb — «осуществляется настройка» instead of
«настраивают»), and the **machine formulas** calqued from English templates
(«важно отметить», «в современном мире», «не просто X, а Y»). Step 4 in
`references/patterns.md` still applies — the structures break the same way whether
or not an English original exists. Step 5 loses only its cross-version checks;
links, anchors, numbers and example paths still need the greps.

**One check at a time, and collect before you fix.** Two rules govern how steps
3–5 are executed, and both are load-bearing:

- **Never merge the passes into one read.** A reader assessing everything at once
  collapses onto the one or two most salient defects and goes blind to the rest —
  measured on the slop taxonomy, where span precision between professional
  annotators ran 0.13–0.16 across prompting conditions. Three separate passes are
  not bureaucracy; a combined pass is a worse pass.
- **When reviewing an existing Russian version, produce the whole defect list
  first, then fix item by item.** Rewriting sentence by sentence as you read
  produces a smoothed text with the same defects redistributed. Diagnose fully,
  then repair — deepest layer first (structure → lexicon → mechanics).

## What must NOT be changed

Translating these breaks the document:

- **command names and flags** — `kb save`, `--dry-run`, `kb check`
- **field values with meaning in the tool** — `kind: reference`, `state`, `recipe`
- **file and path names in examples** — they must match the English version
  character for character, or a reader moving between versions is lost
- **error strings the user will actually see** — `index table is stale`
- **code comments** where the English term is precise for whoever edits the code

## The shape of a correct edit

Professional editors repairing machine-written text overwhelmingly **replace and
delete**; they almost never add. In the LAMP corpus the split is roughly
**74% replace / 18% delete / 8% insert**. Two consequences:

- **When in doubt, cut.** A Russian version that grew noticeably longer than the
  English without a stated reason is usually padded, not clarified. The exception
  is the founding case above: when a phrase resists translation and the mechanism
  has to be described, longer is correct.
- **The only legitimate addition is real specificity** — a version, a path, a
  command, an error string, a number. Everything else added is filler.

**Never invent a specific.** If the English is vague about a version, a filename
or a count, the Russian may not resolve it by guessing. Ask, or leave an explicit
`TODO`. A confidently stated wrong fact is worse than an acknowledged gap, and it
is the exact mechanism behind the fact-drift trap below.

**Never replace a cliché with a blander paraphrase.** This is the documented
failure mode of automated repair: the defect is smoothed into something that
reads as text and says less. Either find the concrete Russian formulation, or
delete the line.

## The read-aloud test

"Grammatically correct but unsayable" is a distinct defect, separate from
grammar and separate from vocabulary. It is what a reader means by
«это не по-русски»: nothing is wrong, and no one would ever say it.

After rewriting a sentence, say it to yourself. If a Russian engineer would not
utter it in a meeting or type it in a message, redo it in speech-shaped syntax —
even if every word is defensible.

## What is not evidence

`references/lexicon.md` is a grep list, and a grep list read literally produces
over-correction — which is its own defect, and a harder one to see. Guard rails:

- **A single hit is not a verdict; clusters are.** One transliteration, one long
  sentence, one abstract noun means nothing. Count the hits in a section and act
  when they gather.
- **Do not flag conventional containers.** Changelog categories, issue and MR
  templates, runbook and RCA section headings, standard warning blocks — the
  community expects that shape and a reader navigates by it.
- **Do not flag formal register in a formal venue.** Matching the venue beats
  forced informality; a deliberately casual RU manual sitting next to a neutral
  EN one is a defect, not a fix.
- **Do not flag clean grammar and correct punctuation.** Injecting roughness to
  sound human is a gimmick and reads as one.
- **Do not flag a listed word inside a quotation, an error string or a command.**
  Quoted material keeps its own texture — see the section above on what must not
  be changed.
- **Do not flag the author's own verified habit.** Extract the habits from the
  project's existing RU documents first, then edit toward *that* profile.

## The trap that costs most

The two versions **drift apart on facts**, not on wording. Found in one session:

- the Russian manual documented two commands where the tool ran three
- one version used `01-pipeline.md`, the other `02-pipeline.md`
- the same example file carried `2026-09-01` in one place and `2026-08-05` in
  another

None of this is a language problem, and re-reading the prose never finds it.
`references/checks.md` has the greps that do.

## Correct is not the same as clearest

`prose` in the sense "everything that is not code" is standard English — Vale
calls itself "a linter for prose". It was still worth replacing with `text` in a
repository read by non-native speakers, because nothing was lost.

Ask "does this word carry weight the plainer one would not?" — if no, take the
plainer one. That applies to the English side of a bilingual repository too.

## The English side, on demand

`references/en-side.md` covers what the English text needs — the ten-point
checklist, the overrepresented syntax templates, the vocabulary that inflates,
and the register models suppress. **Load it only when the task touches the
English text**: writing or reviewing an EN README, manual or release note, or
repairing an English original before its Russian version is made. On a pure
EN→RU run it is dead weight and stays closed.

Worth the detour when the Russian version fights back: a defect in the Russian
is often a defect inherited from the English, and fixing it upstream is cheaper
than translating around it twice.
