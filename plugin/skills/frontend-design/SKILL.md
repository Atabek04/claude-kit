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

1. **Plan:** 4 to 6 named colours with hex values; one or two typefaces with roles and a type scale; a layout in one
   sentence plus an ASCII wireframe, with alignment; two or three principles for what makes this screen its own.
2. **Check against the brief:** for each part, would a similar brief have produced the same thing? If yes, revise it
   and say what changed. Brief the tone with references, never "modern" or "clean"; state what must not appear.
3. **Build:** read the real component and token files rather than paraphrasing them; keep spacing and radii at the
   values the system defines. Watch selector specificity where section and element classes meet.
4. **Critique:** screenshot when the environment allows, and remove the one thing that does not serve the brief.

## Principles

- **One bold move.** One memorable element; everything around it quiet.
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
