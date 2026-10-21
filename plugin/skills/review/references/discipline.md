# Discipline: what ships and what does not

The stack references say what to look for; this file decides what is posted. A weak finding costs the author a round
trip and teaches them to skip the next one.

## Do not report

- What lint, formatters, hooks or CI already enforce, and generated files, lockfiles and vendored code.
- What the compiler or type system rules out: a null check on a non-null type, an unhandled branch of an exhaustive
  `when`.
- Code silenced on purpose with a stated reason (`@SuppressWarnings`, `NOSONAR`, a comment saying why).
- A second defence when the primary one holds: an app-level uniqueness check behind a unique index, a role check
  behind a route rule.
- Risks that need an attacker who already has the database, hours of clock skew, or a crash between two statements.
  Two requests racing one resource is normal load, never "unlikely".
- "Use library X" or "switch to pattern Y" with no concrete defect in the current code.
- "Add more tests" or "cover edge cases": a test finding names the missing case.
- Behaviour that `CLAUDE.md`, the docs or the spec define as the design.
- Style the project does not state, unless it passes the improvement lane in [value-vs-cost.md](value-vs-cost.md).

## Before posting a finding

1. Re-open the file and read the whole function and its callers; the hunk alone hides guards and validators.
2. For "missing", "duplicated" or "dead": search by concept, not only by the name you had in mind, and write the grep
   and the count. "No X exists" and "I did not find X" are different claims.
3. For "this could break callers": name the callers (grep count). For a library API you are unsure of in this
   project's version: check context7, else say "verify this exists in <library> <version>".
4. Never invent a CVE, package or version range. File paths and line numbers are real: re-open before writing them.
5. Answer honestly: is the code wrong, or only not how I would write it? Would a senior on this team push back? Can I
   cite the failing input? Any "no" or "unsure": drop or downgrade.
6. A behaviour claim needs a `file:line` citation, not an inference from a name.

## Severity honesty

P0 means stop the merge; if nobody would block on it, it is P1, and so on one notch down. "Missing test": P2, P1 only
when it covers a bug you also found. "Could be more readable" or "not SOLID": a suggestion at P3. "Not optimal
performance": P2 only with an order-of-magnitude estimate. A typical 200-line diff lands near 0 P0, 0-2 P1, 2-5 P2 and
some P3; far from that shape, recalibrate.

## Show the work

Say what was read fully, what was only skimmed, what was skipped and why, which mechanical checks ran, and what was
not run (tests, the app). The same findings with a coverage trail read as analysis; without it they read as guessing.
Coverage is the floor, never a tool-call count.

## Options

One recommended fix is the default. Offer options only for a design-level finding, when confidence in the preferred
one is below 0.8, or when the trade-off is real; mark one as the pick with its one reason.

## Final check

Every planned file read; every P0-P2 went through the verifier; every finding cites its rule or its failing input; at
most two P0; the summary says what was left out and why.
