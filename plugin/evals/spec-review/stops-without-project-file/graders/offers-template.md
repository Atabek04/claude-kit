---
type: llm
weight: 2
---

PASS if the reply says `.claude/spec/project.md` is missing, offers to create it from a template, and waits for the user's answer instead of delivering a review verdict.
FAIL if the reply reviews the spec (findings, a verdict, a seal) or creates the file without asking.
