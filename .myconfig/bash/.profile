# Colors
source ~/.myconfig/bash/.colors

# alias
source ~/.myconfig/bash/.aliases

# Load envup function
source ~/.myconfig/bash/.functions/envup

# homebrew
export PATH="/usr/local/sbin:$PATH"
export PATH="/usr/local/bin:$PATH"

# Add Xcode bin folder to PATH environment variable
export PATH="$PATH:/Applications/Xcode.app/Contents/Developer/usr/bin"

# Add mysql bin folder to PATH environment variable
export PATH="$PATH:/usr/local/mysql-5.5.25-osx10.6-x86_64/bin"
export DYLD_LIBRARY_PATH=/usr/local/mysql/lib:$DYLD_LIBRARY_PATH

# Add android tools to PATH environment variable
export PATH="$PATH:/Applications/android-sdk-macosx/tools:/Applications/android-sdk-macosx/platform-tools"

# Add ANDROID_HOME
export ANDROID_HOME="/Applications/android-sdk-macosx/"

# Add Postgresql from brew
export PATH="/usr/local/Cellar/postgresql/9.2.4/bin:$PATH"

# Add npm
export PATH="/usr/local/share/npm/bin:$PATH"

# git autocomplete
source ~/.myconfig/bash/.git-completion
__git_complete ga _git_add
__git_complete gb _git_branch
__git_complete gc _git_commit
__git_complete gd _git_diff
__git_complete gl _git_log
__git_complete gco _git_checkout
__git_complete gp _git_push

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
# Setting PATH for Python 3.3
# The orginal version is saved in .profile.pysave
# PATH="/Library/Frameworks/Python.framework/Versions/3.3/bin:${PATH}"
# export PATH

# Setting PATH for Python 2.7
# The orginal version is saved in .profile.pysave
# PATH="/Library/Frameworks/Python.framework/Versions/2.7/bin:${PATH}"
# export PATH

# Setting PATH for brew Python
PATH="/usr/local/Cellar/python/2.7.5/bin:${PATH}"
export PATH

# rvm
export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
