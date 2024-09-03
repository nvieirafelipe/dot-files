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
# The following lines were added by compinstall
zstyle :compinstall filename "$HOME/.zshrc"

# zsh completions
fpath=(usr/share/zsh/site-functions $fpath)

autoload -Uz compinit
compinit
# End of lines added by compinstall

# allow bash completions
autoload -U +X bashcompinit
bashcompinit

# zsh syntax highlighting
[ -f /usr/share/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
	source /usr/share/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
	source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# aliases
source "$HOME/.aliases"

# direnv
eval "$(direnv hook zsh)"

# asdf vm
[ -f ~/.asdf/asdf.sh ] && source ~/.asdf/asdf.sh
fpath=($ASDF_DIR/completions $fpath)
autoload -Uz compinit
compinit

# php
# export PATH="/usr/local/opt/bison@2.7/bin:$PATH"

# rust
# export PATH="$HOME/.cargo/bin:$PATH"

# fzf
# Default files command
ZSH_AUTOSUGGEST_IGNORE_WIDGETS+=(fzfz-file-widget)

export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow \
  --glob "!{.git,.direnv,.mnesia,_build,bower_components,cover,*/**/cover,dist,deps,\
  doc,docs,log,node_modules,public/packs,tmp,vendor/bundle}/**"'

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Added by backup.
[ -f /opt/backup/bash-completion/backup ] && . /opt/backup/bash-completion/backup

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
