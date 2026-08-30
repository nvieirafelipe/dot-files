# Pull Request Workflows

These illustrate common patterns. Consider what fits your context.

## Fork-based workflow

```bash
# Fork upstream repo
tea repos fork owner/repo

# Clone your fork
tea clone your-user/repo

# Create feature branch, make changes, push to fork
git checkout -b feature-branch
# ... make changes ...
git push origin feature-branch

# Create PR against upstream
tea pulls create --base main --head your-user:feature-branch --title "Add feature"
```

## AGit push-to-create

Create PRs without forking, using Gitea's AGit feature:

```bash
tea pulls create --agit
```

This pushes via refspecs directly to the upstream repo.

## PR review flow

```bash
# Check out PR locally for testing
tea pulls checkout 42
# Optionally specify local branch name
tea pulls checkout 42 --branch pr-42-review

# After testing, approve or request changes
tea pulls approve 42
tea pulls reject 42

# Interactive review
tea pulls review 42
```

## Merging

```bash
# Merge styles
tea pulls merge 42 --style merge        # merge commit
tea pulls merge 42 --style rebase       # rebase
tea pulls merge 42 --style squash       # squash
tea pulls merge 42 --style rebase-merge # rebase then merge commit

# Clean up local and remote branches after merge
tea pulls clean 42
```

## Listing and filtering

```bash
tea pulls ls
tea pulls ls --state open
tea pulls ls --state closed
tea pulls ls --fields index,title,author,state
tea pulls ls --output json
```

## Comments on PRs

```bash
tea comment 42 --body "Looks good, just one suggestion..."
```
