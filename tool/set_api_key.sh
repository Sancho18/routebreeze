#!/usr/bin/env bash
# tool/set_api_key.sh - store the Google Maps API key for both platforms.
#
# Usage (from the project root):
#   tool/set_api_key.sh                      # prompts for the key (not echoed)
#   tool/set_api_key.sh <GOOGLE_MAPS_API_KEY>
#
# Prefer the prompt: a key given as an argument lands in the shell history.
#
# Writes two gitignored files (mode 600):
#   env.json                     {"GOOGLE_MAPS_API_KEY": "<KEY>"}
#                                read by --dart-define-from-file=env.json (Dart)
#                                and by the Android Gradle build (manifest placeholder)
#   ios/Flutter/Secrets.xcconfig GOOGLE_MAPS_API_KEY=<KEY>
#                                included by the iOS build (Info.plist $(GOOGLE_MAPS_API_KEY))
#
# Then run or build with:
#   flutter run --dart-define-from-file=env.json
set -euo pipefail
umask 077

if [ "$#" -gt 1 ]; then
  echo "usage: tool/set_api_key.sh [GOOGLE_MAPS_API_KEY]" >&2
  exit 1
fi

KEY="${1:-}"
if [ -z "$KEY" ]; then
  read -rs -p "GOOGLE_MAPS_API_KEY: " KEY
  echo
fi
if [ -z "$KEY" ]; then
  echo "error: empty key" >&2
  exit 1
fi
case "$KEY" in
  *'"'*|*'\'*)
    echo "error: the key cannot contain quotes or backslashes" >&2
    exit 1
    ;;
esac
if ! [[ "$KEY" =~ ^AIza[0-9A-Za-z_-]{35}$ ]]; then
  echo "warning: the key does not look like a Google API key (AIza + 35 chars); writing it anyway" >&2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

printf '{"GOOGLE_MAPS_API_KEY": "%s"}\n' "$KEY" > "$ROOT/env.json"
mkdir -p "$ROOT/ios/Flutter"
printf 'GOOGLE_MAPS_API_KEY=%s\n' "$KEY" > "$ROOT/ios/Flutter/Secrets.xcconfig"
chmod 600 "$ROOT/env.json" "$ROOT/ios/Flutter/Secrets.xcconfig"

echo "wrote env.json and ios/Flutter/Secrets.xcconfig"
