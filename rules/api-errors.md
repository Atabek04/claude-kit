---
paths:
  - "**/*ExceptionHandler*"
  - "**/*ErrorResponse*"
  - "**/*ErrorCode*"
  - "**/exception/**"
  - "**/exceptions/**"
  - "**/errors/**"
---

# API error responses

- **One shape in every service:** `error`, `message`, `details`, `status`, `timestamp`. Every key on every error
  response, including 401, unknown route and the catch-all: route the framework's auth entry point and 404 through the
  same handler. An empty value is `null`, never an omitted key: strict decoders (kotlinx.serialization) throw on a
  missing key without a default, and a vanished key reads as removed. Switching an existing field between omitted and
  `null` is a contract change.
- **`error` is the contract and is never null:** `UPPER_SNAKE`, at most 63 characters, stable. Clients branch on it
  and pick their own localized text by it. `message` is one safe English sentence for logs and developers; clients
  never parse or display it. `details` is a machine qualifier only (reason enum, seconds left, field name), never a
  copy of `message`, never exception text.
- **Data the client needs to word its text goes in a structured field** (`details` or a named key), never only in
  `message`.
- **Never forward an upstream or driver message, URL, body, SQL or IIN to the client.** Log it with a correlation id.
- **Name the failed thing and how it failed:** `<SUBJECT>_<FAILURE>`, readable without the docs. An upstream subject
  names the gateway and the system behind it (`<GATEWAY>_<SYSTEM>_TIMEOUT`, `<GATEWAY>_<SYSTEM>_SOAP_FAULT`). Never
  bare or generic: `UPSTREAM_*`, `EXTERNAL_*`, `UNAVAILABLE`, `FAILED`, `ERROR`. Timeout, connection refused, upstream
  5xx, open breaker and unparsable reply are different codes when the client or on-call acts differently.
- **Request-level codes are shared across services, same name and meaning:** `UNAUTHORIZED`, `FORBIDDEN`,
  `NOT_FOUND` (unknown route or resource without a domain code), `METHOD_NOT_ALLOWED`, `BAD_REQUEST`,
  `VALIDATION_ERROR`, `INTERNAL_ERROR`. Reuse an existing code when the meaning matches; never invent a synonym.
- **A business rule gets its own code** (`APPLICANT_UNDERAGE`, `CERTIFICATE_EXPIRED`), 422, thrown as a dedicated
  exception; never folded into `VALIDATION_ERROR`. Format errors on request fields share `VALIDATION_ERROR` and name the
  fields in `details`. A domain "not found" is `<ENTITY>_NOT_FOUND`, so it never collides with an unknown route.
- **Same next step for the user means one code; a different next step means a different code.** Several causes at
  once: check in a fixed, documented order and return the first. Never split where it leaks: a code-guessing endpoint
  answers the same for a wrong, expired and foreign code.
- **Map what the client library really throws.** Read its source or bytecode, or drive it against a local server
  that fails the way the upstream does. A handler for an exception the library wraps away is dead code that hides
  the real path to 500.
- **Status states whose fault it is:**
  - 4xx: the caller (400 unparsable, 401 no identity, 403 not allowed, 404 missing, 409 state conflict, 422 rule
    not met, 429 per-caller rate limit).
  - 500: our bug. Nothing else.
  - 502: an upstream answered invalidly, or rejected our request (an upstream 4xx is never relayed as our 4xx).
  - 503: a dependency is down or we are overloaded; the caller may retry.
  - 504: an upstream did not answer in time.
- **429 and 503 carry `Retry-After`** in seconds, taken from the real limiter or breaker wait, never a constant. A
  retry hint on any other status is a lie.
- **Codes are released, not edited:** a code is added, never renamed or reused for another condition. The consumer
  doc lists every code with status and meaning, and states the client's fallback: unknown `error` shows a generic
  text chosen by status class. Without that fallback, a new code on an existing endpoint is a breaking enum addition.

Sources: RFC 9457; Google AIP-193; Microsoft Azure REST API guidelines; Zalando RESTful API guidelines, rule 123.
