#!/usr/bin/env bash
set -euo pipefail

# Prints an nvim-web-devicons glyph for the project in <dir>, wrapped in a tmux
# colour directive, for use as a tmux-nova segment. The glyphs and colours below
# are generated from the installed nvim-web-devicons so the status bar matches
# neo-tree. <reset-fg> is a bare hex colour (no leading #) restored after the
# glyph so the rest of the segment keeps the segment's own foreground.

[[ $# -ge 1 ]] || {
  printf 'usage: %s <dir> [reset-fg]\n' "${0##*/}" >&2
  exit 1
}

dir=$1
reset=${2:-}

root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || root=$dir

# '<glob> <glyph> <colour>', first match wins
rules=(
  'mix.exs           a074c4'
  'Cargo.toml        dea584'
  'go.mod            00add8'
  'tsconfig.json     519aba'
  'package.json      cbcb41'
  'pyproject.toml    ffbc03'
  'requirements.txt  ffbc03'
  'setup.py          ffbc03'
  'Gemfile           701516'
  '*.gemspec         701516'
  'pom.xml           7a0d21'
  'build.gradle      005f87'
  'build.gradle.kts  7f52ff'
  'composer.json     a074c4'
  '*.csproj         󰌛 596706'
  '*.sln            󰌛 596706'
  'build.zig         f69a1b'
  'pubspec.yaml      03589c'
  'build.sbt         cc3e44'
  'stack.yaml        a074c4'
  '*.cabal           a074c4'
  'flake.nix         7ebae4'
  'default.nix       7ebae4'
  'shell.nix         7ebae4'
  'Dockerfile       󰡨 458ee6'
  '*.tf              5f43e9'
  'CMakeLists.txt    dce3eb'
  'Makefile          6d8086'
  '*.rockspec        51a0cf'
  'init.lua          51a0cf'
  '.git              f54d27'
)

emit() {
  printf '#[fg=#%s]%s' "$2" "$1"
  [[ -n $reset ]] && printf '#[fg=#%s]' "$reset"
  # Trailing gap after the icon. It has to come from here rather than from the
  # segment option: tmux-nova re-echoes option values unquoted, which collapses
  # any run of spaces down to one.
  printf ' '
  return 0
}

for rule in "${rules[@]}"; do
  read -r glob glyph colour <<<"$rule"
  for match in "$root"/$glob; do
    [[ -e $match ]] || continue
    emit "$glyph" "$colour"
    exit 0
  done
done

emit '' '7aa2f7'
