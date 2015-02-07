# rvm
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

# Path to the bash-it configuration
export BASH_IT=$HOME/.bash_it

# Lock and Load a custom theme file
# location /.bash_it/themes/
export BASH_IT_THEME='powerline-plain'

# Load Bash It
source $BASH_IT/bash_it.sh

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $SCRIPTDIR/.colors

# alias
source $SCRIPTDIR/.aliases

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

# Setting PATH for brew Python
export PATH="/usr/local/Cellar/python/2.7.5/bin:$PATH"

# Use direnv (http://direnv.net/)
eval "$(direnv hook bash)"
