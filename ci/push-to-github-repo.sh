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

target_branch=$1
commit_message=$2

current_branch=$(git symbolic-ref --short HEAD)

git push

curl --request POST \
  --url 'https://api.bitbucket.org/2.0/repositories/mobyrix/nicegram-ios/pipelines' \
  --header 'Authorization: Bearer '$BITBUCKET_ACCESS_TOKEN'' \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data "{\"target\": {\"type\": \"pipeline_ref_target\",\"ref_type\": \"branch\",\"ref_name\": \"$current_branch\",\"selector\": {  \"type\": \"custom\",  \"pattern\": \"push-to-github-repo\"}},\"variables\": [{  \"key\": \"TargetBranch\",  \"value\": \"$target_branch\"},{  \"key\": \"CommitMessage\",  \"value\": \"$commit_message\"}]}"
