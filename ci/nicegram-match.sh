#!/bin/bash
# The shebang is load-bearing. Without it this file runs under `sh`, where a
# failed `.` on a missing file aborts the script outright — silently. That
# happens in any worktree, where ci/fastlane-env.sh does not exist.
ENV_FILE="./fastlane-env.sh"
[ -f "$ENV_FILE" ] || ENV_FILE="$(dirname "$(git rev-parse --git-common-dir)")/ci/fastlane-env.sh"
if [ ! -f "$ENV_FILE" ]; then
  echo "error: fastlane-env.sh not found (looked in ./ and the main clone). Obtain it from the shared env store." >&2
  exit 1
fi
. "$ENV_FILE"
fastlane nicegram_match type:$1