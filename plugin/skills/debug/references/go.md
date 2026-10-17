# Loops in Go

- One test: `go test ./<pkg> -run '^TestName$/subcase' -count=1` (`-count=1` defeats the test cache).
- Flaky or concurrent: `-race -count=200`, plus `-cpu=1,4,8`; `GOMAXPROCS` and `-parallel` change the interleaving.
- Hangs and leaks: `SIGQUIT` (or `curl /debug/pprof/goroutine?debug=2`) for every goroutine stack; `go.uber.org/goleak`
  in the test to catch a leaked goroutine.
- Fuzz a "sometimes wrong" function with `go test -fuzz=FuzzName -fuzztime=60s`; a failing input lands in
  `testdata/fuzz` and becomes the regression test.
- Debugger: `dlv test ./<pkg> -- -test.run '^TestName$'`.
- Performance: `go test -bench . -benchmem -cpuprofile cpu.out` then `go tool pprof`; compare runs with `benchstat`.
- HTTP handlers: `httptest.NewRecorder` with the captured request replayed; outbound calls against an `httptest`
  server that can also fail.
