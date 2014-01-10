function fish_prompt --description 'Write out the prompt'
	set -l last_status $status

  set_color magenta
  echo -n (whoami)'@'(hostname -s)
  set_color normal

  echo -n ' '

  # PWD
  set_color white
  echo -n (prompt_pwd)
  set_color normal

  __terlar_git_prompt

  if not test $last_status -eq 0
    set_color $fish_color_error
  end

  set_color yellow
  echo -n ' $ '
  set_color normal
end
