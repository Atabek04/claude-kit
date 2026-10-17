# Kotlin, Java and Spring

Candidates only: each must pass the SKILL.md gates. Style rules are `rules/jvm.md`; this file is what a review
catches that a linter does not.

## Kotlin

- `!!` on injected fields or repository results: `?:`, `requireNotNull(x) { "…" }` or `orElseThrow`.
- `lateinit var` outside test fixtures; a `data class` as a JPA `@Entity` (generated `equals`/`hashCode` break
  proxies and `Set` membership).
- A `when` over a hierarchy that is not `sealed`; public API returning `MutableList` or `MutableMap`.
- `runBlocking` in a controller or reactive chain; `GlobalScope.launch`; a `CoroutineScope` created per call.

## Spring

- Field or setter injection; `@Value` scattered where one `@ConfigurationProperties` type belongs.
- `@Transactional` on a private, protected or self-invoked method (the proxy never applies); on a controller; a
  multi-repository write without it; a read path without `readOnly = true`.
- An external HTTP call inside a transaction (holds a pooled connection for network latency).
- `@Async` self-invoked, or on the default unpooled executor; a future whose exception nobody handles.
- `@EventListener` writing to the database when the publisher may roll back: `@TransactionalEventListener`.
- Mutable state on a singleton bean without synchronisation; check-then-act without a unique constraint or lock.
- A cause dropped on rethrow; per-controller `try/catch` instead of one `@ControllerAdvice`.

## API

- An entity returned from a controller or nested in a DTO; `@RequestBody` without `@Valid`.
- `Pageable` with no maximum size; `200` on create (`201` + `Location`); a retried mutation with no idempotency key.
- A module importing another module's repository or entity, where the project declares module boundaries.

## JPA

- `@ManyToOne`/`@OneToOne` left EAGER; a lazy collection touched in a loop (N+1): `@EntityGraph`, `JOIN FETCH`,
  `@BatchSize`; `JOIN FETCH` on a collection plus pagination (paginates in memory).
- `CascadeType.ALL` or `REMOVE` on `@ManyToOne`; no `@Version` on concurrently edited aggregates.
- `IDENTITY` ids with batch inserts (disables batching); `saveAndFlush` in a loop.

## Tests

- `@MockitoBean` on a type the project owns inside `@SpringBootTest` (hides the wiring, splits the context cache).
- `Instant.now()` or `LocalDate.now()` in production code: inject `Clock`.
- `Thread.sleep`, `await().atMost` without a condition, assertions on unordered collections.
- A repository tested against H2 or a mock instead of Testcontainers on the real engine.
- Shared fixed keys across methods in one context; `@DirtiesContext` as the fix.
