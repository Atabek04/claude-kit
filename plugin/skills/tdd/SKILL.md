---
name: tdd
description: "Test-first development in any stack: agree the seams with the user, then one red test and the least code to pass it per slice, expected values as literals from the requirement, refactor only once green. Use for \"/kit:tdd\", \"test-first\", \"TDD\", \"red-green-refactor\", \"write tests for this feature\", \"add integration tests\", or a change too small for kit:spec. Inside a kit:spec batch, kit:spec implement runs this loop with the batch's criteria as the cases and skips the seam round."
argument-hint: "<behaviour to build or change>"
---

# Test-driven development

A green suite is the target an agent optimises for, so the tests decide what "done" means. This loop makes them
worth keeping: each one fails for the right reason first, asserts behaviour through a public interface, and takes its
expected value from somewhere other than the code. `rules/testing.md` names the four shapes that pass while
protecting nothing; the Tests section of the matching `kit:review` stack reference and the project's own testing
rule add the stack checks.

## 1. Agree the seams

A seam is the public boundary a test observes behaviour through: an HTTP endpoint, a service method, a component's
rendered output, a CLI. Before any test, list the seams you propose, each with one line on what it catches and what
it misses, and confirm them with the user. **No test at an unconfirmed seam.** Prefer the highest seam that stays
fast and deterministic; a seam that needs a type you own mocked is too low. When the seam itself is unclear (no
public interface reaches the behaviour), that is a design question: say so before building around it.

## 2. List the behaviours

Write the behaviours as one-line cases with literal inputs and outputs, from the request, the issue or the user:
happy path, each rule's boundary, each failure the caller can see. Ask for any expected value you would otherwise
have to compute with the code you are about to write. This list is the plan; it is not written as tests yet.

## 3. One slice at a time

For each case, in order:

1. **Red:** write one test at an agreed seam. Run it alone and see it fail on the assertion, not on a compile error
   or a missing fixture.
2. **Green:** the least production code that passes it. Nothing a later case might need.
3. **Run the suite** for the touched module; a test older than this session that fails means the code is wrong,
   never that the old test gets edited, unless the user agrees the behaviour changed.

Writing every test first and then all the code tests imagined behaviour; the next slice learns from the last one.

## 4. Refactor once green

With every case green, clean up names, duplication and structure in production code and tests. Tests keep their
assertions; one that must change to survive a refactor was structural and is rewritten through the seam. Run the
suite after each step.

## 5. Done

- Every listed case has a test that failed before its code existed and passes now.
- Each guard (a retry, a lock, a validation) was shown failing with the guard removed.
- No expected value came from running the code; time and randomness are injected, not read.
- New test files pass alone and in the suite; the project's gate is green.
