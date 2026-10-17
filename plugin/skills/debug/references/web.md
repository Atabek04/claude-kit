# Loops in the browser and Node

- Component logic: one Vitest or Jest file in watch mode, filtered to the test (`-t '<name>'`), querying by role.
- Page behaviour: drive the running dev server with the built-in browser or a Playwright script and assert on the
  DOM, then read console messages and network requests; a 4xx/5xx or a duplicate request is often the whole answer.
  Ask the user to start the dev server when the project says so.
- Hydration mismatches: the console names the element; diff server HTML (`curl`) against the client render.
- Server Components and Route Handlers: `curl` the route with the same cookies to separate server from client.
- Stale data: rule out every cache layer the stack has (framework fetch cache, query client, service worker, CDN,
  backend cache) before suspecting the code; hard-reload with cache disabled.
- Flaky e2e: rerun with `--repeat-each=50 --workers=4`; replace timeouts with web-first assertions before judging.
- Performance: a Performance profile or Lighthouse run for a baseline; React Profiler for render counts; the bundle
  analyser for size regressions.
- Bisect with `git bisect run` and a script that builds and runs the one assertion.
