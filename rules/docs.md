---
paths:
  - "**/*.md"
---

# Project docs

- A stale doc is worse than a missing one: it sends the next agent to write confident, wrong code.
- Derive what the code can tell (endpoints, tables, columns, routes): generate it or link the generator, never
  hand-write a copy.
- A doc that carries the why (rules, constraints, traps) names the code it covers and is updated in the same commit
  as that code.
- A stack claim ("we use X") is true only if real code imports X.
- Specs and reviews are history once landed: never update them to match renamed code.
- A backlog bug item states the observed symptom and the commit it was seen at (`seen at <sha>`): a later commit can
  fix it silently, and work briefed from the item then chases a bug that is gone.
