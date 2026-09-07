#!/bin/bash
#
# Moves packages/nicegram-assistant-ios/.build out of the package, without
# building anything.
#
# Reach for this when an **Xcode** build fails with
#
#   ERROR: Cycle detected but could not be properly displayed due to an
#   internal problem. Please file an issue.
#
# Xcode runs bazel itself, through the generated project, so it cannot be
# hooked the way ci/verify-build.sh and ci/generate-project.sh are -- they
# evict on their own. This is the one-second fix for the Xcode case. See
# ci/lib/swiftpm-build.sh for why a stray .build does that to bazel.

cd "$(dirname "$0")" || exit 1
. ./_env.sh

# shellcheck source=lib/swiftpm-build.sh
. ./lib/swiftpm-build.sh

if ng_evict_swiftpm_build; then
  if [ -d "$(ng_swiftpm_build_path)" ]; then
    echo "evict-swiftpm-build: still present -- eviction did not take" >&2
    exit 1
  fi
  echo "evict-swiftpm-build: the package is clean; retry your build."
else
  echo "evict-swiftpm-build: could not move it out" >&2
  exit 1
fi
