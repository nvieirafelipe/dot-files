#!/usr/bin/env bash
set -euo pipefail

# Regenerates tmux-which-key's menu from which-key.yaml.
#
# The plugin does this itself on every load, which costs 1.4s of every tmux
# start and every config reload -- python3 here is an asdf shim, and the menu
# only changes when the yaml does. Autobuild is off in .tmux.conf; run this
# after editing which-key.yaml, then prefix+R.
plugin=$HOME/.tmux/plugins/tmux-which-key
[[ -x $plugin/plugin/build.py ]] || {
  printf 'tmux-which-key is not installed at %s\n' "$plugin" >&2
  exit 1
}

# The real interpreter, not the shim: the plugin pins .python-version to a
# version that is not installed, so asdf resolves it the slow way.
python=$(python3 -c 'import sys; print(sys.executable)')

"$python" "$plugin/plugin/build.py" "$plugin/config.yaml" "$plugin/plugin/init.tmux"
printf 'menu rebuilt -- prefix+R to pick it up\n'
