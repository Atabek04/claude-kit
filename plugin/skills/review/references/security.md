# Security

Candidates only: each must pass the SKILL.md gates, and none is below P2. A live secret, an injection reachable from
user input, or an unauthenticated admin path is P0: tell the user before continuing. The built-in `/security-review`
goes deeper on the whole branch.

## Access

- An endpoint, handler or server action with no authentication or role check, where its siblings have one.
- A resource read or mutated by id with no ownership check (IDOR); a role or price trusted from the request body.
- An auth check only on the client (redirect or hidden button) with no server check behind it.

## Input and injection

- SQL, shell, LDAP or template built by concatenation; `eval` or `new Function` on input.
- A path from input not normalised under a fixed root; an upload without size, type and name checks.
- Deserialisation of untrusted bytes into arbitrary types; mass assignment from a request into an entity.
- An outbound request to a user-supplied host without an allow-list (SSRF, including metadata addresses).
- A regex with nested quantifiers on user input; a list endpoint with no size cap.

## Secrets and data

- A key, token or password in code, config, tests or CI logs; a secret in a client-exposed env var
  (`NEXT_PUBLIC_*`, `VITE_*`).
- Tokens in `localStorage`; auth cookies missing `HttpOnly`, `Secure` or `SameSite`.
- Tokens, passwords or personal data in logs, error responses or `toString`; stack traces returned to clients.
- `Math.random` or a non-crypto RNG for tokens; a fast hash for passwords; JWT `alg` not pinned or `exp` not checked.

## Abuse and supply chain

- A login, reset, signup or paid-API endpoint with no rate limit or quota.
- `dangerouslySetInnerHTML` or `v-html` on unsanitised content; a dynamic `href` allowing `javascript:`.
- CORS `*` with credentials; a new dependency that is unpinned, very new with few downloads, or unmaintained.
- A CI action pinned to a tag instead of a SHA, where the project pins by SHA.
