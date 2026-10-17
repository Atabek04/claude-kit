# Loops on the JVM

- One test, fast: `./gradlew test --tests '<Class>.<method>'` or `mvn test -Dtest='<Class>#<method>'`; integration
  tests through the project's failsafe or Gradle task, never the whole suite per iteration.
- Repeat a flaky test with JUnit `@RepeatedTest(200)` or a shell loop counting failures; pin time with an injected
  `Clock` and randomness with a seed.
- Database bugs: Testcontainers on the real engine, never H2; log SQL with bound values (`p6spy`, or Hibernate
  `org.hibernate.orm.jdbc.bind=TRACE`) to see N+1 and wrong parameters.
- Transaction and proxy bugs: assert `TransactionSynchronizationManager.isActualTransactionActive()` at the boundary;
  a self-invoked `@Transactional` or `@Async` method is the first suspect.
- Concurrency: run the trigger from an `ExecutorService` with a `CountDownLatch` start gate; take a thread dump
  (`jstack <pid>`) on a hang.
- Performance: JFR (`-XX:StartFlightRecording`) or async-profiler for a baseline; `EXPLAIN (ANALYZE, BUFFERS)` for a
  query; a JMH benchmark only when the hot path is a pure function.
- Startup and wiring: `--debug` for the auto-configuration report; a failing `@SpringBootTest` context names the
  missing bean.
