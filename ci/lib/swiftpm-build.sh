#!/bin/bash
#
# Keeps SwiftPM's build directory OUT of packages/nicegram-assistant-ios, and
# gives SwiftPM somewhere else to put it.
#
# Why. rules_swift_package_manager's repository rule digests the whole
# nicegram-assistant-ios directory (DIRECTORY_TREE_DIGEST), `.build` included.
# SwiftPM's checkouts contain symlinks that point at their own ancestors -- the
# one bazel reports is
#
#   .build/checkouts/GRDB.swift/Tests/CustomSQLite/GRDB -> ../..
#
# Walking that is a cycle, so bazel analysis dies before compiling anything:
#
#   ERROR: Cycle detected but could not be properly displayed due to an
#   internal problem. Please file an issue.
#
# It is not a bazel bug, and it surfaces only once someone has run SwiftPM in
# that directory (`swift test`, the Demo app, Scripts/generate_resources.sh) --
# so a clean checkout builds fine and the failure looks intermittent.
#
# Three fixes that do NOT work, all measured:
#
#   - Adding the path to .bazelignore. That governs package loading in the main
#     workspace, not a repository rule's directory digest.
#   - Renaming `.build` in place. Bazel just walks the new name; the next cycle
#     report named it.
#   - Moving it aside for the duration of a wrapper run and putting it back
#     afterwards. This was tried here and was WORSE THAN NOTHING: an Xcode
#     build runs bazel itself, through the generated project, so a wrapper can
#     neither stash for it nor be hooked by it -- and restoring the directory on
#     exit re-armed the trap for the next Xcode build. Do not reintroduce a
#     restore step.
#
# What works is that the directory is not there at all, so it gets moved out --
# to a path outside the workspace, on the same filesystem, so nothing is lost
# and the move is a rename rather than a 10 GB copy.
#
# It is a one-way move, not a loan. SwiftPM re-creates `.build` whenever it runs
# in that package, so the resting state has to be "outside" or the trap re-arms
# itself. Pointing SwiftPM at the evicted directory with `--scratch-path`
# instead was tried and does not work: it relocates checkouts and build
# products, but binary targets are still looked up under
# `<package>/.build/artifacts`, so resource generation fails with
# `error: XCFramework Info.plist not found`. Nothing here tries to be clever
# about that -- after running SwiftPM in the package, evict again
# (ci/evict-swiftpm-build.sh), which is one command and is what the wrappers do
# for themselves.

ng_swiftpm_build_path() {
  printf '%s/packages/nicegram-assistant-ios/.build' "$SOURCE_PATH"
}

# Deliberately beside the checkout, not inside it: outside this bazel
# workspace, and on the same filesystem so eviction is a rename rather than a
# 10 GB copy. Dot-prefixed because for a worktree this lands in
# .claude/worktrees/, next to the worktrees themselves.
ng_swiftpm_scratch_path() {
  printf '%s/.swiftpm-scratch/%s' \
    "$(dirname "$SOURCE_PATH")" "$(basename "$SOURCE_PATH")"
}

ng_evict_swiftpm_build() {
  local build scratch
  build="$(ng_swiftpm_build_path)"
  scratch="$(ng_swiftpm_scratch_path)"

  [ -d "$build" ] || return 0

  mkdir -p "$(dirname "$scratch")" || return 1

  if [ -d "$scratch" ]; then
    # Something already lives at the scratch path. The copy inside the package
    # is the newer one (SwiftPM just wrote it), so it wins.
    rm -rf "$scratch" || return 1
  fi

  mv "$build" "$scratch" || return 1
  echo "note: moved packages/nicegram-assistant-ios/.build out to $scratch"
  echo "      (a .build inside that package makes bazel analysis fail with"
  echo "       \"Cycle detected\"; see ci/lib/swiftpm-build.sh)"
}
