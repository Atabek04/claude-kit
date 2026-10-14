# Gate false positives

When `no-slop.sh` blocks something that was correct, log it here and tell the user. Do not rephrase the code to slip past
the pattern, and do not edit the gate to make yourself pass.

**Fix it now. This file is not a queue.**

A false positive is a bug in the gate, and it is due the same day as any other bug. Deferring one costs more than fixing
it: every later session hits the same wrong block, and each is one step from working around it. That is how a checked rule
quietly becomes an evaded rule.

**The only reason to log without fixing** is that you cannot yet tell what the correct general rule is, and one example is
not enough to infer it. That is rare. "The rule is deliberately blunt" is not that reason; a blunt rule that misfires has
the wrong boundary, and the boundary is the thing to fix.

**Why this file exists.** Fixes need cases. A gate that fires wrongly is worse than no gate, because the cheapest way past
it makes the code worse: delete a comment carrying real information, rename `PaymentProcessor` to `PaymentThing`, split a
function to dodge a length check. Those edits look like compliance and are invisible in review.

**Three legitimate moves when a gate fires.** Fix the code. Fix the gate. Escalate to the user. Evading the pattern is not
one of them, and neither is deleting the gate.

Every row must say what was done, not what should be done later. A row whose fix column says "if this recurs" is an unfixed
bug wearing a log entry.

| Date | File | Rule | What was blocked | Why the rule was wrong |
|---|---|---|---|---|
| 2026-10-14 | `backend/api/internal/httpapi/rafiq.go` | `commented-out-code` | A prose comment whose last clause ended in `);` | Genuine false positive: any comment ending in `;` or `}` counted as code. **Fixed**: a trailing `;` or `}` counts only when the text starts like a statement (call, assignment, `return`, `val`) and has no sentence break. A leading `}` or a trailing `{` still counts. Cases: a statement, `} else {` and `total = a + b;` deny; prose ending in `;`, a route ending in `{id}` and a two-clause sentence allow. |
| 2026-10-14 | `docs/architecture/hosting.md` | `changelog` (markdown) | "Prices as of 2026-09-27, after the June adjustment", a dated fact stamp in a paragraph | Genuine false positive: the `until\|as of\|before <year>` pattern is meant for comment lines dated against an edit, and in markdown it matched every paragraph. **Fixed**: in markdown it runs only on lines starting with `>`, `#` or `*`. Cases: a quote saying "Kept until 2027-01" denies; the fact stamp allows. |
| 2026-10-14 | `scripts/*.sh` | `run-cap` | Case carried over from the reference implementation and built in from the start: a new shell script whose three-line header sat under `#!/bin/bash`, counted as a four-line `#` run | Genuine false positive: a shebang is an interpreter directive, not prose. **Fixed**: a `#!` on line 1 is skipped. Cases: shebang plus three allows; shebang plus four denies. |
| 2026-10-14 | `scripts/*.py` | `run-cap` | Carried over and built in from the start: a PEP 723 inline-metadata header (`# /// script` ... `# ///`) that `uv run` reads | Genuine false positive: the block is machine-read TOML, not prose. **Fixed**: lines from a `# /// <type>` opener to its `# ///` closer are skipped. Cases: the header plus three comment lines allows; plus four denies. |
| 2026-10-14 | any | hook mode | Carried over and built in from the start: an `Edit` that deletes a block by anchoring on a neighbouring line, so an unchanged violating line sat in `new_string` | Genuine false positive: the line was carried over verbatim, not written. **Fixed**: only lines of `new_string` absent from `old_string` (or, for a Write, from the file on disk) are judged. A line the edit touches never matches verbatim, so inherited debt on a touched line is still caught. Cases: carried-over debt allows; a touched debt line denies. |
| 2026-10-14 | `~/.claude/projects/<project>/memory/MEMORY.md` | any | Carried over and built in from the start: adding an index line to Claude's auto-memory | Genuine false positive: the memory store is outside every repo and its format is dictated by the harness. **Fixed**: `$HOME/.claude/projects/*/memory/*` joins the scratch-path skip list. Case: a memory path allows changelog-shaped text; the same text in a repo markdown file denies. |
| 2026-10-14 | any file with a touched debt line | any | An `Edit` whose `new_string` modified a line that already violated a rule | Not a false positive. A block on inherited debt in a line you are editing is the gate working: fix the line you touch. Logged as the calibration case. |
| 2026-10-14 | `block-inplace-edits.sh` | redirect over an existing file | `cd /new/repo && printf x > .gitignore`, denied because the session's own repo had a `.gitignore` | Genuine false positive: a relative target was tested against the hook's cwd. **Fixed**: it resolves against the command's leading `cd`, else the event's `cwd`. Eight cases in `test/run.sh` (`run_inplace_cases`): new file after `cd`, relative `cd`, absolute target and `sed -i` in both directions. |
| 2026-10-14 | `block-inplace-edits.sh` | gate opener | A `git commit -m` whose message named the bulk-edit gate in prose | Genuine false positive: the word matched after any whitespace. **Fixed**: only command position (start, after `;&\|(`, or a `-c` script) counts; the gate file name still denies anywhere. Six cases: three openers and the gate file deny, a commit message and a grep allow. |
| 2026-10-14 | `rules/instructions.md` | `changelog` (markdown) | A rule banning narration that quoted the banned phrase, `no "we changed"` | Genuine false positive: a rule has to cite what it bans. **Fixed**: in markdown, backticked and double-quoted spans are removed before the changelog check. Two cases: the quoted phrase allows; narration beside a quoted word still denies. |
