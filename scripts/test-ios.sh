#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SIMULATOR_ID=$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/{print $2; exit}')

if [[ -z "${SIMULATOR_ID:-}" ]]; then
  echo "No available iPhone simulator found. Please install one via Xcode." >&2
  exit 1
fi

# Cap CI/script timeouts at 10 minutes; guard direct local runs too.
perl -e 'alarm shift; exec @ARGV' 600 xcodebuild test \
  -scheme CapgoCapacitorVideoPlayer \
  -destination "id=${SIMULATOR_ID}" \
  "$@"
