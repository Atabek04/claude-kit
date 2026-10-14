# Atomic Note Creation Rules

Follow this reference exactly when the user asks to create notes for a concept introduced during coaching.

---

## Vault Detection (Do This First)

This skill is global — it can run in any vault. Pick the path mode before writing:

- **Knowledge-Base vault** — if `01-MOCs/Self-Mastery/Self-Mastery MOC.md` exists at the working directory (`~/Documents/obsidian/Knwoledge-Base`), use all the hardcoded `02-Zettelkasten/Self-Mastery/` paths below **automatically**, no questions.
- **Any other vault** — the hardcoded paths below do NOT exist. Ask the user (a) which MOC to link the note to and (b) which folder to put it in, then substitute those for the Self-Mastery paths. All other rules (title, frontmatter, body, linking, quality checklist) still apply unchanged.

---

## Pre-Creation Checklist

Before writing any note:

- [ ] Does the concept have a named framework (e.g. "Implementation Intentions") — not just a general idea?
- [ ] Does the user want a note for this specific concept, or just understanding?
- [ ] Is there already an existing note for this concept in the vault? (Search `02-Zettelkasten/` first)
- [ ] Which MOC chapter does it belong to?

---

## File Location

```
02-Zettelkasten/Self-Mastery/{Subtopic}/
```

Subtopic folders map to MOC chapters:

| MOC Chapter | Subfolder |
|---|---|
| Habits | `02-Zettelkasten/Self-Mastery/Habits/` |
| Discipline & Willpower | `02-Zettelkasten/Self-Mastery/Discipline/` |
| Time Management | `02-Zettelkasten/Self-Mastery/Time-Management/` |
| Study Techniques | `02-Zettelkasten/Self-Mastery/Study-Techniques/` |
| Mindset & Mental Models | `02-Zettelkasten/Self-Mastery/Mindset/` |
| Principles from Books | `02-Zettelkasten/Self-Mastery/Books/` |

Create the subfolder if it doesn't exist.

---

## Note Title Rules

Titles must be **complete statements** — not topic labels.

❌ Bad: "Implementation Intentions", "Planning Fallacy", "Non-Zero Day"
✓ Good: "Implementation intentions convert vague goals into automatic if-then triggers"
✓ Good: "Planning Fallacy causes people to underestimate task duration even with past evidence"

Test: Does the title teach something on its own, or just name a thing?

---

## Frontmatter Template

```yaml
---
title: {full atomic title as complete statement}
aliases: [{short recognizable name people would search for}]
tags: [self-mastery, {subtopic}]
---
```

**Alias rules:**
- Short, plain text only — no symbols (`?.`, `::`, etc.)
- Use the name people would search for (e.g. `Implementation Intentions`, `Planning Fallacy`)
- Can have multiple: `[Implementation Intentions, if-then planning, Gollwitzer]`

---

## Note Body Structure

```markdown
{Opening paragraph — explain the concept in 1-3 sentences, plain language. No heading needed.}

### Why it matters

{Why this concept is significant. One concrete consequence of not knowing it.}

---

### How it works

{The mechanism. Use an analogy. Keep paragraphs to 1-3 sentences each.}

---

### Research backing

{Author, year, key finding. One real stat if available. If uncertain, write "Research suggests..." — never fabricate.}

---

### How to apply it

{Concrete implementation. IF-THEN, checklist, example, or formula. Make it actionable.}

---

### Read more

- [[{related note full title}]]
- [[{MOC full title}]]
```

**Formatting rules:**
- Use `###` and `####` only — never `#` or `##` (too large)
- Horizontal lines `---` between major sections
- Start directly with content — no "Parent: [[MOC]]" header at top
- Short paragraphs: 1-3 sentences max. Single-sentence paragraphs are fine.
- MOC link and related notes go in "Read more" only, not at the top

---

## Linking Rules

### Inline links
Use when the note title fits naturally in a sentence. Use aliases to keep it smooth:
`[[Implementation intentions convert vague goals into automatic if-then triggers|Implementation Intentions]]`

### Read more section
- Every note created must link back to `[[Self-Mastery MOC]]`
- Link to any strongly related existing notes found in the vault
- List all inline links here again (full title, no aliases)
- Add additional related notes that didn't fit inline

### Finding related notes
Search `02-Zettelkasten/` for notes that:
- Are in the same MOC chapter
- Reference the same researcher or framework
- Address the same struggle type (e.g. all "behavioral domain" notes)

---

## MOC Update

After creating the note, add it to `01-MOCs/Self-Mastery/Self-Mastery MOC.md` under the correct chapter.

Format to use:
```markdown
- [[{full note title}|{short alias}]] — {one-line description}
```

Example:
```markdown
- [[Implementation intentions convert vague goals into automatic if-then triggers|Implementation Intentions]] — IF-THEN plans that pre-load execution so action becomes automatic
```

---

## Flashcard Creation (Only If User Asks)

Location: `05-Flashcards/Self-Mastery/{subtopic}.md`
One file per subtopic area.

Rules:
- Only create flashcards for the note just written — not general knowledge
- Every key concept, definition, formula, and example should become a card
- Follow the syntax in `04-Docs/Rules/FLASHCARD_SYNTAX.md`
- Use `START/END` block format
- After creation, tell the user to strip IDs before syncing with Anki (point to `scripts/remove-flashcard-ids.sh`)

---

## Quality Checklist Before Finishing

- [ ] Title is a complete statement (teaches something alone)
- [ ] Aliases are plain text, no symbols
- [ ] Paragraphs are 1-3 sentences
- [ ] No `#` or `##` headings
- [ ] Horizontal lines between sections
- [ ] Note starts with content, not a MOC link
- [ ] "Read more" section present with MOC link
- [ ] Note added to correct MOC chapter
- [ ] At least one link to an existing note (no orphans)
