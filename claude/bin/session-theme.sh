#!/usr/bin/env bash
set -euo pipefail

# Installs one Claude Code theme per accent colour, so a session can be given a
# colour without anything being computed at launch.
#
# Claude Code reads its theme from the layered settings, and every session in a
# directory reads the same files -- so the colour cannot be chosen there without
# sessions fighting over it. `claude --settings '<json>'` takes settings inline
# instead, which is per invocation and touches no file at all. The shell wrapper
# in zsh/prezto/.functions passes one of these slugs that way; all this has to
# do is make sure the themes exist, which is a one-off.
#
# The colours are Tokyo Night Storm's accents, the same palette the tmux status
# bar and delta already use, so a prompt border never clashes with what is
# around it.
#
# usage: session-theme.sh [--list]

themes=$HOME/.claude/themes

# name=hex, in the order tokyonight.nvim's storm palette declares them.
palette=(
  red=#f7768e
  orange=#ff9e64
  yellow=#e0af68
  green=#9ece6a
  teal=#1abc9c
  cyan=#7dcfff
  blue=#7aa2f7
  blue1=#2ac3de
  purple=#9d7cd8
  magenta=#bb9af7
)

if [[ ${1-} == --list ]]; then
  for entry in "${palette[@]}"; do printf 'tn-%s\n' "${entry%%=*}"; done
  exit 0
fi

# The base a custom theme sits on. Read from the settings rather than assumed,
# so this follows a switch between dark and light -- and never nests one custom
# theme on another, which the loader rejects.
base=$(jq -r '.theme // "dark"' "$HOME/.claude/settings.json" 2>/dev/null || printf 'dark')
case $base in custom:* | '' | null) base=dark ;; esac

mkdir -p "$themes"
for entry in "${palette[@]}"; do
  name=${entry%%=*}
  hex=${entry#*=}
  # promptBorder is the box around what you type. Its Shimmer partner is the
  # animated variant; the same colour keeps the pulse from changing hue.
  jq -n --arg n "Tokyo Night Storm $name" --arg b "$base" --arg c "$hex" '{
    name: $n,
    base: $b,
    overrides: { promptBorder: $c, promptBorderShimmer: $c }
  }' >| "$themes/tn-$name.json"
done

printf 'installed %d themes in %s on base %s\n' "${#palette[@]}" "$themes" "$base"
