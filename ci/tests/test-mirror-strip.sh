#!/bin/bash
#
# The mirror strips fork-internal trees before pushing to the public GitHub
# repo, in two places that must agree: the `rm -rf` that deletes them and the
# staged-path grep that fails the build if one is staged anyway. This test
# reads both lists out of bitbucket-pipelines.yml and asserts they describe the
# same set -- a divergence there is silent, and the symptom is a fork-internal
# tree quietly reaching the public mirror.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YML="$HERE/../../bitbucket-pipelines.yml"

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

# The `rm -rf` line inside the push-to-github-repo step's script list -- the
# one beginning `- rm -rf .claude`. bitbucket-pipelines.yml has two other
# `rm -rf` lines (`git rm -rf .` and a bare `rm -rf .git`, both earlier in the
# same step, clearing the freshly-cloned mirror checkout before the copy);
# anchoring on the `.claude` prefix keeps this from picking either of those up.
strip_set="$(sed -n 's/^[[:space:]]*-[[:space:]]*rm -rf \(\.claude .*\)$/\1/p' "$YML" \
  | tr ' ' '\n' | sed '/^$/d' | sort | tr '\n' ' ' | sed 's/ $//')"

# The guard's ERE, e.g. ^(\.claude|docs/superpowers|docs/tg-merge|docs/changes)/
guard_ere="$(sed -n "s/.*grep -qE '\(.*\)'.*/\1/p" "$YML" | head -1)"
guard_set="$(printf '%s' "$guard_ere" \
  | sed -e 's/^\^(//' -e 's/)\/$//' -e 's/\\//g' \
  | tr '|' '\n' | sort | tr '\n' ' ' | sed 's/ $//')"

check "rm -rf lists docs/changes" \
  "yes" "$(printf '%s' "$strip_set" | grep -qw 'docs/changes' && echo yes || echo no)"

check "guard and rm -rf describe the same set" "$strip_set" "$guard_set"

# The comment above the `rm -rf` explains why the tree is stripped, and no other
# check reads it -- so a rename that updates both lists and leaves the comment
# behind would pass everything above. Asserting the old path appears NOWHERE in
# the file covers the comment without having to parse it. `grep -c` prints 0 and
# exits 1 on no match; the exit code is discarded by `$( )`, the 0 is what we
# compare. A missing $YML prints nothing, so `actual` is empty and this FAILS.
check "no docs/qa reference survives anywhere in the yml" \
  "0" "$(grep -c 'docs/qa' "$YML")"

# The guard must actually match a change record, and must not match a source file.
matches() { printf '%s\n' "$2" | grep -qE "$1" && echo yes || echo no; }
check "guard matches a change record"   "yes" "$(matches "$guard_ere" 'docs/changes/2026-08-31-x.md')"
check "guard matches a superpowers doc" "yes" "$(matches "$guard_ere" 'docs/superpowers/specs/x.md')"
check "guard ignores a kept doc"        "no"  "$(matches "$guard_ere" 'docs/ui-testing.md')"
check "guard ignores source"            "no"  "$(matches "$guard_ere" 'submodules/Display/Source/ListView.swift')"

if [ "$failures" -ne 0 ]; then
  echo "test-mirror-strip: $failures failure(s)"
  exit 1
fi
echo "test-mirror-strip: all passed"
