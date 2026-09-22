#!/usr/bin/env bash
# tool/set_api_key.sh - store the Google Maps API key for both platforms.
#
# Usage (from the project root):
#   tool/set_api_key.sh <GOOGLE_MAPS_API_KEY>
#
# Writes two gitignored files:
#   env.json                     {"GOOGLE_MAPS_API_KEY": "<KEY>"}
#                                read by --dart-define-from-file=env.json (Dart)
#                                and by the Android Gradle build (manifest placeholder)
#   ios/Flutter/Secrets.xcconfig GOOGLE_MAPS_API_KEY=<KEY>
#                                included by the iOS build (Info.plist $(GOOGLE_MAPS_API_KEY))
#
# Then run or build with:
#   flutter run --dart-define-from-file=env.json
set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "usage: tool/set_api_key.sh <GOOGLE_MAPS_API_KEY>" >&2
  exit 1
fi

KEY="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

printf '{"GOOGLE_MAPS_API_KEY": "%s"}\n' "$KEY" > "$ROOT/env.json"
mkdir -p "$ROOT/ios/Flutter"
printf 'GOOGLE_MAPS_API_KEY=%s\n' "$KEY" > "$ROOT/ios/Flutter/Secrets.xcconfig"

echo "wrote env.json and ios/Flutter/Secrets.xcconfig"
