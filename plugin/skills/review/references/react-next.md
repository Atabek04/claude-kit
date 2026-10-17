# React and Next.js

Candidates only: each must pass the SKILL.md gates. Naming is `rules/typescript.md`; visual direction is the project's
`.claude/rules/frontend.md` and `kit:frontend-design`.

## Next.js App Router

- `"use client"` on a page or layout instead of the interactive leaf; a Client Component with no interaction.
- `useEffect` + `fetch` where a Server Component or the project's query library belongs.
- A Server Action that mutates without `revalidatePath`, `revalidateTag` or `redirect`.
- A `fetch` with no stated cache intent; `cookies()` or `headers()` making an intended-static route dynamic.
- A data-fetching segment with no `loading.tsx`/`error.tsx` or `<Suspense>` with a real fallback.
- Server-only imports (DB driver, secrets) reachable from a client file; whole rows passed to a client component that
  reads three fields.

## React

- State derived from props via `useState` + `useEffect` (compute in render); a reset on prop change (use `key`);
  effects chained into each other (one event handler).
- `key={index}` on a list that reorders, inserts or deletes.
- A `useEffect`/`useCallback` dependency list missing a reactive value (stale closure).
- Fast-changing values in Context; server data held in `useState`.
- Query keys missing a dependency; a mutation that invalidates nothing; an optimistic update with no rollback.
- A form submittable twice while pending; server errors shown only as a toast instead of on the field.
- Memoization the project's compiler already does, added with no measurement.

## Accessibility

- `<div onClick>` or `role="button"` where `<button>` belongs; a custom modal without focus trap and return.
- An input without a label (placeholder is not one); errors not tied by `aria-describedby` and `aria-invalid`.
- An interactive element unreachable by keyboard or with no visible focus.

## States and design system

- An async surface rendering only the happy path: loading, empty, error, success each exist.
- A raw hex colour, arbitrary pixel value or hand-built primitive where a token or the design-system component
  exists (grep it first).
- A destructive action with no confirmation.

## Tests

- Testing Library by test id or class where a role or label exists; Playwright by CSS selector or with
  `waitForTimeout`.
- A spec depending on another spec's data or order; a page-level spec with no axe check where the project uses one.
- A mocked component the project owns inside the test of its parent.
