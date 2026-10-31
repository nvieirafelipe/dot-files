# Repository state

No commit linter configuration exists in the repository.

## `git log --no-merges -10 --format=%s`

```text
feat(search): rank results by recency
fix(auth): refresh tokens before they expire
docs(readme): document the cache settings
refactor(cache): extract key building
test(search): cover empty queries
feat(cache): expire entries after one hour
fix(search): ignore trailing whitespace in queries
ci: run tests on pull requests
build(deps): bump jason to 1.4.4
chore: remove unused scripts
```

## `git status --short`

```text
M  lib/app/cache/key.ex
M  test/app/cache/key_test.exs
 M lib/app/search/ranker.ex
```

## `git diff --cached`

```diff
diff --git a/lib/app/cache/key.ex b/lib/app/cache/key.ex
@@ -4,6 +4,6 @@ defmodule App.Cache.Key do
   @spec build(String.t(), map()) :: String.t()
   def build(path, params) do
-    "#{path}?#{URI.encode_query(Map.delete(params, :locale))}"
+    "#{path}?#{URI.encode_query(params)}"
   end
 end
diff --git a/test/app/cache/key_test.exs b/test/app/cache/key_test.exs
@@ -8,4 +8,9 @@ defmodule App.Cache.KeyTest do
+  test "keys differ by locale" do
+    refute Subject.build("/articles", %{locale: "fr"}) ==
+             Subject.build("/articles", %{locale: "en"})
+  end
```

## `git diff`

```diff
diff --git a/lib/app/search/ranker.ex b/lib/app/search/ranker.ex
@@ -12,3 +12,3 @@ defmodule App.Search.Ranker do
-  @recency_weight 0.3
+  @recency_weight 0.5
```

## Context from the issue tracker

Users reported seeing article pages in French after switching the site to English.
