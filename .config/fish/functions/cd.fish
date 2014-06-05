function cd
  builtin cd "$argv"
  envup
  rvm_load_current_gemset
end