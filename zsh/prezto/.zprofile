#
# Executes commands at login pre-zshrc.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

#
# Browser
#

export BROWSER=/usr/bin/google-chrome-stable
if [[ "$OSTYPE" == darwin* ]]; then
  export BROWSER='open'
fi

#
# Editors
#

export EDITOR='nvim'
export VISUAL='nvim'
export PAGER='less'

#
# Language
#

if [[ -z "$LANG" ]]; then
  export LANG='en_US.UTF-8'
fi

#
# Paths
#

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path

# Set the the list of directories that cd searches.
# cdpath=(
#   $cdpath
# )

# Set the list of directories that Zsh searches for programs.
# Every entry carries the (N) glob qualifier so directories that do not exist
# on this machine are dropped instead of sitting in PATH as failed stat()s on
# every command lookup. The Homebrew entry used to be produced by a command
# substitution, which meant neither the brace nor the (N) was ever expanded --
# it put the literal string `/opt/homebrew/{,s}bin(N)` into PATH. Homebrew is
# on PATH regardless, via the `brew shellenv` eval at the bottom of this file.
path=(
  /usr/local/{bin,sbin}(N)
  /opt/homebrew/{bin,sbin}(N)
  /opt/local/{,s}bin(N)
  $HOME/.local/{bin,sbin}(N)
  $path
)

#
# Less
#

# Set the default Less options.
# Mouse-wheel scrolling has been disabled by -X (disable screen clearing).
# Remove -X and -F (exit if the content fits on one screen) to enable it.
export LESS='-F -g -i -M -R -S -w -X -z-4'

# Set the Less input preprocessor.
# Try both `lesspipe` and `lesspipe.sh` as either might exist on a system.
if (( $#commands[(i)lesspipe(|.sh)] )); then
  export LESSOPEN="| /usr/bin/env $commands[(i)lesspipe(|.sh)] %s 2>&-"
fi

#
# Temporary Files
#

if [[ ! -d "$TMPDIR" ]]; then
  export TMPDIR="$(mktemp -d)"
fi

TMPPREFIX="${TMPDIR%/}/zsh"

#
# Homebrew
#

eval "$(/opt/homebrew/bin/brew shellenv)"
