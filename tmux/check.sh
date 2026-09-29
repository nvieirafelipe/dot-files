#!/usr/bin/env bash
# Lints, format-checks and tests every script in this repo.
#
# Run: tmux/check.sh

set -uo pipefail

repo=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo" || exit 1

scripts=(
  tmux-review/review.tmux tmux-review/run_tests tmux-review/run_coverage
  tmux-review/bin/git-review tmux-review/scripts/*.sh tmux-review/tests/*.sh
  tmux-agent-status/agent-status.tmux tmux-agent-status/run_tests
  tmux-agent-status/run_coverage tmux-agent-status/bin/agent-status
  tmux-agent-status/scripts/*.sh tmux-agent-status/tests/*.sh
  tmux/check.sh tmux/rebuild-which-key.sh tmux/scripts/*.sh install.sh
)
status=0

step() { printf '\n\e[1m==> %s\e[0m\n' "$1"; }

# A tool that cannot run has to say so. An asdf shim with no version pinned
# prints its complaint to stderr and exits non-zero having done nothing, which
# read as a clean run for as long as only stdout was being looked at.
require() {
  local tool=$1
  if "$tool" --version >/dev/null 2>&1; then
    return 0
  fi
  # asdf installs it but will not choose a version; take the newest it has.
  local version
  version=$(asdf list "$tool" 2>/dev/null | tr -d ' *' | grep -E '^[0-9]' | tail -1)
  if [[ -n $version ]]; then
    export "ASDF_$(printf '%s' "$tool" | tr '[:lower:]-' '[:upper:]_')_VERSION=$version"
    if "$tool" --version >/dev/null 2>&1; then
      printf '  using %s %s from asdf\n' "$tool" "$version"
      return 0
    fi
  fi
  printf '  \e[31m%s cannot run\e[0m -- brew install %s, or pin it with asdf\n' \
    "$tool" "$tool"
  return 1
}

# -x so it follows the source directives: review.sh reads git-review as a
# library rather than spawning it, and without this that read is a blind spot.
step "shellcheck (${#scripts[@]} scripts)"
if ! require shellcheck; then
  status=1
elif shellcheck -f gcc -x "${scripts[@]}"; then
  printf '  clean\n'
else
  status=1
fi

# shfmt is deliberately not run. It cannot format this without either dropping
# the column alignment in install.sh's link calls, or -- with -kp, which keeps
# that alignment -- indenting the body of a `|| { a; b; }` one-liner out to
# where the brace was. A check that cannot be satisfied is worse than no check.

step 'bash -n'
for f in "${scripts[@]}"; do
  bash -n "$f" || status=1
done
printf '  clean\n'

step 'tests'
tmux-review/run_tests || status=1
tmux-agent-status/run_tests || status=1

# The agent-status plugin is covered line for line, and a new line with no test
# should fail here rather than wait for someone to run the report.
step 'coverage'
tmux-agent-status/run_coverage --min 100 >/dev/null || {
  tmux-agent-status/run_coverage --missing
  status=1
}

exit "$status"
