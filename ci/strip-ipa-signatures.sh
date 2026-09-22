#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <input.ipa> <output.ipa>" >&2
  exit 64
fi

input_ipa="$1"
output_ipa="$2"
work_directory="$(mktemp -d "$(dirname "$output_ipa")/unsigned-ipa.XXXXXX")"

ditto -x -k "$input_ipa" "$work_directory"

# Remove nested signatures deepest-first so the caller can sign every bundle afresh.
while IFS= read -r -d '' bundle; do
  codesign --remove-signature "$bundle" || true
done < <(find "$work_directory/Payload" -depth -type d \( -name '*.app' -o -name '*.appex' -o -name '*.framework' -o -name '*.xpc' \) -print0)

find "$work_directory/Payload" -type d -name _CodeSignature -prune -exec rm -rf {} +
find "$work_directory/Payload" -type f -name embedded.mobileprovision -delete

rm -f "$output_ipa"
ditto -c -k --keepParent --norsrc --noextattr "$work_directory/Payload" "$output_ipa"
