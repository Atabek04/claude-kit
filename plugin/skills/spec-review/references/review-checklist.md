# Review checklist

Run the section for the file type, then project.md "Review checks".

## spec.md

**Shape**
- [ ] No section restates what a migration, an API doc, an owner note or the code already says.
- [ ] Each rule is stated once; stories and traps cite `BR-n`.
- [ ] Under 220 lines, or it is split into two specs.

**Decisions**
- [ ] **Why** names who fails today, with evidence, and a measurable **Done when**.
- [ ] Every **Out** item has a reason.
- [ ] Every new entity, column, endpoint or architecture choice has a Decisions row with 2 to 4 options and a pick,
  and the pick survives project.md's chairs or its row says which chair it loses and why.
- [ ] Thresholds, caps, retries and timeouts are numbers in a rule, not open questions.
- [ ] No `[TBD]`, no "appropriate", "properly", "as needed", "etc.".

**Stories**
- [ ] Every criterion is testable without judgement: a stored value, a count, a status, a rendered element.
- [ ] Every example value can come out of the code and rules it describes; recompute one.
- [ ] The unhappy paths that apply are criteria (the `kit:spec-write` Skeptic list and project.md "Spec rules").
- [ ] Every UI story is tagged `[UI]`, and a `[UI]` spec has `## Chosen design` per project.md "UI design".

**Changes and code**
- [ ] Every row is a delta; no "existing, unmodified" rows. Each new table or endpoint has its DDL or JSON.
- [ ] Every new endpoint states its auth, and the security config that grants it was opened, not assumed.
- [ ] New foreign keys have an index.
- [ ] Every trap cites a file, and the file says what the trap claims.

## tasks.md

- [ ] Every batch has a one-sentence capability, `Files:`, `Depends:` and a `Verify:` that runs unattended.
- [ ] No horizontal batch, no tests-only batch, no infra-only batch; at most six tasks each.
- [ ] Every spec.md criterion lands in exactly one task; no task criterion lacks a story.
- [ ] No criterion depends on a later batch's deliverable (🔴: it forces work forward or fakes a boundary).
- [ ] Order is a DAG; `[P]` tasks share no file.
- [ ] `Unlock:` was found by search: grep the existing tests for each symbol, label, route or flow the batch deletes,
  renames or changes; a hit missing from `Unlock:` is 🔴. Every entry names the rule that changed what it asserts.
- [ ] Every new public name a task introduces (export, route, class, table) was grepped and does not collide.
- [ ] A criterion no unattended command proves names its command or agent in `Verify:`, or is tagged `[manual]`.
- [ ] Paths match project.md "Tasks"; UI batches build `## Chosen design` per project.md "UI design".
