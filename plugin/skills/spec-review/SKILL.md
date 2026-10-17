---
name: spec-review
description: "Reviews a spec's spec.md or tasks.md as a skeptical staff engineer: what should not exist, what breaks at runtime, what the implementer would have to guess, what contradicts the code. Fixes what it can in place and seals the file. Runs after kit:spec-write and kit:spec-tasks, and on \"/kit:spec review\", \"review this spec\", \"check the spec for gaps\". One pass per file. Not for code: that is kit:review."
---

# Staff engineer review

Read `.claude/spec/project.md` at the repo root first; if it is missing, follow `kit:spec` (stop and offer the
template, review nothing).

You are not trying to approve the spec; you are trying to find what costs an implementer a day, while it still costs
a line to fix.

## Target

- `review <name>`: the first unsealed file of `spec.md`, then `tasks.md` (a legacy layout per project.md "Paths").
- `tasks.md` is reviewed only when `spec.md` is sealed, and approved when project.md "Approval" requires it.

**Seal check first.** Line 1 is `<!-- reviewed: <sha> -->`. If `git diff <sha> -- <file>` changes nothing but the
`reviewed` and `approved` marker lines, print "already reviewed, unchanged" and stop.

## Pass 0: should it exist

Answer all three in the verdict, each after a search, not from memory:

1. **What existing table, endpoint, tool, module or screen could absorb this?** Search project.md "Search surface".
   Name it, or name the search that found none.
2. **What line serves no story or rule?** Quote it and cut it: a section kept because the template had it, a restated
   rule, an unchanged endpoint listed, pasted implementation, a DTO that differs from an existing one by a name.
3. **What is the smallest version that still ships the capability?** Two sentences. If it is materially smaller than
   the document, that is the top finding.

## Pass 1: find every issue

Run [references/review-checklist.md](references/review-checklist.md) for the file type, plus project.md "Review
checks". For each issue: what breaks at runtime, what the implementer must guess, what the user sees when the edge
hits, what in today's code it contradicts. **Open the code the spec names;** a trap the spec missed, or a trap whose
file says otherwise, is the most valuable finding there is.

## Pass 2: fix

For each 🔴 or 🟡, weigh two or three fixes, pick one, apply it in the file. 🟢 notes are reported, not applied. Keep
the file as short as the fix allows: a fix that adds a paragraph usually belongs in a rule or a criterion as one line.
A fix that needs a decision project.md "Approval" reserves goes under **Open**, not into the file.

## Verdict

```
### Review: <spec.md | tasks.md>, <name>
**Should it exist:** absorbed by <X | search that found none>; cut <what | nothing>; smallest version <two sentences>
**Fixed:** 🔴/🟡 <issue>: <fix>
**Open (owner decides):** <issue>: <suggested fix>        (omitted when empty)
**Verdict:** ✅ approved / ⚠️ approved with warnings / ❌ needs revision
```

🔴 breaks at runtime or in sync, leaks data, misses auth, breaks a project hard rule, or contradicts the code. 🟡 a
likely edge with no criterion, a vague criterion, a missing index. 🟢 a suggestion.

On ✅ or ⚠️, commit the reviewed file (project.md "Commits"), then write that commit's SHA as the seal on line 1 and
commit it. On ❌, no seal. The seal is the review, never the approval.
