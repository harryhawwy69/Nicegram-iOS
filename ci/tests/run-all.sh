#!/bin/bash
#
# Runs every ci/tests/test-*.sh. Exits non-zero if any fails.
#
# There is no test framework in this repo and no dependency to install: these
# are plain bash scripts asserting on fixture directories and fixture log files.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures=0

for t in "$HERE"/test-*.sh; do
  [ -f "$t" ] || continue
  echo "== $(basename "$t")"
  if ! bash "$t"; then
    failures=$((failures + 1))
  fi
done

if [ "$failures" -ne 0 ]; then
  echo ""
  echo "run-all: $failures test file(s) failed"
  exit 1
fi
echo ""
echo "run-all: all test files passed"
