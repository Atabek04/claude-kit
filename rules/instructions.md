---
paths:
  - "**/CLAUDE.md"
  - "**/CLAUDE.local.md"
  - "**/AGENTS.md"
  - "**/.claude/**/*.md"
  - "**/SKILL.md"
  - "**/claude-kit/rules/**"
  - "**/claude-kit/README.md"
---

# Writing instructions (CLAUDE.md, rules, skills, agents, briefs)

Loaded instructions cost attention on every turn, and models get less accurate as context grows, even on simple
tasks (Chroma, "Context rot", 2025). Write the smallest set of lines that changes behaviour.

- **Each line prevents a mistake.** Ask "would removing this cause an error?"; if not, cut it.
- **Principles and pointers, never tutorials.** The model knows languages, frameworks and conventions: name the choice
  ("Conventional Commits", "Kotlin coding conventions") and the exceptions, not the content.
- **Put it where it loads only when needed:**
  - true for every project and turn: the kit `CLAUDE.md`, under 100 lines;
  - true for one stack or topic: `rules/<topic>.md` with `paths:` globs;
  - a procedure: a skill (only its description is always loaded; `SKILL.md` under 500 lines);
  - checkable by a script: a hook, linter or CI gate, with one line of prose naming it;
  - true for one project: that project's `CLAUDE.md`, under 200 lines, or its `.claude/rules/`.
- **One owner per fact.** Every other file points to it; a copied rule drifts silently.
- **Concrete and checkable:** numbers, names, paths, commands. "Be careful" is not a rule.
- **State the rule as it is now.** No history, no "we changed", at most one example per rule.
- A doc is precise and short or absent; never pad.

Sources: Anthropic, Claude Code best practices (code.claude.com/docs/en/best-practices); Anthropic, "Effective context
engineering for AI agents"; Chroma, "Context rot" (trychroma.com/research/context-rot).
