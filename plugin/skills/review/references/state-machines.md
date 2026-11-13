# Implicit state machines

Candidates only: each must pass the SKILL.md gates. A machine is any lifecycle spread across flags, a status field,
timers, retries or callbacks. Finding one is not a finding: the finding is a reachable event sequence that breaks
an invariant, each step cited `path:line`. State the invariant, then try to disprove the sequence (callers' guards,
locks, transactions, unique constraints, `@Version`) before filing.

## Signals worth tracing

- Two or more booleans describing one process (`isPaid` + `isCancelled`); a reachable combination the domain forbids.
- A status assigned from more than one place with no transition method; a caller setting it directly.
- A cancel, reset or rollback that clears some of the fields the forward path set.
- A flag set once and never reset; a state with no exit (no timeout, no job, no manual path), e.g. `PENDING` forever
  when a callback never arrives.
- A copy of the same flow in two places whose transitions have drifted.

## Races

- `UPDATE … SET status = :to` without `AND status = :from` (or `@Version`), with no check of the affected row count:
  two concurrent requests both win.
- An async result (callback, Kafka message, SSE event, retry) applied without checking that the entity is still in
  the state that started it; a redelivered message that moves the state twice.
- A side effect (push, payment, external call) fired before the transition commits, or fired again on retry.

## Labels

Each finding carries one label:
- **Confirmed:** every step of the sequence traced in code.
- **Likely:** one step depends on runtime behaviour not confirmed; name that step.
- **Smell:** correct today only by convention or ordering elsewhere; name it. Severity P3 unless the convention
  is already broken somewhere.
