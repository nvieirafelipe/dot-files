set -g -x PATH ~/.bin $PATH

set fish_path ~/.oh-my-fish/
set fish_plugins git php localhost emoji-clock
. $fish_path/oh-my-fish.fish

function fish_greeting
  echo
  fortune
  echo
  envup
end