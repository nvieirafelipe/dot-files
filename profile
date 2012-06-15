# Colors
source ~/.colors

# alias
source ~/.aliases

# Add Xcode bin folder to PATH environment variable
export PATH="$PATH:/Applications/Xcode.app/Contents/Developer/usr/bin"

# Add mysql bin folder to PATH environment variable
export PATH="$PATH:/usr/local/mysql-5.5.25-osx10.6-x86_64/bin"

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
    local GIT_PROMPT=`__git_ps1 "${color}(%s)${NORMAL}"`
    echo ${GIT_PROMPT}
  fi
}

PS1="${VIOLET}\u@\h${NORMAL} \w${NORMAL} $(fnv_git_prompt) ${YELLOW}\$ ${RESET}"