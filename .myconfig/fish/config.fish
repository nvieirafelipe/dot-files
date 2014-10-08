set -g -x PATH ~/.bin $PATH

# Android
set -g -x PATH ~/Developer/android/sdk/platform-tools $PATH
set -g -x PATH ~/Developer/android/sdk/tools $PATH

set fish_path ~/.oh-my-fish/
set fish_plugins git php localhost emoji-clock
. $fish_path/oh-my-fish.fish

# RVM
rvm > /dev/null

. ~/.config/fish/functions/aliases.fish

function fish_greeting
  echo
  fortune
  echo
  envup
end
