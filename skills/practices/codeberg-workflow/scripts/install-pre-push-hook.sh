#!/usr/bin/env bash
#
# install-pre-push-hook.sh
#
# Install (or list/update) a per-repo .git/hooks/pre-push that, when
# pushing to the `codeberg` remote, fails the push if `playbill verify`
# does not pass on the most recent .livemd in
# .snippets/issue-*/ matching the current branch, OR if any cell output
# in those notebooks reports ExUnit failures (a `[1-9][0-9]* failure`
# line) or contains a `TODO` marker. The two checks correspond to the
# two pass conditions documented in
# references/solution-verifier.md#the-two-pass-conditions.
#
# Usage:
#   install-pre-push-hook.sh [--list|--update] <repo-path> [<repo-path> ...]
#   install-pre-push-hook.sh [--list|--update] --scan <parent-dir>
#
# Flags:
#   --list           Show which repos already have the hook installed.
#                    Does not install or modify anything.
#   --update         Overwrite existing pre-push hooks. Without this flag,
#                    an existing hook is left untouched and reported.
#   --scan <dir>     Treat every immediate subdirectory of <dir> that
#                    contains a .git directory as a target repo.
#   --help, -h       Print this help and exit.
#
# Exit codes:
#   0  success
#   1  invalid flags / no repos found
#   2  one or more repos failed (e.g. not a git repo, write error)

set -euo pipefail

readonly SCRIPT_NAME="${0##*/}"

usage() {
  sed -n '3,25p' "$0" | sed 's/^# \{0,1\}//'
}

log()   { printf '[%s] %s\n' "$SCRIPT_NAME" "$*" >&2; }
fatal() { log "FATAL: $*"; exit 1; }

# The hook body installed into each repo. Keep self-contained — no
# dependency on this installer at runtime.
read -r -d '' HOOK_BODY <<'HOOK_EOF' || true
#!/usr/bin/env bash
#
# pre-push: gate pushes to the `codeberg` remote on `playbill verify`
# for the active issue's livemd(s). Installed by
# codeberg-workflow/scripts/install-pre-push-hook.sh.
#
# Skips gracefully when the push targets a remote other than `codeberg`,
# or when no .snippets/issue-*/ dir matches the current branch — older
# repos, unrelated branches, and other remotes push normally.

set -euo pipefail

# git passes the remote name as $1 and its URL as $2. Gate only pushes
# to the `codeberg` remote; pushes to any other remote (e.g. a github
# mirror) skip the verifier gate entirely.
REMOTE_NAME="${1:-}"
[ "$REMOTE_NAME" = "codeberg" ] || exit 0

readonly REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '')"
[ -z "$REPO_ROOT" ] && exit 0

# Resolve current branch — works for both regular checkouts and worktrees.
BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo '')"
[ -z "$BRANCH" ] && exit 0

# Extract issue slug from branch. Accept `issue-NNN-...` or any branch
# that contains `issue-NNN`.
ISSUE_SLUG=""
if [[ "$BRANCH" =~ (issue-[0-9]+) ]]; then
  ISSUE_SLUG="${BASH_REMATCH[1]}"
fi

if [ -z "$ISSUE_SLUG" ]; then
  exit 0
fi

SNIPPETS_DIR="$REPO_ROOT/.snippets/$ISSUE_SLUG"
if [ ! -d "$SNIPPETS_DIR" ]; then
  exit 0
fi

shopt -s nullglob
LIVEMDS=("$SNIPPETS_DIR"/*.livemd)
shopt -u nullglob

if [ "${#LIVEMDS[@]}" -eq 0 ]; then
  echo "[pre-push] No .livemd found in $SNIPPETS_DIR — skipping verifier gate." >&2
  exit 0
fi

if ! command -v playbill >/dev/null 2>&1; then
  echo "[pre-push] playbill not on PATH; install it before pushing." >&2
  exit 1
fi

FAILED=0
for livemd in "${LIVEMDS[@]}"; do
  echo "[pre-push] Verifying $livemd ..." >&2

  if ! playbill verify "$livemd" >/dev/null 2>&1; then
    echo "[pre-push] FAIL: playbill verify $livemd" >&2
    FAILED=1
    continue
  fi

  # Re-render the notebook and scan for unsatisfied ACs. `playbill show`
  # prints the captured cell outputs alongside the markdown. Pass
  # condition 2 from solution-verifier.md: zero ExUnit failures in the
  # baseline. TODO markers in the Solution Critique also block.
  if playbill show "$livemd" 2>/dev/null \
      | grep -nE '[1-9][0-9]* failure|TODO' >/dev/null; then
    echo "[pre-push] FAIL: $livemd reports ExUnit failures or TODO markers." >&2
    echo "        Every AC cell must record 0 failures and the Solution" >&2
    echo "        Critique must have no TODO items before push." >&2
    FAILED=1
  fi
done

if [ "$FAILED" -ne 0 ]; then
  echo "[pre-push] Verifier gate FAILED. Fix the livemd(s) before retrying." >&2
  exit 1
fi

exit 0
HOOK_EOF

# ---- arg parsing ----

mode="install"
update=0
scan_dir=""
repos=()

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --list)    mode="list"; shift ;;
    --update)  update=1; shift ;;
    --scan)    [ $# -ge 2 ] || fatal "--scan requires a directory"
               scan_dir="$2"; shift 2 ;;
    --*)       fatal "unknown flag: $1" ;;
    *)         repos+=("$1"); shift ;;
  esac
done

if [ -n "$scan_dir" ]; then
  [ -d "$scan_dir" ] || fatal "--scan target not a directory: $scan_dir"
  while IFS= read -r -d '' git_dir; do
    repos+=("$(dirname "$git_dir")")
  done < <(find "$scan_dir" -mindepth 2 -maxdepth 2 -name .git -print0)
fi

[ "${#repos[@]}" -gt 0 ] || fatal "no repos provided. See --help."

# ---- per-repo action ----

failures=0

install_hook() {
  local repo="$1"
  local hook_path="$repo/.git/hooks/pre-push"

  if [ ! -d "$repo/.git" ]; then
    log "SKIP $repo (not a git repo)"
    failures=$((failures + 1))
    return
  fi

  if [ -e "$hook_path" ] && [ "$update" -ne 1 ]; then
    log "EXISTS $repo (use --update to overwrite)"
    return
  fi

  printf '%s\n' "$HOOK_BODY" > "$hook_path"
  chmod +x "$hook_path"
  log "INSTALLED $repo"
}

list_hook() {
  local repo="$1"
  local hook_path="$repo/.git/hooks/pre-push"
  if [ -x "$hook_path" ] && grep -q 'codeberg-workflow/scripts/install-pre-push-hook.sh' "$hook_path" 2>/dev/null; then
    printf 'INSTALLED  %s\n' "$repo"
  elif [ -e "$hook_path" ]; then
    printf 'OTHER-HOOK %s\n' "$repo"
  else
    printf 'MISSING    %s\n' "$repo"
  fi
}

for repo in "${repos[@]}"; do
  case "$mode" in
    install) install_hook "$repo" ;;
    list)    list_hook "$repo" ;;
  esac
done

if [ "$failures" -gt 0 ]; then
  exit 2
fi
exit 0
