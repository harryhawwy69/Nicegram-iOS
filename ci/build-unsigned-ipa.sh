#!/usr/bin/env bash
set -euo pipefail

: "${BAZEL_LOCAL_CACHE:?BAZEL_LOCAL_CACHE is required}"
: "${BAZEL_USER_ROOT:?BAZEL_USER_ROOT is required}"
: "${BUILD_WORKING_DIR:?BUILD_WORKING_DIR is required}"
: "${GITHUB_RUN_NUMBER:?GITHUB_RUN_NUMBER is required}"
: "${WRAITHGRAM_TELEGRAM_CONFIGURATION_PROD:?WRAITHGRAM_TELEGRAM_CONFIGURATION_PROD is required}"

source_path="${SOURCE_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
configuration_path="$BUILD_WORKING_DIR/wraithgram-configuration.json"
artifacts_path="$BUILD_WORKING_DIR/artifacts"

mkdir -p "$BUILD_WORKING_DIR" "$artifacts_path"

printf '%s' "$WRAITHGRAM_TELEGRAM_CONFIGURATION_PROD" | base64 --decode > "$configuration_path"
python3 - "$configuration_path" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as source:
    configuration = json.load(source)

configuration["bundle_id"] = "app.wraithgram"
configuration["is_appstore_build"] = "false"

with open(path, "w", encoding="utf-8") as destination:
    json.dump(configuration, destination, indent=2)
    destination.write("\n")
PY

cd "$source_path"
python3 build-system/Make/Make.py \
  --bazelUserRoot="$BAZEL_USER_ROOT" \
  --cacheDir="$BAZEL_LOCAL_CACHE" \
  build \
  --buildNumber="$GITHUB_RUN_NUMBER" \
  --configurationPath="$configuration_path" \
  --xcodeManagedCodesigning \
  --disableProvisioningProfiles \
  --configuration=release_arm64 \
  --outputBuildArtifactsPath="$artifacts_path"
