---
name: screenshot
description: Loads the user's most recent screenshot. Use when the user says they took a screenshot, asks to check a screenshot, or references a screen capture.
---

STARTER_CHARACTER = 📸

## Instructions

1. List the screenshot directory sorted by most recent first:
   ```bash
   ls -t ~/Pictures/screenshots/ | head -5
   ```

2. Read the most recent file using its full path:
   ```
   ~/Pictures/screenshots/<filename>
   ```

3. Describe what you see and ask the user what they need help with.

If the user asks for a specific screenshot (e.g. "the one before that", "the second one"), use the sorted listing to pick the right file.

## Screenshot directory

`~/Pictures/screenshots/`

## Anti-patterns

- Do not assume what the user wants done with the screenshot — ask
- Do not skip reading the image and ask the user to describe it instead
