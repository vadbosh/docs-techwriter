# docs-techwriter Auto-Trigger

Writing or editing Russian prose in any `.md` / `.html` / `SKILL.md` / CLI help text — a README, a manual, release notes, a rules file, a generated or hand-written HTML page — including writing RU and EN side by side, translating either direction, renaming a Russian heading, or reviewing an existing Russian version → invoke `docs-techwriter` skill BEFORE writing/editing.

**MANDATORY — no discretion.** Description-matching does not fire here: the common case is not "переведи доку" but writing both versions in the same turn, which reads as ordinary work and never triggers the skill on its own. This rule is the actual trigger mechanism.

The rule has no `paths:` on purpose. Claude Code loads a path-scoped rule only when it *reads* a matching file *inside the session's project*: a session started in one directory and editing docs in another never matched, and neither did a new file written without a prior read — measured 2026-10-04, ten `.md` reads and writes, zero loads.

In HTML the rule covers text a reader sees **and** text they only sometimes see: `alt`, `title`, `aria-label`, `placeholder`, `<meta name="description">`, `<title>`. Tag names, attribute names, class names and `id`s are code — never translated, never checked. Escaped entities (`&mdash;`, `&nbsp;`) hide characters from a plain grep, so the mechanical checks in `references/checks.md` need the entity form as well as the literal one.

Not for: Russian in chat replies, commit messages, code comments.
