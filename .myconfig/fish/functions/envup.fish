function envup
  if test -f '.env'
    sed -Ee 's/export (.*)=(.*)$/set -gx \1 \2/' .env | .
  end
end
