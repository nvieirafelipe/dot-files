#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# Customize to your needs...


# The following lines were added by compinstall

zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'm:{[:lower:]}={[:upper:]}' 'r:|[._-]=** r:|=**' 'l:|=* r:|=*'
zstyle :compinstall filename '/Users/felipe/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

# zsh syntax highlighting
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# iTerm2
source ~/.iterm2_shell_integration.zsh

# fzf
# Default files command
ZSH_AUTOSUGGEST_IGNORE_WIDGETS+=(fzfz-file-widget)

export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow \
  --glob "!{.git,.direnv,.elixir_ls,*/**/.elixir_ls,.mnesia,_build,bower_components,cover,*/**/cover,dist,deps,doc,log,node_modules,\
  public/packs,tmp,vendor/bundle}/**"'

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
#

# asdf
. $(brew --prefix asdf)/asdf.sh

# aliases
source "$HOME/.aliases"

# direnv
eval "$(direnv hook zsh)"

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

# iTerm2
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# Homebrew asdf
source $(brew --prefix asdf)/asdf.sh
