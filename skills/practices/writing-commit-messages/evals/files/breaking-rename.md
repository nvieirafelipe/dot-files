# Repository state

## `commitlint.config.js`

```js
module.exports = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "header-max-length": [2, "always", 60],
    "scope-enum": [2, "always", ["config", "api", "worker"]],
  },
};
```

## `git log --no-merges -5 --format=%s`

```text
feat(api): return order status in responses
fix(worker): retry failed webhook deliveries once
refactor(config): read settings in one place
docs: describe local setup
test(api): cover missing order ids
```

## `git status --short`

```text
M  lib/app/config.ex
M  README.md
```

## `git diff --cached`

```diff
diff --git a/lib/app/config.ex b/lib/app/config.ex
@@ -10,7 +10,7 @@ defmodule App.Config do
   def database_url do
-    System.fetch_env!("DB_URL")
+    System.fetch_env!("DATABASE_URL")
   end
diff --git a/README.md b/README.md
@@ -22,7 +22,7 @@
-Set `DB_URL` to the Postgres connection string.
+Set `DATABASE_URL` to the Postgres connection string.
```

## Context

Deployments set `DB_URL` today. The rename matches the variable name that the hosting
platform injects.
