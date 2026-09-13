#!/usr/bin/env bash
# Shared by review.tmux. review.sh does not source this: it reads no options at
# all, by design -- see the note in variables.sh.

# Reads a user option, falling back to the plugin's own default. show-option
# -gqv prints an empty line for an option that was never set, which is why the
# test is on emptiness rather than on the exit status.
get_tmux_option() {
  local option=$1 default=$2 value
  value=$(tmux show-option -gqv "$option")
  [[ -n $value ]] && printf '%s\n' "$value" || printf '%s\n' "$default"
}
