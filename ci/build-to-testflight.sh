#!/bin/bash
# The shebang is load-bearing. Without it this file runs under `sh`, where a
# failed `.` on a missing file aborts the script outright — the `||` fallback
# never runs, nothing is printed, and it looks like a silent no-op. That only
# happens in a worktree, where ci/fastlane-env.sh does not exist.
ENV_FILE="./fastlane-env.sh"
[ -f "$ENV_FILE" ] || ENV_FILE="$(dirname "$(git rev-parse --git-common-dir)")/ci/fastlane-env.sh"
if [ ! -f "$ENV_FILE" ]; then
  echo "error: fastlane-env.sh not found (looked in ./ and the main clone). Obtain it from the shared env store." >&2
  exit 1
fi
. "$ENV_FILE"
SOURCE_PATH="$(cd .. && pwd)"; export SOURCE_PATH

if [ "$1" = "" ] || [ "$2" != "" ]
then
  echo "You must pass one argument reflecting the version and build number"
  exit 1
fi

. ./push-to-github-repo.sh beta "$1"
