---
name: frontend-design
description: "Visual direction for new or reshaped UI: a brief-specific palette, type, layout and copy instead of templated defaults, planned, checked against the brief, then built and critiqued. Use for \"/kit:frontend-design\", \"design this page\", \"make it look good\", \"redesign the landing page\", or a new screen built from a brief. Not for bug fixes, logic, or work that only follows an existing design system."
argument-hint: "<brief or screen>"
---

# Frontend design

Generated UI drifts to the median of its training data. Every visual choice here is made for this brief, or it is a
default and gets replaced.

## Constraints first

Read the project's `.claude/rules/frontend.md`, else its design-system doc. Its tokens, theme and limits (text
direction, touch targets, device tier, accessibility level) are mandatory and beat everything below. A brief that
names a look gets that look, even one listed as a default.

## Ground it in the subject

Name the product, its audience and the screen's one job before designing; if the brief does not, propose them and
confirm. Distinctive choices come from the subject's own world (its materials, vocabulary, artefacts), and the build
uses real content from it, never lorem ipsum or invented metrics.
- **Jobs before data.** List the 2 or 3 things the user opens the screen to do; every element serves one. A job the
  data cannot serve yet is raised as a gap, never dropped in silence. No raw code, enum, slug or id reaches the
  screen: a part-of-speech tag or a source key gets the words a user would use.

## Defaults to avoid where the brief leaves a choice open

- Palettes: warm cream with a serif display and a clay accent; near-black with one neon accent; tinted near-black
  standing in for black.
- Layout: identical rounded cards with one radius and one soft shadow everywhere; broadsheet hairline columns;
  numbered markers on content that is not a sequence; stat tiles nobody reads.
- Type: one accented word in a headline; all-caps eyebrow labels over every heading; a mono face for small labels;
  meta strings joined with middle dots; an arrow appended to every link.
- Effects: glass and glow, gradient washes as decoration, a coloured left border as the only accent, a fade-up
  entrance on every section.

## Plan, check, build

1. **References:** 3 to 6 real product screens doing the same job, at the target viewport. They set the bar for
   layout, density and hierarchy; the project's tokens still own colour and type.
2. **Plan:** 4 to 6 named colours with hex values; one or two typefaces with roles and a type scale; a layout in one
   sentence plus an ASCII wireframe, with alignment; two or three principles for what makes this screen its own.
3. **Check against the brief:** for each part, would a similar brief have produced the same thing? If yes, revise it
   and say what changed. Brief the tone with references, never "modern" or "clean"; state what must not appear.
4. **Build:** read the real component and token files rather than paraphrasing them; keep spacing and radii at the
   values the system defines. Watch selector specificity where section and element classes meet.
5. **Critique:** screenshot at the references' viewport. A fresh-context subagent gets only the reference and build
   images side by side plus the ban list, never the code or your opinion, and names the three biggest gaps; fix them.
   The builder's own verdict never closes this step: with no screenshot or subagent, report the critique as not run.
   Unreachable reference sites are no exemption: use the project's shipped screens, or name the apps and describe
   their screens in the critic's brief. A build that skipped the critic is not shown as a pick, nor built on.
   The owner's verdict outranks both: when they judge the work worse than you or the critic did, that gap is your
   bias, so recheck everything already called done at their bar, not only the part they named.

## Showing the owner a choice

A preview asks for a decision, never hands the design back. Show 2 to 4 **named directions**, each a whole working
screen built from real content, each with the one line of why it exists, and mark the one you would ship with what
it beats. Directions differ in what the screen is (what the header carries, which surface owns a fact, how many
tabs), never in a value.
- **No knob the designer should have turned:** padding, type size, page width, radius, border style, density. A
  control earns its place only when it switches a real state the design must survive — a role, an empty list, an
  inherited value, a long name.
- The owner may answer across directions ("A's header, B's footnote"); take that as the pick and build it.

## Principles

- **One bold move.** One memorable element; everything around it quiet.
- **Surfaces share one temperature.** Page, card and sheet are steps on one hue's lightness ladder (OKLCH: hue within
  10°, chroma within 0.02, lightness 3 to 6 points apart); never a pure `#fff` card on a tinted page, never a neutral
  grey beside a warm tint. Compute each surface pair's hue and lightness; the eye forgives what the screen does not.
- **Typography carries the voice.** At most two families, clearly distinct; body lines under about 80 characters,
  serif body a little looser in line-height.
- **Structure is information.** Borders, numbering, dividers and labels encode something about the content or go.
- **Motion has a reason.** One orchestrated moment at most; motion that answers a user action shows what changed.
- **Quality floor, unannounced.** Responsive to mobile, visible keyboard focus, reduced motion respected, accessible
  contrast.

## Copy

Words are interface. Name things the way users think of them, not the way the system is built; buttons say what
happens ("Save changes") and the result echoes it ("Saved"); errors say what went wrong and how to fix it, without
apology; an empty state invites the next action. Sentence case, active voice, no filler.

**Nothing the screen already says.** Every string earns its place by carrying what the user cannot see: a reason, a
consequence, a value, a number. Cut the rest, and let the interface itself carry it.
- A caption for an absent control ("Read-only", "You cannot change this") tells a user who sees no control what they
  already know. Show the control to whoever has it and nothing to everyone else.
- A label that repeats its heading, its icon or the obvious action of its own button is noise; an icon with a tooltip
  or `aria-label` replaces a repeated text button in a row or column of them.
- A line that restates what the row, chip or value beneath it already states goes, even when it reads as helpful.
