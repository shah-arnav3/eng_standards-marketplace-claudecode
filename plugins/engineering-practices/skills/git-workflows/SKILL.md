---
name: git-workflows
description: Modern git workflows and procedures — trunk-based development vs. Git Flow, commit hygiene and conventional commits, branching strategy, pull request practices, rebasing vs. merging, and resolving conflicts safely. Use whenever working with git branches, commits, pull requests, merge conflicts, or the user mentions git workflow, commit messages, or repository strategy.
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
