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
setopt appendhistory autocd beep extendedglob nomatch notify
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/nvieirafelipe/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

# zsh completions
fpath=(usr/share/zsh/site-functions $fpath)

# zsh syntax highlighting
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

zsh_asdf_ruby(){
  local tool=$(cat .tool-versions 2> /dev/null | cut -c -4)

  if [[ "$tool" == "ruby" ]]; then
    local version=$(cat .tool-versions | cut -c 6-)
    local icon=$(print_icon 'RUBY_ICON')

    echo "$version $icon"
  fi
}

POWERLEVEL9K_CUSTOM_ASDF_RUBY='zsh_asdf_ruby'
POWERLEVEL9K_CUSTOM_ASDF_RUBY_BACKGROUND='009'

# On arch using the prezto-git POWERLEVEL9K_MODE must be set on .zshenv
POWERLEVEL9K_MODE='awesome-fontconfig'

POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status custom_asdf_ruby rspec_stats root_indicator background_jobs)

POWERLEVEL9K_DIR_DEFAULT_BACKGROUND='098'
POWERLEVEL9K_DIR_HOME_BACKGROUND='098'
POWERLEVEL9K_DIR_HOME_SUBFOLDER_BACKGROUND='098'
POWERLEVEL9K_DIR_DEFAULT_FOREGROUND='015'
POWERLEVEL9K_DIR_HOME_FOREGROUND='015'
POWERLEVEL9K_DIR_HOME_SUBFOLDER_FOREGROUND='015'

POWERLEVEL9K_VCS_CLEAN_BACKGROUND='148'
POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND='214'
POWERLEVEL9K_VCS_MODIFIED_BACKGROUND='009'

POWERLEVEL9K_RSPEC_STATS_GOOD_BACKGROUND='green'
POWERLEVEL9K_RSPEC_STATS_AVG_BACKGROUND='214'
POWERLEVEL9K_RSPEC_STATS_BAD_BACKGROUND='009'

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# aliases
source "$HOME/.aliases"

# direnv
eval "$(direnv hook zsh)"

# asdf vm
. $HOME/.asdf/asdf.sh
. $HOME/.asdf/completions/asdf.bash

# php
export PATH="/usr/local/opt/bison@2.7/bin:$PATH"

# fzf
export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow --glob "!{.git,tmp,dist,log,vendor,node_modules,bower_components}/**"'
