# Go

Candidates only: each must pass the SKILL.md gates. Doc rules are `rules/go.md`; `gofmt`, `go vet` and the project's
linters own formatting and the checks they report.

## Errors

- An error discarded with `_` or unchecked; a wrap with `%v` where callers need `errors.Is`/`As` (`%w`).
- An error both logged and returned (logged twice upstream); a sentinel compared with `==` after wrapping.
- `panic` for an expected failure in library code; `log.Fatal` outside `main`.

## Concurrency

- A goroutine with no exit path (no context, closed channel or `WaitGroup`): a leak per call.
- A `context.Context` dropped, stored in a struct, or replaced by `context.Background()` mid-request.
- Shared map or slice written from several goroutines without a mutex; a `sync.Mutex` copied by value.
- An unbuffered send nobody may receive; `time.After` in a loop (a timer per iteration).
- Loop variables captured by goroutines in modules older than Go 1.22 (check `go.mod`).

## Resources and APIs

- A `Body`, `Rows` or file not closed, or `defer Close()` inside a loop.
- An outbound `http.Client` without a timeout (the default never times out); `http.DefaultClient` in a server.
- A nil map written to; a nil interface holding a typed nil pointer returned as an error.
- `interface` declared next to its only implementation instead of at the consumer; an exported identifier nothing
  outside the package uses.
- A slice returned that aliases internal state the caller can mutate.

## Tests

- Not table-driven where cases differ only in data; `t.Run` names that do not say the case.
- No `-race` in the project's test command for concurrent code.
- `time.Sleep` for synchronisation; a test that needs network or a fixed port without the project's fixture.
- An `httptest` server or fake that never returns an error.
