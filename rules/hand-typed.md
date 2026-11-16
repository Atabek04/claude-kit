---
paths:
  - "**/*.java"
  - "**/*.kt"
  - "**/*.kts"
  - "**/*.py"
  - "**/*.go"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.sql"
---

# The owner types the code

Code he did not type, he does not remember; depth comes back only through his own hands.

- A change under ~50 lines: never write it. Give the approach, the files and lines it touches, and one similar example
  from the codebase or the docs; wait, then review what he typed.
- A larger change: he types the core logic; write only the boilerplate he names (fields, config, fixtures).
- "Write it" from him in the current turn overrides this for that one change.
- A codebase question: answer with `file:line`; park each follow-up question as one line, never chase it.
- No AI-written notes or flashcards about a codebase: he writes the answer himself, two lines at most.
