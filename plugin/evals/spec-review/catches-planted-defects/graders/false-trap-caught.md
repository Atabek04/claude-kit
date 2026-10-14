---
type: llm
weight: 2
---

PASS if the reply says the trap about `src/lists.ts:4` is wrong because the file caps a list at 200 books (`MAX_BOOKS = 200`), not 50.
FAIL if the reply accepts the 50-book cap, or does not mention the trap at all.
