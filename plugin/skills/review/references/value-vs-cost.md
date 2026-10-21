# Value versus cost: raise, size, batch or drop

Applies to every finding and every improvement idea. Two failures to prevent together: a 100-line refactor
proposed for a small gain, and a valuable refactor dropped because it is "too much work".

1. **Judge value, never effort.** Value is the bug risk removed, the reader time saved, the boilerplate removed, the
   user-visible gain, and how often the code is touched. Effort decides when and how big, never whether.
2. **High value, small cost:** raise it with the exact simpler form.
3. **High value, large cost:** one entry, sized S/M/L, with the smallest first step and a follow-up line (ticket or
   `TODO`) for the rest. Do not demand it in this change; do not drop it for size.
4. **Low value, small cost:** a nitpick, batched into the summary note (at most five), never its own thread.
5. **Low value, large cost, or a speculative abstraction:** drop, and state the reason as value ("one caller, no second
   use"), never as effort.
6. **Net-size test:** a suggestion that adds more lines or new types than it removes needs a named failing case or a
   second user; otherwise drop it.
7. **Rule of three:** two copies are mentioned, three get an extraction; never propose the abstraction on the first
   occurrence.
8. **Write the drop reason in one line before dropping anything.** "Too big" is not a reason; rule 3 applies.
9. **Unruled smell** (copy-paste, a comment restating the code, a one-caller class, flexibility nobody asked for):
   raise it once as a non-blocking suggestion with the concrete simpler form; never above P3, never blocking, even when
   no project rule names it.
10. **Stop after the review.** No extra rounds, no unasked fixes; a deeper review is offered in one line.

Editing this skill: give each rule its reason in one clause, use plain wording instead of CRITICAL or NEVER, and
keep generic good/bad example comments out; the model copies their surface. The reviewer never scores its own
findings; the verifier decides what survives.
