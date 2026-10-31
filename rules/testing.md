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

A green suite is the target an agent optimises for. These shapes pass while protecting nothing or break someone
else's test; never write them, and name them when you find them. A project's own testing rules take precedence.

- **Tautological:** the expected value comes from the code under test (printed by running it, recomputed with its
  formula, read from its constants, returned by a mock the test configured). Take it from the spec, as a literal.
- **Structural:** the test asserts how the code is written (reads source text, pins private calls), so it breaks on a
  refactor and misses real bugs. Run the code and assert what it does.
- **Mock-the-world:** the unit under test or a type the project owns is mocked, or a boundary fake never fails. Fake
  only paid or slow boundaries, with their real wire format and failure modes.
- **Special-cased:** production code recognises a test's input. Solve for every valid input; a test that looks wrong
  is reported, never satisfied.
- **Leaky:** on a shared database, cache or app context, the test leaves rows or keys behind, or inserts a state no
  production writer can produce, and an unrelated test fails later in another order. Delete what you insert, build
  fixtures through the code's writers or with every field the invariant needs, and let the database enforce it.
- **Clock-bound:** a performance test asserts wall time inside a shared run, so it measures the machine's load. Assert
  a statement count or a query plan, or time it in isolation.
