---
name: spec-write
description: "Writes spec.md, the single requirements-and-design document for a feature: why, scope, business rules, stories with acceptance criteria, the options weighed, only the new schema/API deltas, and the code traps found by reading the code. Use for \"/kit:spec create\", \"write a spec\", \"spec this out\", \"what's the data model for this\", or whenever new functionality is about to be planned. kit:spec-review runs on its output."
---

# Spec writer

Read `.claude/spec/project.md` at the repo root first; if it is missing, follow `kit:spec` (stop and offer the
template). Produces `<spec dir>/spec.md` (project.md "Paths") from
[references/spec-template.md](references/spec-template.md).

**The measure of a spec is decisions per line.** Every line records a decision the code cannot show (a rule, a scope
cut, a criterion, a trap, a rejected option) or it goes. A fact a migration, an API doc, an owner note or the code
already states is never copied in; name it in one clause if the reader needs to know it is reused.

## Workflow

1. If the spec directory exists, ask before overwriting.
2. **Read the code the feature touches before writing a line:** project.md "Search surface", the owner notes, and
   the services, routes, screens and config the feature passes through. The Traps section is the reason to do this.
3. Think in three passes, then write once. The passes are how you think, not sections in the file:
    - **Analyst.** Who has the problem, in which moment, what fails today, what number says it is fixed.
    - **Skeptic.** Per rule and story, the unhappy paths: double submit, concurrent edit, retry after a timeout, a
      deleted parent, wrong role or another user's row, downstream failure, empty and maximum input, plus project.md
      "Spec rules". Each that applies becomes a criterion on the story it breaks.
    - **Owner.** Cut to the smallest version that ships the capability. Everything cut goes to **Out** with a reason.
4. **Options.** Every new entity, column, endpoint or architecture choice gets a Decisions row: 2 to 4 options, one
   line each (what it gives, what it costs now, what it costs later), and the pick. Test the pick through the chairs
   project.md "Spec rules" lists; a pick that loses a chair carries the reason in its row, one that loses two is the
   wrong pick.
5. Write `spec.md`, then invoke `kit:spec-review` on it. When project.md "Approval" requires it, ask the approver;
   nothing is built before. A `[UI]` spec fills `## Chosen design` per project.md "UI design".

## Rules

- **IDs:** `BR-n` for rules, `US-n` for stories, numbered once and never reused. Criteria carry no IDs.
- **A rule is stated once.** Stories and traps cite `BR-n`; they never restate it.
- **Criteria are testable without judgement:** a stored value, a row count, a status code, a rendered element.
  "Works correctly", "appropriate", "as needed" and "etc." are not criteria. Name the expected value itself (`104%`,
  `409`, three rows): tests take their oracle from the criterion, never from the code.
- **An example value is derived from the rules and the code it describes,** never copied from a mock or a design.
- **Defaults are decided, not asked.** Thresholds, caps, retries and timeouts get a number in a rule.
  `## Open questions` holds only what needs the owner and is omitted when empty.
- **Changes lists deltas only:** new or changed tables, columns, endpoints, events, tools, config. Each new table or
  endpoint carries its DDL or request/response JSON; no other pasted implementation, and a signature only when another
  module codes against it.
- **No sequence diagram** unless the flow is async or crosses three modules; **no caching, security or NFR prose**
  unless the spec departs from the project default, and then it is a rule with a number.
- **UI detail belongs to the design artifact, not to prose.** The spec records only behaviour a design cannot show:
  what a tap does, what is hidden by default, what is computed.
- **A trap or a "reuse X" line is written from the open file, never from memory:** the exact path, line and callers.
  A wrong one makes the implementer stop or, worse, build on it.
- Never leave `[TBD]`: decide it, or make it an open question.
