# Security

Candidates only: each must pass the SKILL.md gates, and none is below P2. A live secret, an injection reachable from
user input, or an unauthenticated admin path is P0: tell the user before continuing. Each finding names the attack
input and what the attacker gets. The built-in `/security-review` goes deeper on the whole branch.

## Authentication and tokens

- A resource-server `JwtDecoder` with no audience check (`audiences` property or an `aud` validator): a token the same
  realm minted for another client is accepted.
- `setJwtValidator(...)` that replaces `JwtValidators.createDefaultWithIssuer(...)` instead of wrapping it in a
  `DelegatingOAuth2TokenValidator`: `exp`, `nbf` and `iss` are no longer checked. Spring's decoder trusts RS256 only by
  default; a `jws-algorithms` change adding a weaker algorithm is a finding.
- A custom authorities converter that reads roles from a claim the user can influence, maps scopes to `ROLE_`, or does
  not fail closed when the claim is missing.
- `Math.random` or a non-crypto RNG for tokens; a UUID used as a secret (v1 embeds time and MAC); a fast hash for
  passwords.

## Access

- An endpoint, handler or server action with no authentication or role check, where its siblings have one; a new route
  not covered by an explicit matcher or `@PreAuthorize` while the chain lacks deny-by-default.
- A resource loaded by id and checked afterwards (IDOR): the lookup is scoped in the query
  (`findByIdAndOwnerId(id, principalId)`). Tenant, unit or owner filters take their value from the token or
  principal, never from a request parameter, body field or header.
- A role, price or status accepted from the request body; a request bound straight into an entity (mass assignment)
  or an entity returned from a controller (leaks columns such as a national ID): bind and return DTOs.
- An auth check only on the client (redirect or hidden button) with no server check behind it.

## Input and injection

- SQL, shell, LDAP or template built by concatenation; sort column or table names from input without an allow-list;
  `eval` or `new Function` on input; `ProcessBuilder` with input in the executable.
- A JAXB `unmarshal`, `DocumentBuilder`, `SAXParser` or `XMLInputFactory` on inbound or gateway XML without DOCTYPE
  and external entities disabled (XXE reads local files; a billion-laughs DOCTYPE exhausts memory). Feed JAXB a
  hardened StAX reader, not raw bytes.
- A path from input not decoded once, resolved under a fixed root and checked to stay inside it; stored uploads kept
  under the client's file name.
- `ObjectInputStream`, `XMLDecoder`, `XStream.fromXML` or `Yaml()` without `SafeConstructor` on request or queue
  bytes; Jackson default typing or `@class` polymorphism on untrusted JSON.
- A request value placed in a response header (`Content-Disposition`, `Location`, custom) without stripping CR/LF.
- A regex with nested quantifiers on user input; a list endpoint with no size cap.

## Outbound calls

- A request to a caller-influenced URL or host without a fixed scheme, host and port plus validated parts, or with
  redirects followed: a `callbackUrl` of `http://169.254.169.254/…` returns cloud credentials, and a permitted host
  that answers 302 to an internal address passes a prefix check (SSRF).
- A host allow-list that checks the name but not the resolved address: resolve, reject private and link-local ranges,
  connect to that IP (DNS rebinding).
- A trust-all `TrustManager`, `NoopHostnameVerifier` or `verify=false` client: a man in the middle reads or alters
  the payloads of the government gateway.

## Data exposure

- Tokens, passwords, national ID, phone, names, SOAP bodies or connection strings in logs, `toString`, MDC or error
  responses; user text logged without CR/LF stripped (forged log lines).
- Error responses carrying upstream gateway text, exception messages, stack traces or versions: a fixed code and a
  generic message, the detail only in the server log.
- Code-check and lookup endpoints that answer differently for wrong, expired, unknown and foreign values (status,
  body or timing): one answer for all, and a foreign-owned id is the same 404 as a missing one.

## Config, secrets and supply chain

- A key, token, password or keystore (`.p12`, `.jks`) in code, config, tests, a Dockerfile `ENV`/`ARG` or CI logs; a
  secret in a client-exposed env var (`NEXT_PUBLIC_*`, `VITE_*`).
- `management.endpoints.web.exposure.include=*`, or a custom `SecurityFilterChain` without its own actuator matcher
  (it disables Boot's default protection): `/actuator/heapdump` downloads tokens and PII.
- A new dependency or parent that is a `-SNAPSHOT`, a range or unpinned, very new with few downloads, or unmaintained.

## Web layer

- CORS that echoes `Origin` back, or lists `*` on an endpoint returning private data; exact origins from config.
- `csrf.disable()` on a chain that has any cookie-based authentication; a state change on GET. Disabling is fine only
  where auth is a bearer header.
- A login, reset, signup, OTP or SMS-sending endpoint with no rate limit per account or phone; a paid-provider call
  with no quota (50,000 "send code" calls are 50,000 SMS; a 6-digit code falls to 10^6 guesses).
- An upload without size, extension allow-list, server-side type detection and a generated storage name.

## Frontend

- A `'use server'` action or `route.ts` that does not re-check the session and resource ownership inside itself: a
  direct POST with another user's id bypasses the page-level redirect.
- A whole database row passed as a prop to a Client Component or returned from a Server Action: it serialises into
  the page payload.
- Tokens in `localStorage`, `sessionStorage` or IndexedDB (one XSS reads them; all apps on one origin share
  `localStorage`): use `HttpOnly` cookies. Auth cookies missing `HttpOnly`, `Secure` or `SameSite`.
- A `?next=` or `callbackUrl` redirect matched by `startsWith` or substring instead of parsed scheme, host and port:
  the allowed host as a prefix of a longer domain, or placed before an `@` in the URL's userinfo, passes the check.
- `dangerouslySetInnerHTML` or `v-html` on unsanitised content; a dynamic `href` allowing `javascript:`.
- A CI action pinned to a tag instead of a SHA, where the project pins by SHA (a project convention, not a standard).

Sources: OWASP Cheat Sheet Series (IDOR, Injection, XXE, Deserialization, SSRF, Logging, Error Handling, Secrets, CSRF,
HTML5, File Upload, Unvalidated Redirects); OWASP API Security Top 10 2023; Spring Security JWT resource-server
reference; Spring Boot actuator reference; Next.js data security guide; CWE Top 25.
