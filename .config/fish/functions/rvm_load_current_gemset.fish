function rvm_load_current_gemset
  if test -f '.versions.conf'
    rvm .versions.conf
  end
end