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
- A shared UI control owns its width: segmented controls, toggles, chips and buttons size to their content in any
  parent; only text inputs, selects and textareas stretch to the field. A call site wrapping it to stop the stretch
  means the primitive is wrong: fix it there.
