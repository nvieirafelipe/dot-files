# Repository state

No commit linter, commit template, or contributing notes exist in the repository.

## `git log --no-merges -10 --format=%s`

```text
Start the review comment editor beside its draft
Open the line under the review cursor in nvim with E
Draw the review diff again once a drag of the list stops
Give the review diff 140 columns before the list grows
Offer the other local branches in the review picker
Review a branch against the local trunk it was cut from
Add the using-playbill skill
Load work-only Claude settings from an untracked file
Add the codeberg-workflow skill
Keep a review working on tmux 3.8
```

## `git status --short`

```text
M  tmux/review.sh
```

## `git diff --cached`

```diff
diff --git a/tmux/review.sh b/tmux/review.sh
@@ -40,6 +40,9 @@ bind_review_keys() {
   tmux bind-key -T review j send-keys -X cursor-down
   tmux bind-key -T review k send-keys -X cursor-up
+  # Jump between files without scrolling through every hunk.
+  tmux bind-key -T review ] run-shell "$REVIEW_DIR/jump.sh next-file"
+  tmux bind-key -T review [ run-shell "$REVIEW_DIR/jump.sh prev-file"
 }
```
