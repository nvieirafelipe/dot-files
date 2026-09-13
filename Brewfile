# Dependencies for this dotfiles setup. Restore with: brew bundle
#
# Everything here is load-bearing for the tmux/git/terminal configuration in
# this repo -- see install.sh for what gets linked where.

brew "tmux"               # .tmux.conf, the agent status scripts
brew "tpm"                # tmux plugin manager, sourced at the end of .tmux.conf
brew "git-delta"          # git pager, styled by .gitconfig
brew "bat"                # supplies delta's syntax themes (bat/themes)
brew "terminal-notifier"  # agent notifications; osascript banners do not appear
brew "fontconfig"         # fc-query, used to verify glyph coverage
brew "jq"                 # hook config manipulation
brew "shellcheck"         # tmux/check.sh
brew "neovim"
brew "gh"

# The two terminals install.sh writes configuration for: Ghostty's config is
# linked into its Application Support directory, iTerm2's profile into
# DynamicProfiles. Both auto-update themselves, so brew only puts them there.
cask "ghostty"
cask "iterm2"

# Pinned build matters: glyph choices in .tmux.conf and .gitconfig were measured
# against this font, and pre-3.2 releases lack the yaml (U+E8EB) and css
# (U+E6B8) icons nvim-web-devicons asks for.
cask "font-sauce-code-pro-nerd-font"
