# Colors
source ~/.colors

# alias
source ~/.aliases

# homebrew
export PATH="/usr/local/sbin:$PATH"

# rvm
export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

# Add Xcode bin folder to PATH environment variable
export PATH="$PATH:/Applications/Xcode.app/Contents/Developer/usr/bin"

# Add mysql bin folder to PATH environment variable
export PATH="$PATH:/usr/local/mysql-5.5.25-osx10.6-x86_64/bin"

# Add android tools to PATH environment variable
export PATH="$PATH:/Developer/android-sdk-macosx/tools:/Developer/android-sdk-macosx/platform-tools"

# git autocomplete
source ~/.git-completion
__git_complete ga _git_add
__git_complete gb _git_branch
__git_complete gc _git_commit
__git_complete gd _git_diff
__git_complete gl _git_log
__git_complete go _git_checkout

fnv_git_prompt() {
  local g="$(__gitdir)"
  if [ -n "$g" ]; then
    local color=${GREEN}
    git diff --no-ext-diff --quiet --exit-code 2>/dev/null || \
        color=${RED}
    local GIT_PROMPT=`__git_ps1 "${color} (%s)${NORMAL}"`
    echo ${GIT_PROMPT}
  fi
}

PS1="${VIOLET}\u@\h${NORMAL} \W${NORMAL}\$(fnv_git_prompt) ${YELLOW}\$ ${RESET}"