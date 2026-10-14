---
paths:
  - "**/*.{test,spec}.{ts,tsx,js,jsx}"
  - "**/__tests__/**"
  - "**/src/test/**"
  - "**/src/*Test/**"
  - "**/tests/**"
  - "**/test_*.py"
  - "**/*_test.{py,go}"
---

# Tests

A green suite is the target an agent optimises for. These four shapes pass while protecting nothing; never write
them, and name them when you find them. A project's own testing rules take precedence over this file.

- **Tautological:** the expected value comes from the code under test (printed by running it, recomputed with its
  formula, read from its constants, returned by a mock the test configured). Take it from the spec, as a literal.
- **Structural:** the test asserts how the code is written (reads source text, pins private calls), so it breaks on a
  refactor and misses real bugs. Run the code and assert what it does.
- **Mock-the-world:** the unit under test or a type the project owns is mocked, or a boundary fake never fails. Fake
  only paid or slow boundaries, with their real wire format and failure modes.
- **Special-cased:** production code recognises a test's input. Solve for every valid input; a test that looks wrong
  is reported, never satisfied.
