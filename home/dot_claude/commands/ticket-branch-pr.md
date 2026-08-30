---
description: Create a Linear ticket (EXP by default), branch, commit the working changes, push, and open a PR — auto-generated from the diff. Runs on Haiku.
argument-hint: "[optional title/context hint] [team=EXP]"
model: claude-haiku-4-5-20251001
disable-model-invocation: true
allowed-tools: Bash(git status:*) Bash(git diff:*) Bash(git branch:*) Bash(git checkout:*) Bash(git add:*) Bash(git commit:*) Bash(git push:*) Bash(git symbolic-ref:*) Bash(git rev-parse:*) Bash(git log:*) Bash(gh pr create:*) Bash(gh repo view:*) mcp__claude_ai_Linear__save_issue mcp__claude_ai_Linear__get_issue mcp__claude_ai_Linear__list_teams
---

You take the current working-tree changes and ship them end to end: a Linear ticket, a
branch, a commit, a push, and a PR. The point is to save the human from doing five rote
steps by hand, so be decisive and don't stop to ask unless something is genuinely unsafe.

## Context

- Working tree status: !`git status --porcelain=v1`
- Staged changes (name + stat): !`git diff --cached --stat`
- Unstaged tracked changes (name + stat): !`git diff --stat`
- Full diff to summarize: !`git diff HEAD`
- Current branch: !`git rev-parse --abbrev-ref HEAD`
- Recent commit style to imitate: !`git log --no-merges -n 15 --pretty=format:%s`
- User hint / team override (may be empty): $ARGUMENTS

## Your task

Do these steps in order. Prefer running the git steps together once you've drafted the text.

1. **Pick the changes to ship (staged-first).** If there are staged changes, work with only
   those. Otherwise work with all dirty tracked changes. If the working tree is clean (no
   staged or unstaged tracked changes), stop and tell the user there's nothing to ship —
   don't create an empty ticket or PR.

2. **Resolve the team.** Look in `$ARGUMENTS` for a `team=XXX` token; if present, use `XXX`,
   otherwise default to `EXP`. Everything else in `$ARGUMENTS` is a free-text hint about the
   change — fold it into the ticket title/description but let the diff be the source of truth.

3. **Draft the ticket content from the diff.** Write a concise, Conventional-Commits-style
   title (e.g. `feat: ...`, `fix: ...`, `refactor: ...`) matching the recent commit style
   shown above, plus a short markdown description: a one-line summary followed by a bullet
   list of the concrete changes. This same title becomes the commit subject and PR title.

4. **Create the Linear ticket.** Call `mcp__claude_ai_Linear__save_issue` with
   `team` = the resolved team, `assignee` = `"me"`, and the drafted `title` and `description`.
   From the response, capture the `identifier` (e.g. `EXP-123`), the `url`, and the
   `gitBranchName` (Linear's suggested branch name — use it verbatim).

5. **Create the branch.** `git checkout -b <gitBranchName>`. Note: if the current branch (shown
   above) is already a non-default feature branch, mention it but proceed — the new branch is
   cut from wherever HEAD is.

6. **Stage and commit.** Stage the changes you selected in step 1 (`git add` the relevant paths,
   or `git add -u` for all tracked modifications), then commit with the drafted subject and a
   body containing the summary + bullets. End the commit message with:

   ```
   Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
   ```

7. **Push.** `git push -u origin <gitBranchName>`.

8. **Open the PR.** `gh pr create` with `--title` = the commit subject and `--body` containing a
   `## Summary`, a `## Changes` bullet list, and a final `Closes <identifier>` line, followed by:

   ```
   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   ```

   Do **not** pass `--base` — let `gh` target the repository's default branch.

9. **Report back** a short summary with the ticket identifier + URL, the branch name, the commit
   sha, and the PR URL.

## Guardrails

- Use only the git/gh tools listed in `allowed-tools`. Never force-push, never `git reset --hard`,
  never touch branches other than the one you create.
- If any step fails (e.g. Linear ticket creation errors, push rejected), stop and report the
  failure with the error output rather than pressing on — a half-finished PR is worse than a clear
  error.
- Opening a PR is outward-facing; only run this command when the user explicitly invokes it.
