---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.mjs"
---

# TypeScript

- JSDoc only when the type cannot carry the meaning (units, ranges, side effects, ownership); types are the docs.
- A file is named for its single export; a file with no dominant export gets split.
- React components are noun phrases for what the user sees (`DueCardsQueue`, not `CardsWrapper`); hooks are `useX`
  where X is what they return or grant.
