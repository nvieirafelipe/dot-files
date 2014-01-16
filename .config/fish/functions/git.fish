function ga
  git add $argv
end

function gb
  git branch $argv
end

function gc
  git commit $argv
end

function gd
  git diff $argv
end

function gl
  git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative $argv
end

function gco
  git checkout $argv
end

function gs
  git status $argv
end


function gp
  git push $argv
end

function gf
  if count $argv > 0
    git fetch $argv
  else
    git fetch origin
  end
end
