#!/bin/bash
#
# Fixture-based tests for ci/lib/swiftpm-build.sh.
#
# The property under test is one-way: after ng_evict_swiftpm_build, the package
# must not contain .build. An earlier version of this helper moved the directory
# aside and put it BACK when the run finished, which passed every test it had
# and was worse than doing nothing -- Xcode runs bazel itself, so restoring the
# directory simply re-armed the trap for the next Xcode build. Hence the
# assertions below check the resting state, not just that a move happened.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/swiftpm-build.sh
. "$HERE/../lib/swiftpm-build.sh"

failures=0
check() { # $1=label  $2=expected  $3=actual
  if [ "$2" = "$3" ]; then
    echo "  ok   $1"
  else
    echo "  FAIL $1"
    echo "         expected: [$2]"
    echo "         actual:   [$3]"
    failures=$((failures + 1))
  fi
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

new_checkout() { # $1=name -> echoes SOURCE_PATH
  local root="$tmp/$1"
  mkdir -p "$root/packages/nicegram-assistant-ios"
  printf '%s' "$root"
}

state() { # -> "build,scratch" presence
  local b s
  [ -d "$(ng_swiftpm_build_path)" ] && b=build || b=-
  [ -d "$(ng_swiftpm_scratch_path)" ] && s=scratch || s=-
  printf '%s,%s' "$b" "$s"
}

echo "-- a .build present is moved out and STAYS out"
SOURCE_PATH="$(new_checkout wt1)"
mkdir -p "$(ng_swiftpm_build_path)/checkouts"
echo marker > "$(ng_swiftpm_build_path)/checkouts/keep.txt"
ng_evict_swiftpm_build > /dev/null
check "package is clean, scratch holds it" "-,scratch" "$(state)"
check "contents survived the move" "marker" \
  "$(cat "$(ng_swiftpm_scratch_path)/checkouts/keep.txt" 2>/dev/null)"

echo "-- the scratch is outside the bazel workspace, which is the whole point"
case "$(ng_swiftpm_scratch_path)" in
  "$SOURCE_PATH"/*) check "scratch outside SOURCE_PATH" "outside" "INSIDE" ;;
  *)                check "scratch outside SOURCE_PATH" "outside" "outside" ;;
esac

echo "-- no .build at all is a no-op, not an error"
SOURCE_PATH="$(new_checkout wt2)"
ng_evict_swiftpm_build > /dev/null
check "exit status" "0" "$?"
check "nothing invented" "-,-" "$(state)"

echo "-- a second eviction replaces a stale scratch rather than failing"
SOURCE_PATH="$(new_checkout wt3)"
mkdir -p "$(ng_swiftpm_scratch_path)"
echo stale > "$(ng_swiftpm_scratch_path)/keep.txt"
mkdir -p "$(ng_swiftpm_build_path)"
echo fresh > "$(ng_swiftpm_build_path)/keep.txt"
ng_evict_swiftpm_build > /dev/null
check "package clean again" "-,scratch" "$(state)"
check "the newer copy won" "fresh" "$(cat "$(ng_swiftpm_scratch_path)/keep.txt" 2>/dev/null)"
check "no nested leftover" "keep.txt" "$(ls "$(ng_swiftpm_scratch_path)")"

echo "-- eviction says what it did, so a surprised reader can find out why"
SOURCE_PATH="$(new_checkout wt4)"
mkdir -p "$(ng_swiftpm_build_path)"
out="$(ng_evict_swiftpm_build 2>&1)"
case "$out" in
  *"Cycle detected"*) check "explains itself" "explained" "explained" ;;
  *)                  check "explains itself" "explained" "[$out]" ;;
esac

if [ "$failures" -ne 0 ]; then
  echo ""
  echo "test-swiftpm-build: $failures check(s) failed"
  exit 1
fi
