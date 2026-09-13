#!/usr/bin/env bash
set -euo pipefail

# Links this repo into place on a fresh machine. Idempotent -- safe to re-run.
# Run `brew bundle` first (or let this script do it) so tmux, delta, bat,
# terminal-notifier and the Nerd Font exist before anything is linked.

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

link() {
  local src=$1 dest=$2
  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src" "$dest"
  printf '  %s -> %s\n' "${dest/#$HOME/~}" "${src/#$repo/.}"
}

echo "==> brew bundle"
command -v brew >/dev/null && brew bundle --file="$repo/Brewfile"

echo "==> symlinks"
link "$repo/.tmux.conf"                 "$HOME/.tmux.conf"
link "$repo/.gitconfig"                 "$HOME/.gitconfig"
link "$repo/tmux/scripts"               "$HOME/.tmux/scripts"
# The review plugin, linked in beside the ones tpm fetches -- .tmux.conf runs
# its entry point from there. git-review lives inside it and is linked onto PATH
# as well, because `git review` is worth having outside a review window too.
link "$repo/tmux-review"                "$HOME/.tmux/plugins/tmux-review"
link "$repo/tmux-review/bin/git-review" "$HOME/.local/bin/git-review"
link "$repo/claude/settings.json"       "$HOME/.claude/settings.json"
link "$repo/claude/bin"                "$HOME/.claude/bin"
link "$repo/codex/hooks.json"           "$HOME/.codex/hooks.json"
link "$repo/ghostty/config"             "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
link "$repo/iterm2/DotfilesProfile.json" \
     "$HOME/Library/Application Support/iTerm2/DynamicProfiles/DotfilesProfile.json"

echo "==> notification sounds"
mkdir -p "$HOME/Library/Sounds"
cp "$repo"/sounds/*.aiff "$HOME/Library/Sounds/"
printf '  %s\n' "$(cd "$repo/sounds" && echo *.aiff)"

echo "==> delta syntax theme"
# delta reads bat's theme set, and bat only sees themes after a cache rebuild.
mkdir -p "$HOME/.config/bat/themes"
cp "$repo"/bat/themes/*.tmTheme "$HOME/.config/bat/themes/"
command -v bat >/dev/null && bat cache --build >/dev/null && echo "  bat cache rebuilt"

echo "==> tmux plugins"
# TPM lives in the Homebrew prefix; its plugins install into ~/.tmux/plugins.
tpm_dir=$(brew --prefix 2>/dev/null)/opt/tpm/share/tpm
if [[ -x "$tpm_dir/bin/install_plugins" ]]; then
  mkdir -p "$HOME/.tmux/plugins"
  "$tpm_dir/bin/install_plugins"
  # tmux-which-key keeps its config inside the plugin checkout, so it can only
  # be linked once the plugin exists.
  link "$repo/tmux/which-key.yaml" "$HOME/.tmux/plugins/tmux-which-key/config.yaml"
else
  echo "  tpm not found; run 'brew install tpm' then re-run this script" >&2
fi

cat <<'DONE'

==> done. Remaining manual steps:
  - iTerm2: Settings > Profiles, select "Tokyo Night Storm (dotfiles)", set as default
  - Codex:  run /hooks and trust the entries under User config
  - tmux:   reload with `tmux source-file ~/.tmux.conf`
DONE
