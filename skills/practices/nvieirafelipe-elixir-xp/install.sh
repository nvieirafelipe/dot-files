#!/usr/bin/env bash
# Install nvieirafelipe-elixir-xp into ~/.claude/skills/, then offer to install missing companion skills.
#
# Usage:
#   bash install.sh                 # symlink + interactive companion install
#   bash install.sh --copy          # copy instead of symlink (loses live edits)
#   bash install.sh --no-companions # skip companion check
#   bash install.sh --yes           # non-interactive: install all missing companions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="nvieirafelipe-elixir-xp"
SKILLS_HOME="$HOME/.claude/skills"
TARGET="$SKILLS_HOME/$SKILL_NAME"

mode="symlink"
check_companions=1
auto_yes=0

for arg in "$@"; do
  case "$arg" in
    --copy) mode="copy" ;;
    --no-companions) check_companions=0 ;;
    --yes|-y) auto_yes=1 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

mkdir -p "$SKILLS_HOME"

# Install the skill itself.
if [[ -e "$TARGET" || -L "$TARGET" ]]; then
  if [[ "$auto_yes" -eq 1 ]]; then
    rm -rf "$TARGET"
  else
    echo "$SKILL_NAME: $TARGET already exists. Replace? (y/N)"
    read -r reply
    if [[ ! "$reply" =~ ^[Yy]$ ]]; then
      echo "aborted."
      exit 0
    fi
    rm -rf "$TARGET"
  fi
fi

if [[ "$mode" == "symlink" ]]; then
  ln -s "$SCRIPT_DIR" "$TARGET"
  echo "$SKILL_NAME: symlinked $SCRIPT_DIR -> $TARGET"
else
  cp -R "$SCRIPT_DIR" "$TARGET"
  echo "$SKILL_NAME: copied $SCRIPT_DIR -> $TARGET"
fi

# Companion skills check.
if [[ "$check_companions" -eq 1 ]]; then
  factory_root="$(cd "$SCRIPT_DIR/../../.." && pwd)"
  companions_dir_in_factory="$factory_root/output_skills"

  # name|relative-path-under-output_skills
  companions=(
    "xp|practices/xp"
    "elixir-crafting|practices/elixir-crafting"
    "tdd|testing/tdd"
    "refactoring|practices/refactoring"
  )

  echo
  echo "Checking companion skills under $SKILLS_HOME ..."

  missing=()
  for entry in "${companions[@]}"; do
    name="${entry%%|*}"
    path="${entry#*|}"
    if [[ ! -e "$SKILLS_HOME/$name" ]]; then
      missing+=("$name|$path")
    else
      echo "  ✓ $name (already installed)"
    fi
  done

  if [[ "${#missing[@]}" -eq 0 ]]; then
    echo "All companion skills present."
  else
    echo
    echo "Missing companion skills:"
    for entry in "${missing[@]}"; do
      name="${entry%%|*}"
      echo "  - $name"
    done

    for entry in "${missing[@]}"; do
      name="${entry%%|*}"
      path="${entry#*|}"
      source="$companions_dir_in_factory/$path"
      if [[ ! -d "$source" ]]; then
        echo "  $name: source not found at $source — skipping. Install manually."
        continue
      fi

      install_it=0
      if [[ "$auto_yes" -eq 1 ]]; then
        install_it=1
      else
        echo "Install $name from $source? (y/N)"
        read -r reply
        [[ "$reply" =~ ^[Yy]$ ]] && install_it=1
      fi

      if [[ "$install_it" -eq 1 ]]; then
        ln -s "$source" "$SKILLS_HOME/$name"
        echo "  symlinked $name"
      fi
    done
  fi
fi

echo
echo "Done. Restart Claude Code to load the skill."
