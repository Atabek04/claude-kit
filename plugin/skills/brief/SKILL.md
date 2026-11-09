---
name: brief
description: "Writes a prompt for another model run that starts with no context: a new-session handoff or a subagent brief. Use for \"/kit:brief\", \"write a prompt for a new session\", \"handoff\", \"continue this in a fresh session\", \"brief an agent\", before every Agent tool call, and whenever a skill asks for a fresh-session prompt. The only owner of prompt and brief rules; chat messages for people follow the device rules instead."
argument-hint: "<handoff | subagent> <task>"
---

# Prompts for a fresh context

The reader is a capable engineer who has read nothing of this conversation. Everything it needs is in the prompt or
behind a path in it; everything else costs its attention. Anthropic prompting guidance: be clear and direct, give the
why, separate parts with XML tags, state the output (docs.claude.com, "Prompt engineering overview").

## Rules

- **English**, even when the user and the domain speak another language. Domain terms, UI copy, error codes and
  names stay in their original form, in backticks.
- **Facts, not memory.** Every fact was checked in this session (command, file, ticket) and carries its source:
  path, `file:line`, branch, commit, ticket link, who decided and when. What was not checked is labelled
  `assumption:`. Absolute dates, never "today" or "yesterday".
- **Point, never paste:** specs, docs, rules and CLAUDE.md files go by path. The new session loads its own
  CLAUDE.md files, so never restate their rules; carry only what is specific to this task.
- **Say what to do and why:** positive instructions, one reason for each constraint that is not obvious. No emphasis
  words; the order and the stop point carry the priority.
- **Every line prevents a re-derivation or a mistake.** No recap of the conversation, no history of dead ends unless
  it stops a repeat (one line: what failed and why).
- **No real citizen data:** no IINs, names, phones, booking or application ids from prod; test values only.

## Shape

Sections in this order, each in its XML tag, omitted only when empty:

```text
<task>One sentence: the goal and why it matters. Ticket link.</task>

<context>
Established facts with sources: repos and paths, branches and their state (pushed or not, ahead of what),
decisions (who, date), environments and what is deployed where.
</context>

<done>What is finished and where it lives.</done>

<remaining>
1. Ordered steps, each with its observable done condition.
</remaining>

<constraints>
Files and repos it may touch, those it must not; actions that need the user's OK first (deploys, tickets, MRs,
contract changes); the checks it runs.
</constraints>

<open_questions>Each with who answers it and where the answer will appear.</open_questions>

<first_step>
What to do first, and where to stop and report before continuing.
</first_step>

<output>Shape and length of the report: fixed sections, a cap, file:line refs, "not found" over guessing.</output>
```

## Delivery

- **Handoff for a new session:** one fenced ```` ```text ```` block in chat, nothing else inside, so it survives a
  paste. Markdown inside the tags is fine; the block is the only fence. One line above it says where to paste it.
- **Subagent:** the same tags as the Agent tool's prompt, plus the model choice and limits from the kit
  `CLAUDE.md` § Subagents. Read-only unless the task is a write task.

Before sending, reread it as the receiver: could it start without asking anything? Remove every line it would not miss.
