#!/bin/bash
#
# Fixture-based tests for ci/lib/report.sh.
#
# The fixture log lines are verbatim bazel 8.4.2 output captured on 2026-08-27
# from a throwaway workspace -- including the singular "1 process:" form, which
# a naive parser written against the plural form silently misses.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/report.sh
. "$HERE/../lib/report.sh"

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

cat > "$tmp/warm.log" <<'LOG'
INFO: Analyzed target //Telegram:Telegram (412 packages loaded, 21877 targets configured).
INFO: Found 1 target...
INFO: Elapsed time: 128.451s, Critical Path: 42.10s
INFO: 12043 processes: 9877 disk cache hit, 2100 internal, 66 darwin-sandbox.
INFO: Build completed successfully, 12043 total actions
LOG

cat > "$tmp/singular.log" <<'LOG'
INFO: Analyzed target //:g (0 packages loaded, 2 targets configured).
INFO: Elapsed time: 0.079s, Critical Path: 0.00s
INFO: 1 process: 1 action cache hit, 1 internal.
INFO: Build completed successfully, 1 total action
LOG

cat > "$tmp/cold.log" <<'LOG'
INFO: Analyzed target //:g (6 packages loaded, 8 targets configured).
INFO: Elapsed time: 10.965s, Critical Path: 0.07s
INFO: 2 processes: 1 internal, 1 darwin-sandbox.
INFO: Build completed successfully, 2 total actions
LOG

cat > "$tmp/failed.log" <<'LOG'
ERROR: /some/path/BUILD:12:1: Compiling Swift module //submodules/Display failed
INFO: Elapsed time: 55.100s, Critical Path: 30.00s
LOG

# Real fastlane-wrapped bazel output, transcribed byte-for-byte from an actual
# ci/generate-project.sh capture: a "[HH:MM:SS]: " timestamp, a "▸ " marker,
# and an ANSI SGR colour escape around the INFO: text. This is what every ci/
# wrapper actually captures (`fastlane ... | tee log`), not the raw bazel
# output above -- ng_report_field must parse both shapes the same way. The
# ESC byte is built with `printf`, not written as a literal escape in this
# quoted heredoc, since a quoted heredoc does no backslash interpretation.
esc="$(printf '\033')"
marker="$(printf '\xe2\x96\xb8')"  # ▸, U+25B8
cat > "$tmp/fastlane.log" <<LOG
[14:59:26]: ${marker} ${esc}[35mINFO: Elapsed time: 12.169s, Critical Path: 0.04s${esc}[0m
[15:00:42]: ${marker} ${esc}[35mINFO: 4361 processes: 2805 disk cache hit, 225 internal, 1331 local.${esc}[0m
[15:00:42]: ${marker} ${esc}[35mINFO: Analyzed target //Telegram:Telegram (956 packages loaded, 48876 targets configured).${esc}[0m
LOG

echo "test_warm_build_fields"
check "elapsed"        "128.451" "$(ng_report_field "$tmp/warm.log" elapsed)"
check "disk hits"      "9877"    "$(ng_report_field "$tmp/warm.log" disk_cache_hits)"
check "action hits"    "0"       "$(ng_report_field "$tmp/warm.log" action_cache_hits)"
check "processes"      "12043"   "$(ng_report_field "$tmp/warm.log" processes)"
check "pkgs loaded"    "412"     "$(ng_report_field "$tmp/warm.log" packages_loaded)"
check "targets cfg"    "21877"   "$(ng_report_field "$tmp/warm.log" targets_configured)"

echo "test_fastlane_wrapped_output_is_normalized"
check "fastlane elapsed"     "12.169" "$(ng_report_field "$tmp/fastlane.log" elapsed)"
check "fastlane processes"   "4361"   "$(ng_report_field "$tmp/fastlane.log" processes)"
check "fastlane disk hits"   "2805"   "$(ng_report_field "$tmp/fastlane.log" disk_cache_hits)"
check "fastlane action hits" "0"      "$(ng_report_field "$tmp/fastlane.log" action_cache_hits)"
check "fastlane pkgs loaded" "956"    "$(ng_report_field "$tmp/fastlane.log" packages_loaded)"
check "fastlane targets cfg" "48876"  "$(ng_report_field "$tmp/fastlane.log" targets_configured)"

echo "test_singular_process_line_is_parsed"
check "singular procs" "1" "$(ng_report_field "$tmp/singular.log" processes)"
check "singular action hits" "1" "$(ng_report_field "$tmp/singular.log" action_cache_hits)"
check "singular disk hits"   "0" "$(ng_report_field "$tmp/singular.log" disk_cache_hits)"

echo "test_cold_build_has_no_cache_hits"
check "cold disk hits"   "0" "$(ng_report_field "$tmp/cold.log" disk_cache_hits)"
check "cold action hits" "0" "$(ng_report_field "$tmp/cold.log" action_cache_hits)"
check "cold procs"       "2" "$(ng_report_field "$tmp/cold.log" processes)"

echo "test_failed_build_reports_what_it_has"
check "failed elapsed" "55.100" "$(ng_report_field "$tmp/failed.log" elapsed)"
check "failed procs"   "?"      "$(ng_report_field "$tmp/failed.log" processes)"
check "failed errors"  "1"      "$(ng_report_field "$tmp/failed.log" error_lines)"

echo "test_missing_log_does_not_crash"
check "missing log" "?" "$(ng_report_field "$tmp/nope.log" elapsed)"

echo "test_summary_block_names_the_flow_but_not_the_log_path"
out="$(ng_report_from_log compile_check "$tmp/warm.log")"
case "$out" in
  *compile_check*) echo "  ok   summary names the flow" ;;
  *) echo "  FAIL summary names the flow"; failures=$((failures + 1)) ;;
esac
# It must NOT name the log. Both wrappers parse a scratch file they delete as
# they exit, so printing the path would hand the reader a path that is already
# gone -- worse than printing nothing, because it looks actionable.
case "$out" in
  *"$tmp/warm.log"*) echo "  FAIL summary leaks a log path that will not exist"; failures=$((failures + 1)) ;;
  *) echo "  ok   summary omits the log path" ;;
esac
case "$out" in
  *9877*) echo "  ok   summary shows disk cache hits" ;;
  *) echo "  FAIL summary shows disk cache hits"; failures=$((failures + 1)) ;;
esac

echo "test_output_base_from_convenience_symlink"
mkdir -p "$tmp/ws" "$tmp/ob/execroot/_main/bazel-out"
ln -s "$tmp/ob/execroot/_main/bazel-out" "$tmp/ws/bazel-out"
check "derived from symlink" "$tmp/ob" "$(ng_bazel_output_base "$tmp/ws")"

echo "test_output_base_absent_symlink_is_silent"
mkdir -p "$tmp/ws_nolink"
check "no symlink" "" "$(ng_bazel_output_base "$tmp/ws_nolink")"
ng_bazel_output_base "$tmp/ws_nolink" >/dev/null 2>&1; check "no symlink exit code" "1" "$?"

echo "test_nested_output_base_from_outer"
check "nested derived from symlink" \
  "$tmp/ob/rules_xcodeproj.noindex/build_output_base" \
  "$(ng_bazel_nested_output_base "$tmp/ws")"

echo "test_nested_output_base_absent_symlink_is_silent"
check "nested, no symlink" "" "$(ng_bazel_nested_output_base "$tmp/ws_nolink")"
ng_bazel_nested_output_base "$tmp/ws_nolink" >/dev/null 2>&1
check "nested, no symlink exit code" "1" "$?"

if [ "$failures" -ne 0 ]; then
  echo "test-report: $failures failure(s)"
  exit 1
fi
echo "test-report: all passed"
