---
paths:
  - "**/*ExceptionHandler*"
  - "**/*ErrorResponse*"
  - "**/exception/**"
  - "**/errors/**"
---

# API error responses

- **Body: `error`, `message`, `details`.** `error` is the contract: `UPPER_SNAKE`, stable, the only thing a client
  branches on. `message` is one safe human sentence. `details` is a machine qualifier only (reason enum, seconds
  left, upstream name), never a copy of `message`, never exception text.
- **Never forward an upstream or driver message, URL, body, SQL or IIN to the client.** Log it with a correlation id.
- **Name the failed thing and how it failed:** `<SUBJECT>_<FAILURE>` (`FL_SERVICE_TIMEOUT`, `SOURCE_DB_QUERY_TIMEOUT`,
  `STORAGE_UPLOAD_FAILED`). Never bare `UNAVAILABLE`, `FAILED`, `ERROR`. Timeout, connection refused, upstream 5xx,
  open breaker and unparsable reply are different codes when the client or on-call acts differently. A code is added,
  never renamed or reused.
- **Status states whose fault it is:**
  - 4xx: the caller (400 unparsable, 401 no identity, 403 not allowed, 404 missing, 409 state conflict, 422 rule
    not met, 429 per-caller rate limit).
  - 500: our bug. Nothing else.
  - 502: an upstream answered invalidly, or rejected our request (an upstream 4xx is never relayed as our 4xx).
  - 503: a dependency is down or we are overloaded; the caller may retry.
  - 504: an upstream did not answer in time.
- **429 and 503 carry `Retry-After`** in seconds, taken from the real limiter or breaker wait, never a constant. A
  retry hint on any other status is a lie.
- **Same next step for the user means one code; a different next step means a different code.**
