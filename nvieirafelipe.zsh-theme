# Initially hacked from the CRUNCH theme.

WHITE_COLOR="%{$fg[white]%}"
WHOAMI_COLOR="%{$fg[magenta]%}"
AT_COLOR="%{$fg[yellow]%}"
RVM_COLOR="%{$fg[magenta]%}"
DIR_COLOR="%{$fg[blue]%}"
GIT_BRANCH_COLOR="%{$fg[green]%}"
GIT_CLEAN_COLOR="%{$fg[green]%}"
GIT_DIRTY_COLOR="%{$fg[red]%}"

ZSH_THEME_GIT_PROMPT_PREFIX="$WHITE_COLOR:$GIT_BRANCH_COLOR"
ZSH_THEME_GIT_PROMPT_SUFFIX=""
ZSH_THEME_GIT_PROMPT_CLEAN=" $GIT_CLEAN_COLOR✓"
ZSH_THEME_GIT_PROMPT_DIRTY=" $GIT_DIRTY_COLOR✗"

if [ -e ~/.rvm/bin/rvm-prompt ]; then
  RVM_="$RVM_COLOR|ruby \${\$(~/.rvm/bin/rvm-prompt i v g)#ruby-}|%{$reset_color%}"
fi

WHOAMI="$WHOAMI_COLOR%n$AT_COLOR@%m"
DIR_="$DIR_COLOR%~"
PROMPT="$WHITE_COLOR ➭ "

# Put it all together!
RPS1="$RVM_"
PROMPT="$WHOAMI $DIR_\$(git_prompt_info)$PROMPT%{$reset_color%}"
