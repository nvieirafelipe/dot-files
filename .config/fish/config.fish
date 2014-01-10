set -g -x PATH /usr/local/bin $PATH
set -g -x PATH ~/bin $PATH

function fish_greeting
  echo
  fortune
  echo
end