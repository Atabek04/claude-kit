---
paths:
  - "**/*.kt"
  - "**/*.kts"
  - "**/*.java"
---

# Kotlin and Java

- KDoc/Javadoc only on public API that has a contract to state; private code gets a name, not a doc. A one-line doc
  stays on one line.
- No `@param` / `@return` tags; fold the meaning into the sentence (Kotlin coding conventions).
- Acronyms: two letters stay upper (`IOStream`), three or more capitalise only the first (`HttpClient`).
- Absent values are Kotlin nullable `T?`, never `Optional<T>`.
- Booleans read as assertions (`isDue`, `hasRoot`), never negated; collections are plural nouns.
