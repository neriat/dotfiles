---
description: Cursor-style Plan mode — research and produce an implementation plan in docs/plans/.
argument-hint: "<slug> [task description]"
disable-model-invocation: true
allowed-tools: Read Grep Glob Write(docs/plans/*) Edit(docs/plans/*) Bash(git log:*) Bash(git diff:*) Bash(git status:*) Bash(git show:*) Bash(ls:*) Bash(mkdir -p docs/plans) Bash(rg:*) Bash(rtk:*)
---

You are operating in Cursor-style **Plan mode**: research-only with a single allowed write — produce an implementation plan at `docs/plans/<slug>.md`.

## Argument shape

- `$1` is a kebab-case slug for the plan filename. Required.
- The remainder of `$ARGUMENTS` is the task description.
- If `$1` is missing or does not match `^[a-z0-9][a-z0-9-]*$`, STOP and ask the user for a valid slug. Do not infer one.

## Hard rules (non-negotiable)

- The ONLY write allowed is creating or updating `docs/plans/$1.md`. Any other file write/edit/delete is forbidden.
- DO NOT run mutating shell: no commits, branch ops, package installs, builds, tests, formatters.
- DO NOT call MCP tools that mutate state.
- DO NOT begin implementation. This mode ends with a written plan.

## Workflow

1. Research the codebase using Read, Grep, Glob, and read-only shell. Prefer `rtk` proxies (`rtk read`, `rtk grep`, `rtk tree`, `rtk git log`, `rtk git diff`) to keep context compact.
2. If the task scope is ambiguous or there are multiple valid implementations with meaningful trade-offs, ask 1-2 clarifying questions before writing. Do not guess.
3. Run `mkdir -p docs/plans` if needed, then write `docs/plans/$1.md` with the structure below.
4. Print the file path written and a 5-line summary of the plan to chat.

## Plan file structure (`docs/plans/$1.md`)

- `# <Title>` (H1, derived from the task, not the slug)
- `## Goal` — one-paragraph statement of intent.
- `## Context` — relevant existing code with `path:line` citations and at most 2-3 short snippets.
- `## Design` — the chosen approach, with a brief rationale and any rejected alternatives.
- `## Steps` — ordered, actionable todos a developer (or agent) can execute.
- `## Risks / open questions` — known unknowns, follow-ups, or things to validate.

Constraints on the plan content:
- No emojis.
- No markdown tables — use bullets.
- Keep snippets short; cite `path:line` instead of pasting large blocks.
- Match the style of existing plans in `docs/plans/` (e.g. `docs/plans/fix-converter-eoa-vs-contract.md`).

## Task

$ARGUMENTS
