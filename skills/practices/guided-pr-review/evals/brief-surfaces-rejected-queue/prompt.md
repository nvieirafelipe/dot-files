---
tags: [skill-creator]
max_turns: 150
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash, Agent]
---

Do a guided review of my branch retry-deliveries against main before I open the PR. The
discussion behind it is in notes/issue-140.md, and notes/pr-description.md is the PR
description I plan to use. There is no other discussion. Full mode. Don't run the code or
the tests, just read it. Put the report in review-out/.

Input files: the git repository in the working directory, notes/issue-140.md,
notes/pr-description.md
