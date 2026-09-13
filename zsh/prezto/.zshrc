# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Felipe Vieira <nvieirafelipe@gmail.com>
#

# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt appendhistory autocd autopushd pushdignoredups beep extendedglob nomatch notify
bindkey -e

# End of lines configured by zsh-newuser-install

# Keep PATH free of duplicates. .zprofile marks `path` unique, but it only runs
# for login shells, so nested interactive shells accumulated repeats -- .rd/bin
# and .local/bin were each on PATH several times, and every repeat is another
# failed lookup on every command that misses.
typeset -U path PATH
# The following lines were added by compinstall
zstyle :compinstall filename "$HOME/.zshrc"

# Completions are initialised exactly once, by Prezto's `completion` module,
# which runs `compinit -C` against its own cached dump. Calling `compinit` here
# too rebuilt that dump from scratch on every startup: the three resulting
# compinit calls accounted for 926ms of a 885ms interactive shell. The fpath
# entry that used to live here was `usr/share/zsh/site-functions` -- relative,
# so never resolved, and absent on macOS regardless.
# `bashcompinit` still has to run, but only after Prezto -- see below.

# zsh syntax highlighting
[ -f /usr/share/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
	source /usr/share/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
	source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# bash-style completions, for the `backup` completion sourced further down.
# Depends on compinit, so it has to follow Prezto rather than precede it.
autoload -U +X bashcompinit && bashcompinit

# aliases
source "$HOME/.aliases"

# functions
source "$HOME/.functions"

# direnv
#
# The hook is pure shell that only changes when direnv itself does, so it is
# cached rather than regenerated: `direnv hook zsh` cost an exec (20ms) on
# every shell.
_direnv_hook=${XDG_CACHE_HOME:-$HOME/.cache}/direnv-hook.zsh
if (( $+commands[direnv] )); then
  if [[ ! -s $_direnv_hook || $commands[direnv] -nt $_direnv_hook ]]; then
    mkdir -p "${_direnv_hook:h}"
    direnv hook zsh >| "$_direnv_hook"
  fi
  source "$_direnv_hook"
fi
unset _direnv_hook

# asdf vm
#
# The prefix is hardcoded rather than asked for: `brew --prefix asdf` costs
# 213ms per shell and Homebrew's opt path is stable. asdf.sh is pure shell --
# it prepends bin and shims to PATH and defines the `asdf` wrapper. It ships no
# completions directory, so there is no fpath entry to add here and nothing
# that justified a second compinit.
ASDF_DIR=/opt/homebrew/opt/asdf/libexec
[[ -f $ASDF_DIR/asdf.sh ]] && source "$ASDF_DIR/asdf.sh"

# php
# export PATH="/usr/local/opt/bison@2.7/bin:$PATH"

# rust
# export PATH="$HOME/.cargo/bin:$PATH"

# fzf
# Default files command
ZSH_AUTOSUGGEST_IGNORE_WIDGETS+=(fzfz-file-widget)

export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow --glob "!{.git,.direnv,.mnesia,_build,bower_components,cover,*/**/cover,dist,deps,doc,docs,log,node_modules,public/packs,tmp,vendor/bundle}/**"'

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Added by backup.
[ -f /opt/backup/bash-completion/backup ] && . /opt/backup/bash-completion/backup

# Claude native installation
export PATH="/Users/nvieirafelipe/.local/bin:$PATH"

# Added by Playbill
export PATH="/Users/nvieirafelipe/Developer/playbill:$PATH"

# Ghostty tokyonight theme auto-download
if command -v ghostty &> /dev/null; then
  GHOSTTY_THEME_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty/themes/tokyonight"

  if [[ ! -f "$GHOSTTY_THEME_DIR/tokyonight_storm" ]]; then
    mkdir -p "$GHOSTTY_THEME_DIR"
    curl -fsSL "https://raw.githubusercontent.com/folke/tokyonight.nvim/refs/heads/main/extras/ghostty/tokyonight_storm" \
      -o "$GHOSTTY_THEME_DIR/tokyonight_storm"
  fi
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

if [[ "$OSTYPE" == darwin* ]]; then
  ## libpq homebrew installation instructions
  export PATH="/usr/local/opt/libpq/bin:$PATH"
  export LDFLAGS="-L/usr/local/opt/libpq/lib"
  export CPPFLAGS="-I/usr/local/opt/libpq/include"
  export PKG_CONFIG_PATH="/usr/local/opt/libpq/lib/pkgconfig"

  # readline homebrrew installation instructions
  export LDFLAGS="-L/opt/homebrew/opt/readline/lib"
  export CPPFLAGS="-I/opt/homebrew/opt/readline/include"
  ### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
  export PATH="/Users/nvieirafelipe/.rd/bin:$PATH"
  ### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

fi

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/nvieirafelipe/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

# opencode
export PATH=/Users/nvieirafelipe/.opencode/bin:$PATH

# Machine-local overrides (untracked)
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
