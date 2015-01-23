function envup
  if test -f '.env'
    sed -Ee 's/export (.*)=(.*)$/set -gx \1 \2/' .env | . > /dev/null 2>&1
  end
end
