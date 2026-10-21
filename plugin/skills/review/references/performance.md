# Performance

Candidates only: each must pass the SKILL.md gates. A performance finding states per-iteration cost × N × calls per
second, names the resource that saturates (pool, thread, CPU, heap), and grades hot against cold by caller frequency
(per request, per row, scheduled, once). Without that estimate it is P3.

## Database access (query shapes and migrations: [sql.md](sql.md))

- A list endpoint that loads full entities, or `JOIN FETCH`es a collection, to map two or three columns: ask for a
  projection or DTO query. A 100-row page with 200 children per row returns 20k joined rows.
- A lazy getter inside `stream().map {}` or a mapper (hidden N+1 outside the repository): 200 orders × 2 ms = 400 ms
  per request, and no slow-query log shows it.
- Bulk writes (import, sync, `saveAll` over ~100 rows) without `hibernate.jdbc.batch_size` and `order_inserts`, or on
  Postgres without `reWriteBatchedInserts=true`: 10k rows are 10k round trips.
- `findAll`, a native query or a `ResultSet` over a growing table with no limit, stream or fetch size: pgjdbc loads
  every row by default (`defaultRowFetchSize=0`); a 5M-row export is an OOM.
- Non-database work inside `@Transactional` (file or PDF generation, a Kafka `send().get()`, SOAP signing, `sleep`):
  a read-write transaction holds its connection until commit, so 600 ms inside caps ten connections at ~16 req/s.
  Check first whether the project enables lazy connection acquisition; if it does, the cost is far smaller.
- Lazy associations that work only because `spring.jpa.open-in-view` is still `true`: the connection stays held while a
  slow client downloads the rendered response.

## Concurrency and pools

- A diff that raises `maximumPoolSize`, or adds `REQUIRES_NEW`, as the fix for pool timeouts: a thread needing Cm
  connections at once needs Tn × (Cm − 1) + 1; pool 10 with ten threads that each open a second connection deadlocks.
- Callers waiting on the default Hikari `connectionTimeout` (30 s) while the client times out at 10 s: the server
  keeps working for nobody; set the wait below the caller's deadline.
- `synchronized` or a native call around blocking I/O on code that runs on virtual threads: on JDK 21 to 23 it pins
  the carrier (use `ReentrantLock`); eight pinned requests freeze every other virtual thread on eight cores.
- A fixed pool built to cap virtual-thread concurrency: use a `Semaphore` around the scarce downstream instead.
- `@Async` or an executor with an unbounded or large queue and no rejection policy: a burst waits minutes in memory
  until the pod is killed; keep the queue small so the excess is rejected.
- An expensive object created per request, task or virtual thread (`ObjectMapper`, `Pattern`, a client, a
  `ThreadLocal` cache): make it a singleton; 20k virtual threads mean 20k copies.

## External calls

- A new outbound client without both connect and read timeouts; `socketTimeout` on pgjdbc defaults to off. One hung
  gateway then holds every request thread.
- Retries added at a layer when another layer already retries: three attempts at four layers send 81 calls per user
  request. Retry at one point only.
- Retries with a fixed delay, no jitter, no attempt cap, or on a non-idempotent call (booking, payment).
- Independent calls awaited one after another, or per item in a loop: three 300 ms calls take 900 ms instead of 300.
  Run them in parallel with a bound.
- A fresh long timeout inside a request that already has a deadline: pass the remaining time down and stop when it is
  spent.
- A new fan-out to one host while the HTTP client pool keeps its default per-route limit: 50 parallel calls through a
  per-route max of 5 look like downstream slowness. Verify the configured numbers; do not assume the defaults.

## Caching

- `@Cacheable` over an expensive or external loader on a hot key without `sync = true`: Spring does not lock, so 300
  concurrent requests all call the loader when the entry expires.
- A new cache with no maximum size or weigher and no expiry, or a key built from a high-cardinality value (user id,
  timestamp, a request DTO): one entry per user per day until the heap is gone.
- `@Cacheable` on a multi-argument method with the default key: every argument, including flags that do not change the
  result, becomes the key. Use an explicit `key`.

## Hot-path cost

- `Pattern.compile`, `String.matches`, `replaceAll` or `split(regex)` inside a loop or per request: hoist into a
  `static final Pattern`. `+=` string building in a loop is quadratic: `StringBuilder`.
- A log call in a hot path that concatenates or serialises a DTO or SOAP body as its argument: the work runs even when
  the level is off. Use `{}` placeholders and keep payloads out of per-request logs.
- A metric label built from an unbounded value (user id, IIN, path parameter): one time series per value.

## Frontend

- Consecutive `await`s of independent fetches in one Server Component: start them together (`Promise.all`) and stream
  the slow part in `<Suspense>`; the first byte otherwise waits for the sum.
- A layout that reads uncached data, `cookies()` or `headers()`: it skips the segment's `loading.js` and blocks every
  navigation beneath it.
- A heavy library (charts, editor, PDF, a date suite) imported statically for code needed only after a click or on one
  route: use a dynamic `import()`.

## Estimating impact

- Cost × N × rate, stated as p99, not the mean: a 1% tail of 5 s hides behind a 100 ms mean, and a backend's p99
  becomes the caller's median when calls fan out.
- Hot against cold: a 50 ms extra query on an admin export that runs twice a day is P2 at most; the same query per
  booking request saturates a ten-connection pool.

Sources: Hibernate and pgjdbc docs; Vlad Mihalcea on N+1, fetching and connection management; HikariCP "About
Pool Sizing"; JEP 444 and JEP 491; Google SRE book chapters on cascading failures and monitoring; Brendan Gregg's USE
method; Spring cache reference; Next.js data fetching docs; web.dev code splitting.
