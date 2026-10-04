# The English side of a bilingual repository

**Load this file only when the task touches the English text** — writing an EN
README, reviewing an EN manual or release note, or fixing an English original
before its Russian version is made. On a pure EN→RU run it is dead weight; do
not open it.

Everything else in this skill is about Russian. This file is the exception, and
it exists because a bilingual repository has an English side that fails in its
own way — and because a bad English original produces a bad Russian version no
matter how well the translation is done.

Source: the `sepia` skill (MIT, github.com/Nanako0129/sepia, read at commit
`94f6dc2`, v0.4.0), condensed to the non-fiction part. Underlying studies:
LAMP, [arXiv:2409.14509](https://arxiv.org/abs/2409.14509); slop taxonomy,
Shaib et al., [arXiv:2509.19163](https://arxiv.org/abs/2509.19163). For the full
treatment — per-genre files for release notes, PR replies, postmortems, tickets
and articles — go to upstream rather than growing this file.

The rules in `SKILL.md` govern here too, unchanged: read the venue first, one
check per pass, collect the defect list before fixing, cut rather than add, a
single hit is not a verdict, and the whitelist in *What is not evidence*.

## The checklist

One at a time. A combined pass collapses onto the two most salient defects.

| # | Check | What to hunt |
|---|---|---|
| 1 | Chatbot residue | "Great question", "Thanks for raising this", "I hope this helps", "Certainly", "Let's dive in", apology openers, offers of further help. A colleague does not write like a support desk — delete |
| 2 | Density | Could this say the same at half the length? Statements true in any context carry no information |
| 3 | Relevance | Does the paragraph serve the reader's actual task? Background they already have, restated questions and scope tours are filler |
| 4 | Stance | Where a judgement is required, commit to one. A comparison with no recommendation, a postmortem with no admitted mistake. Hedge once per genuinely fragile claim, not per sentence |
| 5 | Specificity | Versions, numbers, `file:line`, commands, verbatim error text — present and real. Missing → ask or leave an explicit `TODO`, never fill |
| 6 | Formatting tells | Bold-mini-heading bullets where prose would do; decorative emoji; Title Case headings; every section the same length; lists of exactly three everywhere; a heading restated by its first sentence |
| 7 | Conclusion residue | "In conclusion", "In summary", generic future outlook. End when the content ends |
| 8 | Templatedness | The same sentence frame recycled; every list item phrased identically. Vary, or turn it into a table |
| 9 | Rhythm | Uniform paragraph and sentence length throughout. Real prose is uneven — depth where it matters, one line where it does not |
| 10 | Fluency | Grammatically correct but unsayable. Read it aloud; if no one would write it in an email, redo it in speech-shaped syntax |

**Weighting.** Article-shaped text (postmortem, tech article, announcement) →
relevance, density, stance first. Short text (PR reply, ticket, review comment) →
factuality, specificity, templatedness first; density and tone matter less at
short length. Weighting sets the order, not an exemption.

## Syntax templates

Overrepresented 2–5× in machine prose and heavily edited out by professionals.

| Template | Fix |
|---|---|
| `a/the [abstract noun] of [noun]` — a sense of, the weight of, a mix of | Name the concrete thing, or cut the wrapper noun |
| Trailing or leading participial clause — "…, enabling teams to…" | Break into its own sentence with a finite verb (up to 5× human rate) |
| Nominalization as subject — realization, transformation, utilization | Turn back into a verb (2× human rate) |
| Paired abstractions — "flexibility and control" | Keep one |
| `not only X but also Y` · `it's not X, it's Y` | Say the one thing you mean |
| Rule of three — three parallel adjectives or clauses, everywhere | Two or four; break the rhythm |

## Vocabulary

Cumulative, not individual. Count the hits in a section; rewrite when they gather.

| Class | Words |
|---|---|
| Abstract grandeur | tapestry, testament, landscape, realm, journey, beacon, ecosystem, nuance, myriad |
| Performance verbs | delve, underscore, foster, harness, navigate, resonate, elevate, embrace, unravel, leverage, streamline |
| Inflation adjectives | intricate, vibrant, palpable, profound, pivotal, crucial, seamless, robust, transformative, comprehensive, multifaceted |
| Formula phrases | paving the way, it's important to note, in a world of/where, a testament to, at the end of the day, when it comes to |

Each of these has a Russian calque that arrives in the translated version —
«ландшафт», «экосистема», «бесшовный», «важно отметить». The RU table is in
`lexicon.md`; fixing the English original is the cheaper end of the same defect.

```bash
grep -rnoiE "tapestry|testament|delve|underscore|foster|harness|navigate|resonate|elevate|embrace|unravel|leverage|streamline|intricate|vibrant|palpable|profound|pivotal|crucial|seamless|robust|transformative|comprehensive|multifaceted|paving the way|important to note|not only .{1,40} but also" *.md docs/*.md
```

## What models suppress, and you can put back

Instruction-tuned models use these at 13–80% of the human rate. Restore to the
degree the venue allows — sprinkled, not poured. This is the one place where the
edit is additive.

- **contractions** — don't, it's, wouldn't
- **plain causal connectives** — *because* (used at ~20% of the human rate), *so*.
  Not *thus*, *hence*, *therefore*
- **discourse particles** — well, anyway, just, actually
- **plain speech tags** — *says* on repeat is human; rotating *notes, observes,
  remarks* is machine elegance
- **negation** — "no answer was good enough" runs at half the human rate
- **second person and direct questions** — where the genre permits

## What this does not cover

Fiction, narrative structure, character agency, voice-skill composition. If the
task is prose that tells a story, this file is the wrong tool — go to upstream
sepia, which is built for it and cites its evidence in full.
