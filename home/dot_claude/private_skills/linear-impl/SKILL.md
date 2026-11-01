---
name: linear-impl
description: Turn a prompt (or the plan made in this conversation) into shipped work — create a Linear ticket (team EXP by default, assigned to me), cut a git worktree on branch `cursor/EXP-<n>-<slug>` from origin/dev|main|master, implement the ticket, commit, push, and open a draft PR. Use when the user invokes /linear-impl.
argument-hint: "<task title/description> [team=EXP] [repo=<path>]"
disable-model-invocation: true
---

You take a task from idea to draft PR: a Linear ticket, an isolated worktree + branch, the
implementation, a commit, a push, and a PR. The human invoked this explicitly to skip the rote
steps, so be decisive — only stop to ask when something is genuinely ambiguous or unsafe.

Arguments: $ARGUMENTS

## 1. Parse the arguments

- `team=XXX` → Linear team key (default `EXP`).
- `repo=<path>` → repository to work in (default: the current repo, `git rev-parse --show-toplevel`).
  Expand `~` and resolve to the repo's top level.
- Everything else is the **task text**.

If there's no task text and no plan in the conversation, ask what to build — there's nothing to
ticket.

## 2. Decide the ticket content

- **Description**: if a plan was produced in this conversation (plan mode, or a plan file under
  `~/.claude/plans/` written this session), use the plan verbatim — it's the spec the user already
  approved. Otherwise use the full task text as written (light cleanup is fine; don't invent scope).
- **Title**: a concise, human-readable version of the task text (no Conventional-Commits prefix —
  this is a ticket, not a commit). If the task text is empty, use the plan's H1.

If you are still in plan mode when invoked, finish the plan and call ExitPlanMode first. Creating
tickets, worktrees and PRs are side effects that must wait for the plan's approval; the approved
plan then becomes the description.

## 3. Create the Linear ticket

Call `mcp__claude_ai_Linear__save_issue` with `team`, `assignee: "me"`, `title`, `description`.
Capture the `identifier` (e.g. `EXP-123`) and `url`.

If this fails, stop and report the error before touching git — a ticket-less branch breaks the
naming convention and leaves junk behind.

## 4. Create the worktree and branch

1. **Branch name**: `cursor/<IDENTIFIER>-<slug>` — the identifier keeps its case, the slug is the
   title in lowercase kebab-case, ASCII only, ≤ ~40 chars, trimmed at a word boundary.
   Example: `cursor/EXP-123-add-retry-to-price-fetcher`.
2. **Base branch**: `git -C <repo> fetch origin`, then pick the first that exists:
   `origin/dev` → `origin/main` → `origin/master`
   (check each with `git -C <repo> show-ref --verify --quiet refs/remotes/origin/<b>`).
   If none exist, stop and report. Remember the choice as `<base>` — the PR targets it too.
3. **Ignore the worktree dir** so it never shows up as untracked in the main checkout:
   if `git -C <repo> check-ignore -q .claude/worktrees/x` fails, append `.claude/worktrees/` to
   `<repo>/.git/info/exclude` (local-only; never edit the committed `.gitignore` for this).
4. **Create it**:
   `git -C <repo> worktree add <repo>/.claude/worktrees/<IDENTIFIER>-<slug> -b <branch> origin/<base>`
   Create it manually rather than with `EnterWorktree(name=…)` — that tool picks its own branch
   name, and the `cursor/EXP-…` convention matters (Linear links branches to tickets by it).
5. **Switch in**: call `EnterWorktree` with `path=<that worktree path>` (load it via ToolSearch if
   it's deferred). If it refuses — e.g. `repo=` points outside the launch directory — carry on
   using absolute paths and `git -C <worktree>`, and mention that in the final report.

From here on, every edit and command happens inside the worktree, never the main checkout.

## 5. Implement

- Read the repo's `CLAUDE.md` / `AGENTS.md` / README and look at neighbouring code so the change
  matches local conventions.
- Implement what the ticket (plan) describes — no more. Unrelated cleanups make the PR harder to
  review.
- Install deps if needed and run the relevant tests / lint / typecheck / build. Fix what you broke.
- If something can't be resolved after a reasonable effort (missing creds, flaky infra, an
  ambiguous requirement), don't spin: commit what you have and call it out clearly in the PR's
  Testing section. A draft PR with an honest note beats an endless loop.

## 6. Commit

- Subject: Conventional Commits (`feat:`, `fix:`, `refactor:` …), imitating the style in
  `git log --no-merges -n 15 --pretty=format:%s origin/<base>`, ≤ 72 chars.
- Body: one-line summary, a bullet list of concrete changes, then `Refs <IDENTIFIER>`.
- End with the Co-Authored-By trailer from the session's attribution instructions (if there are
  none, use `Co-Authored-By: Claude <noreply@anthropic.com>`).
- Stage only files you intentionally changed — check `git status` for stray artifacts first.

## 7. Push and open a draft PR

```bash
git push -u origin <branch>
gh pr create --draft --base <base> --title "<commit subject>" --body "<body>"
```

PR body:

```
## Summary
<1–3 sentences>

## Changes
- …

## Testing
- <what you ran and the result; anything not verified>

Linear: <ticket url>
Closes <IDENTIFIER>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

Draft, because the implementation was autonomous — the user flips it to ready after a look.
If the repo has a PR template (`.github/pull_request_template.md`), fill its sections instead,
keeping the Linear/Closes lines and footer.

## 8. Report back

A short summary: ticket id + URL, branch, worktree path, base branch, commit sha, PR URL, and test
status (passed / failed / not run, with one line on why). Stay in the worktree so the user can keep
iterating there.

## Guardrails

- Never force-push, `reset --hard`, or touch branches other than the one you created — the main
  checkout may hold the user's uncommitted work.
- If push or PR creation fails, report the exact error and leave the worktree and commit in place
  so the user can recover; don't delete anything.
- Don't create a second ticket on retry — if a ticket was already created earlier in this
  conversation for the same task, reuse it.
