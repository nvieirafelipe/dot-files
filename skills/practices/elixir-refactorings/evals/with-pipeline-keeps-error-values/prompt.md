---
tags: [skill-creator]
max_turns: 60
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

update_game_state/3 in lib/game.ex has a case inside an if inside a case and it's getting
hard to follow. Refactor it so the happy path reads top to bottom. Don't change what it
returns. Tell me which refactoring you applied and give me a commit message for it.

Input files: lib/game.ex
