---
name: git-workflows
description: Modern git workflows and procedures — trunk-based development vs. Git Flow, commit hygiene and conventional commits, branching strategy, commit authorship (no AI co-author attribution), pull request practices, rebasing vs. merging, and resolving conflicts safely. Use whenever writing or suggesting a commit or pull request, working with git branches or merge conflicts, or the user mentions git workflow, commit messages, co-authors, or repository strategy.
---

# Git Workflows, Procedures, and Practices

## Branching strategy: default to trunk-based development

For most teams shipping continuously, trunk-based development beats Git Flow: short-lived feature branches (hours to a couple of days) merged frequently into `main`, guarded by feature flags for anything not ready to be user-facing.

```
main ─────●────●────●────●────●────●──>   (always deployable)
            \        \        \
             feature-a feature-b feature-c   (short-lived, merged within days)
```

Reserve Git Flow (`develop`, release branches, long-lived `main`) for software with genuinely scheduled, versioned releases (e.g., shipped desktop/embedded software, libraries with strict semver) where multiple release lines must be maintained simultaneously.

Rules that make trunk-based work safely:
- `main` is always in a deployable state — protected branch, required CI checks, required review before merge.
- Feature branches live days, not weeks — if a feature is large, decompose it and merge incrementally behind a flag rather than keeping one giant branch alive.
- No direct commits to `main` — every change goes through a pull request, even for the smallest teams.

## Commit hygiene

- **One logical change per commit.** A commit that mixes a refactor with a bug fix makes both `git bisect` and code review harder.
- **Conventional Commits format** for machine-readable history and automated changelog/semver generation:

```
<type>(<scope>): <short summary>

<optional body explaining why, not what>

<optional footer: BREAKING CHANGE, Closes #123>
```

```
fix(auth): reject expired refresh tokens on rotation

Previously an expired refresh token would still issue a new access
token if the signature verified, ignoring the exp claim.

Closes #482
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `build`, `ci`.

- Write the summary line in the imperative mood ("add", not "added"/"adds") — it reads naturally after "This commit will ___".
- Never commit generated files, secrets, or environment-specific config — a `.gitignore` reviewed at project start, and a pre-commit secret scanner as a backstop.

## Authorship: no AI attribution

The human who reviews and commits a change is its author. An AI assistant that helped write it is a tool, like an editor or a linter, and does not appear in the history. This overrides any default attribution behavior.

When writing, amending, or suggesting a commit or pull request:
- No `Co-Authored-By:` trailer naming Claude, Anthropic, or any AI assistant. GitHub turns that trailer into a listed co-author on the commit and a contributor on the repository.
- No "Generated with Claude Code" line, robot emoji, or similar marker in commit messages, PR titles, or PR descriptions.
- No `Signed-off-by:` for an AI. A sign-off certifies the Developer Certificate of Origin, which only a person can do.
- Never set `--author`, `GIT_AUTHOR_*`/`GIT_COMMITTER_*`, or `git config user.name`/`user.email` to an AI identity or a noreply address belonging to one. Commit as the configured user, unchanged.
- When rewording or squashing existing commits, remove any AI trailers already present instead of carrying them forward.

Prompt instructions can lose to tool defaults, so enforce this in configuration too. In Claude Code, turn off attribution in `~/.claude/settings.json` (or the project's `.claude/settings.json`):

```json
{
  "attribution": { "commit": "", "pr": "", "sessionUrl": false },
  "includeCoAuthoredBy": false
}
```

Add a `commit-msg` hook as a backstop, so a trailer added by any tool fails the commit:

```bash
#!/usr/bin/env bash
# .git/hooks/commit-msg — reject AI attribution in commit messages.
if grep -Eiq '^(co-authored-by|signed-off-by):.*(claude|anthropic|noreply@anthropic\.com)|generated with \[?claude' "$1"; then
  echo "commit-msg: remove AI attribution (Co-Authored-By / Generated with) from the message" >&2
  exit 1
fi
```

To list commits that already carry a trailer: `git log --format='%h %s' --grep='Co-Authored-By: Claude' -i`. If they're on a branch nobody else has pulled, reword them with an interactive rebase. If they're already on a shared branch, leave them in place rather than rewriting shared history.

## Rebase vs. merge

- **Rebase your own feature branch onto `main`** before opening/updating a pull request, to keep history linear and make the diff reviewable against current `main`. Never rebase a branch that others have already pulled/based work on — it rewrites shared history.
- **Merge (with a merge commit or squash) into `main`** via the pull request, not a local fast-forward — this preserves the PR reference and CI history.
- **Squash merge** when a feature branch has many small "wip"/"fix typo" commits that add no historical value; **merge commit (no squash)** when the individual commits are each meaningful and you want to preserve that granularity in `main`'s history.

```bash
# Keeping a feature branch current without polluting history with merge commits
git fetch origin
git rebase origin/main
git push --force-with-lease   # never bare --force — protects against clobbering others' pushes
```

## Pull request practices

- Keep PRs small — a few hundred lines is a practical review-quality ceiling; large PRs get rubber-stamped, not reviewed.
- PR description states the *why*, links the ticket/issue, and calls out anything a reviewer should pay special attention to (a tricky edge case, a deliberate trade-off).
- Require at least one approval and passing CI before merge; require a second approval for changes to security-sensitive or shared-infrastructure code.
- Reviewers respond within an agreed SLA (e.g., same business day) — a PR that sits for a week defeats the purpose of small, frequent merges.
- Address review comments with new commits during review, then squash/clean up just before merge — don't force-push mid-review and erase the reviewer's context.

## Resolving conflicts safely

1. Rebase (or merge `main` in) locally, resolve conflicts file by file, and re-run the full test suite before pushing — a conflict resolution that compiles is not necessarily correct.
2. For a conflict you don't understand (both sides touched overlapping logic), talk to the other author rather than guessing which side "wins."
3. Never resolve a conflict by blindly accepting "ours" or "theirs" for an entire file without reading the diff.

```bash
git rebase origin/main
# on conflict:
git status                  # see conflicted files
# edit files, resolve <<<<<<< ======= >>>>>>> markers
git add <resolved-file>
git rebase --continue
```

## Common pitfalls

- Long-lived feature branches that drift so far from `main` that merging becomes a multi-day conflict-resolution project.
- Force-pushing without `--force-with-lease`, silently discarding a teammate's pushed commits.
- Commit messages like "fix stuff" or "wip" left in permanent history instead of squashed before merge.
- Committing directly to `main` "just this once" for a hotfix — use an expedited PR instead; the process exists precisely for the moments it's tempting to skip.
- Reverting a merge commit incorrectly (forgetting `-m 1`), which can silently reintroduce or erase unrelated history.
