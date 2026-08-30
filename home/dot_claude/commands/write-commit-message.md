---
description: Generate a Conventional Commits message for the current changes (staged-first). Does not commit.
argument-hint: "[count=50]"
allowed-tools: Bash(git show-ref:*), Bash(git log:*), Bash(git diff:*), Bash(git status:*), Read
---

You are in a git repository. Generate a Conventional Commits message for the current changes. DO NOT commit.

Let COUNT be the first argument `$1` if provided and a positive integer, otherwise `50`.

1) Choose the remote default branch to learn style from:
   - If `git show-ref --verify --quiet refs/remotes/origin/main` succeeds, set BRANCH=origin/main
   - Else set BRANCH=origin/master

2) Read the last COUNT commits from BRANCH to infer conventions (types/scopes/wording):
   - Run: `git log --no-merges -n COUNT --pretty=format:%s%n%b%n---- ${BRANCH}`
     (substitute the numeric COUNT value)

3) Decide which files to base the message on (STAGED FIRST):
   - Get staged file list: `git diff --cached --name-only`
   - IF that list is non-empty:
       a) Use ONLY staged changes:
          - `git diff --cached`
          - (optionally) `git diff --cached --stat`
       b) The commit message must describe ONLY what is staged.
   - ELSE (no staged files):
       a) Use all dirty changes:
          - `git status --porcelain=v1`
          - `git diff`
          - For any untracked files listed by status, read their contents and include them in analysis.

4) Output rules:
   - Output ONLY the commit message text (no markdown, no extra commentary).
   - Conventional Commit format:
       - Header: `type(scope?): subject`
       - Subject: imperative mood, no trailing period, ideally <= 72 chars.
       - Body: explain what/why when helpful (wrap ~72 chars).
       - Footer: include `BREAKING CHANGE:` only if applicable.
   - Do NOT include ANY attribution or trailers such as:
       "Co-authored-by", "Generated-by", "Cursor", "Claude", "AI", etc.
   - Do NOT run `git commit`, do not edit files, do not stage/unstage anything.

Now run the commands above and print the final commit message.
