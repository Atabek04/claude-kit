---
name: mr-description
description: "Writes or rewrites the title and description of a merge request or pull request so a reviewer with no context can review it: the why, the decisions, where to look. Use for \"/kit:mr-description\", \"write the MR description\", \"open an MR\", \"create a PR\", \"rewrite the description\", or whenever a skill or project rule asks for an MR or PR body. Host steps (API calls, branch model) stay in the project or device skill."
argument-hint: "<MR or PR number, or the branch>"
---

# MR and PR descriptions

The diff shows what changed. The description carries the why, the decisions and where to look. It stays in history,
so it must make sense in a year (Google eng-practices, "CL descriptions"). Every line earns its place; never a recap
of the diff.

Read the diff and the commit log first (`git log --format=%B base..HEAD`, `git diff --stat base...HEAD`); write
nothing from memory of the session.

## Title

Imperative, specific, stands alone in `git log`: "Return stable error codes for payment failures", never "Fix bug"
or "Updates".

## Opening

One to three sentences of prose, no header: the problem, then the approach in one breath. A reader who stops here
knows why the MR exists.

## Sections named after the change

- Group the changes into 2-5 themes; each gets a `##` header that says what the theme is ("Error contract",
  "Failures that used to be 500"). Never a generic `## Summary` or `## Changes`.
- Under a header: bullets, effect first ("Adds an audit query endpoint with paging", not "Created AuditController").
  A sub-bullet only for a rule, edge case or value the reviewer needs. Two levels at most.
- Describe the shape of the change, not an inventory. Do not list every class, file, removed type or test; name a
  symbol only where the reviewer must open it. Group the long tail in one line ("dead exceptions and handlers
  removed").
- A small MR (one theme, a few files) is the title, the opening and a test plan, with no headers.

## Optional sections, each only when true

- `## Contract`: any API, error-code or event change. What is additive, what is not and who approved it, which
  consumer is affected.
- `## Decisions`: a trade-off made, the runner-up it beat, and the known shortcomings of the chosen way.
- `## Review notes`: where to start reading, the risky spot, what looks wrong but is deliberate.
- `## Not in this MR`: deliberate scope cuts and follow-ups.
- `## Rollout`: order of deploys, flags, what to check after.

## Test plan

Checkboxes of what was actually run (build, tests, a call on a test environment). Unrun stays unticked. Never "tests
added" or test counts.

## Size check

More than five sections, or a theme the reviewer cannot hold in one sentence, means the MR is too big. Split it
(refactor apart from behaviour change, contract apart from cleanup) or say in the opening why it cannot be.

## Rules

- Ticket or spec IDs only if the repo's MR history already carries them.
- A link is extra, never the only carrier of the reason.
- No AI attribution, no praise, no "this MR".
- Re-read before the last push: review often changes what the MR does.

## Shape of a good one

```
Return stable error codes for payment failures

Clients got raw provider text and a bare 500 for most failures. Every error response now carries an `error` code
the client can map to its own text; statuses stay as before except where noted.

## Error contract
- New `error` field, additive; `message`, `details` and `status` unchanged
- Provider failures are `<PROVIDER>_<FAILURE>` (`CARDS_TIMEOUT`, `LEDGER_NOT_FOUND`); HTTP status follows the failure kind
- 401 now returns the standard body with `UNAUTHORIZED`

## Failures that used to be 500
- Checkout answers the failing provider's own status and code
- Token failures are `AUTH_*` instead of blaming the provider whose call needed the token

## Cleanup
- Dead exceptions and handlers removed; every HTTP call goes through one client

## Review notes
- Start at `ProviderExceptionHandler`; the rest follows from it
- Only status change: checkout (the app shows generic text for any 4xx/5xx)

## Test plan
- [x] Full build green
- [ ] Failing lookup on the test stage returns the expected code
```
