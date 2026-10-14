# spec.md template

Section order is fixed. Omit a section only where its note says so. Target under 150 lines; past 220 it is two specs.

```markdown
# <Feature name>

**Backlog:** <file>#<item> · **UI:** <a value project.md "UI design" lists> | none · **Touches:** <modules or stacks>

## Why

<Who has the problem, in which moment, and what fails today, with the evidence (a row count, a 401, a missing
route). Two to four sentences.> **Done when:** <a measurable outcome>.

## Scope

**In:** <the capabilities this ships, one line>.

**Out:**
- <Capability>: <one-clause reason>.

## Rules

- **BR-1** <A constraint that always holds, with its number when it has one.>

## Stories

**US-1 <Actor does thing>** `[UI]`
- <One testable sentence per criterion, edge cases included.>

## Decisions

| Question | Options | Pick and why |
|---|---|---|
| <What had to be decided> | A: <gives / costs>. B: <gives / costs>. | <Pick>: <reason in one line> |

## Changes

| Kind | What | Note |
|---|---|---|
| Endpoint, new | `POST /<path>` | <auth, body, response, one line> |
| Column, new | `<table>.<column>` | <type, default, constraint, why> |

<DDL and request/response JSON for the new rows above, one fenced block each.>

## Traps

- **<The thing in today's code an implementer would get wrong.>** <What to do instead, with file:line.>

## Chosen design

<`[UI]` specs only; omitted when UI is none. Filled per project.md "UI design".>

## Open questions

<Omitted when empty. Only decisions that need the owner.>
```

## Section notes

- **Why:** no stakeholder table and no as-is/to-be essay. The success number is one phrase.
- **Out:** merges "not now" and "never". An item with a reason is a decision; a bare item is noise.
- **Stories:** no "As a / I want / so that" block: the heading names the actor and the criteria say the rest. A story
  not worth this release goes to **Out**.
- **Decisions:** one row per choice with more than one real option; omitted when there is none.
- **Changes:** a row per delta; "existing, unmodified" is never a row, and empty kinds are not listed.
- **Traps:** findings from reading the code. The section most often worth more than the rest of the spec.
