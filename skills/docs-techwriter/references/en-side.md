# English technical documentation

**Load this file whenever the English text is written or reviewed** — an
English README, manual, CLI help, changelog or release note, on its own or as
the original of a Russian version. On a pure EN→RU run, where the English is
not being changed, it stays closed.

The reader is assumed not to be a native speaker of English. That one
assumption carries most of the rules below: one idea per sentence, the actor
named, the tense that says what happens, no idiom to decode. A bad English
original also produces a bad Russian version however well it is translated —
the defects found in Russian READMEs were often inherited, word for word.

Sources, each rule names its own:

- **Google developer documentation style guide** — developers.google.com/style
  (highlights, tense, voice, procedures, link text, code in text, word list),
  and its Vale package, github.com/vale-cli/Google. Read 2026-10-04.
- **Microsoft Writing Style Guide** — learn.microsoft.com/style-guide (top 10
  tips, global communications, step-by-step instructions), and
  github.com/vale-cli/Microsoft. Read 2026-10-04.
- **Write the Docs** — writethedocs.org/guide/writing/docs-principles.
- **The `sepia` skill** (MIT, github.com/Nanako0129/sepia, read at commit
  `94f6dc2`, v0.4.0), condensed to the non-fiction part, with its studies:
  LAMP, [arXiv:2409.14509](https://arxiv.org/abs/2409.14509); slop taxonomy,
  Shaib et al., [arXiv:2509.19163](https://arxiv.org/abs/2509.19163).
- **Real defects** from the English READMEs of eight projects written with this
  skill (2026-10-04, 2946 lines). Where a guide rule found nothing there, the
  count says so.

Where a guide and the project disagree, the project wins (step 0 of
`SKILL.md`). Measured case: both guides want contractions, and the eight
READMEs write "do not", "is not", "cannot" 180 times — a deliberate register for
non-native readers, not a defect.

The rules in `SKILL.md` govern here too, unchanged: read the venue first, test
the meaning of each paragraph, one check per pass, collect the defect list
before fixing, cut rather than add, a single hit is not a verdict, and the
whitelist in *What is not evidence*.

## Structures that break a sentence for a non-native reader

Every row below is a real sentence from those READMEs. Greps found none of
them; reading did — the same as in Russian.

| Structure | As written | Fix |
|---|---|---|
| **A chain of clauses** — dash, semicolon, dash, each adding a thought | "…`safe-env` had carried that rule since the first commit while the redactor beside it had not, and nothing was going to notice — two implementations of one policy drift in silence, which is also why…" (63 words) | One sentence per idea. Google aims under 26 words; check 9 in `checks.md` flags 25, the ASD-STE100 limit |
| **A dangling participle** — the opening clause has no subject of its own | "Replayed over every Claude Code reply on the author's machine, **it** would have fired on 53 of 3236" — the hook was not replayed; the replies were | "Replaying every Claude Code reply on the author's machine showed that the hook would have fired on 53 of 3236" |
| **A garden path** — the first reading is wrong, and the sentence has to be read again | "what caught `zai-sk-…` being read as an OpenAI key was a test asserting that a model name is not a finding, not the pattern that let it through" | "The model name `zai-sk-…` was read as an OpenAI key. A test caught it — one that asserts a model name is not a finding. The pattern itself had let it through" |
| **A category error** — found only by the meaning test | "Their oldest session is simply the day the IDE was first used" — a session is not a day. The Russian version inherited it word for word | "Their oldest session dates from the day the IDE was first used" |

Microsoft names the cause, for machine translation and non-native readers
alike: *-ing* and *-ed* words whose subject is not stated, and more than two or
three clauses joined by *and*, *or*, *but*.

## Rules from the style guides

Each with its count on the eight READMEs. A rule that found nothing there is a
guide rule only: keep it, but do not argue from it as if it had broken
something. `—` means the rule has no grep and is checked by reading.

| Rule | Source | Not so | So | Hits |
|---|---|---|---|---|
| Present tense for what the program does | Google | "If the file will not run, PowerShell's execution policy is blocking it" | "If the file does not run, …" | 13 `will`, 1 defect (this one); the rest are real future events |
| No hypothetical *would* for normal behaviour | Google | "The server would then remove you" | "The server removes you" | — |
| Active voice, actor named; passive only to stress the object or hide an irrelevant actor | Google, Microsoft | "The service is queried, and an acknowledgment is sent" | "Send a query to the service. The server sends an acknowledgment" | 4 `is …ed by`, all legitimate |
| Lead with the point, not with *there is/are* or *you can* | Microsoft | "There are two ways to configure it" | "Configure it in one of two ways:" | 14, hints |
| *for example*, *that is* — not *e.g.*, *i.e.*, *etc.* | Google | "e.g. a theme" | "for example, a theme" | 1 |
| Sentence case headings, no period at the end | Google, Microsoft | "## How To Install It." | "## Install" | 0 |
| Link text names the target; never *here* or *this page* | Google, Write the Docs | "see [here](docs/install.md)" | "see [Installation](docs/install.md)" | 0 |
| A procedure opens with a full sentence or an imperative; a single step is a bullet, not "1." | Google | "To customize the buttons:" followed by steps | "To customize the buttons, follow these steps:" | — |
| Steps are imperative sentences; say where before what | Microsoft | "The Save button should then be clicked" | "In the dialog, select Save" | — |
| No time-anchored words that rot | Google | "currently", "latest", "as of this writing" | a version and a date | 4, each with a version beside it — legitimate |
| No double negatives | Google | "A missing path won't prevent you from continuing" | "You can continue without a path" | — |
| One word per concept, no synonym rotation | Microsoft | "repository… repo… project" for one thing | the same word each time | — |
| No idioms or cultural references | Microsoft | "out of the box", "a home run" | say what happens | — |
| *lets you*, not *allows you to*; *because*, not *as* | Google | "allows you to filter" | "lets you filter" | 0 |

## The checklist for machine-written prose

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
On the eight READMEs: no hits.

```bash
EN=$(rg -l -g '*.md' -g '!*.RU.md' -g '!*.ru.md' -g '!review-*.md' '[A-Za-z]' .)
rg -n -i "tapestry|testament|delve|underscore|foster|harness|navigate|resonate|elevate|embrace|unravel|leverage|streamline|intricate|vibrant|palpable|profound|pivotal|crucial|seamless|robust|transformative|comprehensive|multifaceted|paving the way|important to note|not only .{1,40} but also" $EN
```

Whole lines, not `-o`: «robust» in "robust to timeouts" and in "a robust
solution" are different verdicts, and only the line tells them apart.
`underscore` and `navigate` are ordinary words in technical text («the
underscore in a name», «navigate to the directory») — a hit there is not a
finding.

## ASD-STE100, 80% of the way

ASD-STE100 (Simplified Technical English, asd-ste100.org) is the controlled
language of aircraft maintenance manuals. It was made for readers whose first
language is not English — the reader this page assumes. Andrej Karpathy
suggested it on 2026-10-02 as the register for reading LLM output, and
"80% of the way" when the full specification is too strict. This page takes
that 80%: the limits and the replacements that keep the meaning whole. It does
not take the closed dictionary, the UPPERCASE convention or the one-meaning
rule — a README needs its own terms, and a forced synonym loses more than it
gains.

**Meaning wins.** When the STE form changes what the sentence says, keep the
original and move on. A hint from the hook is a question, not a verdict.

| Rule | STE limit | Hook | Not so | So |
|---|---|---|---|---|
| A procedure step | 20 words | yes, numbered items that give a command | "Open the configuration file in the editor of your choice and set the timeout to the number of seconds you need" | "Open the configuration file. Set `timeout` to the number of seconds." |
| A descriptive sentence | 25 words | yes, check 9 | — | — |
| A paragraph | 6 sentences, one topic | no, read | — | — |
| A noun cluster | 3 words | no, read | "hook output context injection mechanism" | "the mechanism that injects the hook output" |
| One instruction per sentence, except simultaneous actions | 1 | no, read | "Stop the service and delete the cache" | two steps |
| Active voice in a procedure step | — | yes, hint | "The file is copied to the skills directory" | "Copy the file to the skills directory" |
| Simple tenses in a procedure step, no *-ing* | — | yes, hint | "While the installer is running, …" | "When the installer runs, …" |
| Do not leave out *the*, *a*, *this* | — | no, read | "Run installer, then check copies" | "Run the installer, then check the copies" |

Passive voice in descriptive text is allowed, as STE itself allows it.

A numbered item counts as a procedure step only when it opens with a command
verb, or with a condition and then a command verb ("If the hook is silent,
run…"). Measured on nine READMEs on 2026-10-05: most numbered lists describe —
"Writes the Russian…", "Otherwise the model…" — and checked as steps they gave
21 hints, 20 of them noise. Restricted to commands, one hint remained, and it
was a real step.

**The dictionary.** Only replacements that lose nothing; the hook flags each one.

| Not approved | Approved |
|---|---|
| utilize | use |
| prior to | before |
| in order to | to |
| approximately | about |
| commence | start |
| replenish | fill |
| in the event that | if |
| due to the fact that | because |

STE also rejects *ensure* (→ *make sure*) and *close* as an adjective (→ *near*).
They are left out of the hook: both are common and harmless in technical
English, and every hit would be a question with the answer "keep it".

## Greps from the style guides

From the Vale packages for Google and Microsoft. Run them on prose: remove code
fences and inline code first, or every flag in a command matches. Counts are
the eight READMEs of 2026-10-04; a high count with no defect means the grep is
a hint, not a verdict.

```bash
rg -n -i '\bwill\b' $EN                                          # present tense — 13 hits, 1 defect
rg -n -i '\b(there is|there are|there were)\b' $EN               # weak opener — 14, hints
rg -n -iP '\b(e\.g\.|i\.e\.)(?=[\s,;]|$)|\betc\.' $EN            # Latin — 1
rg -n -i '\b(currently|latest|soon|as of this writing)\b' $EN    # time-anchored — 4, legitimate
rg -n -iP '\bbest(?! practices?)\b|\bsimplest\b|\bfastest\b|\bguarantees?\b' $EN   # claims — 1
rg -n -i 'in order to|utilize|make use of|a number of|due to the fact that|prior to|has the ability to|in the event that|whether or not' $EN   # wordiness — 0
rg -n -i '\b(very|really|quite|extremely|simply|basically|actually|seamlessly)\b' $EN   # adverbs — 14, hints
rg -n -i '\ballows? you to\b' $EN                                # → lets you — 0
rg -n -P '^#{1,6} [A-Z][a-z]+( [A-Z][a-z]+){2,}' $EN             # Title Case heading — 0
rg -n '^#{1,6} .*[a-z0-9]\.\s*$' $EN                             # heading ends in a period — 0
rg -n -i '\[(here|this page|this link|click here|link)\]\(' $EN  # link text — 0
rg -n '\b\w+\(s\)' $EN                                           # optional plural "file(s)" — 0
```

Not used: the contraction check (Google.Contractions, Microsoft.Contractions).
On these projects it found 180 deliberate "do not" — a register choice, see the
top of this page. Typography — dashes, doubled spaces, ellipses — is check 15
in `checks.md`, run with `--lang en`.

## What models suppress, and you can put back

Instruction-tuned models use these at 13–80% of the human rate. Restore to the
degree the venue allows — sprinkled, not poured. This is the one place where the
edit is additive.

- **contractions** — don't, it's, wouldn't; unless the project writes "do not"
  on purpose, as the eight READMEs above do
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
