#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SIMULATOR_ID=$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/{print $2; exit}')

if [[ -z "${SIMULATOR_ID:-}" ]]; then
  echo "No available iPhone simulator found. Please install one via Xcode." >&2
  exit 1
fi

DESTINATION="id=${SIMULATOR_ID}"
SCHEME="CapgoCapacitorVideoPlayer"

run_with_timeout() {
  local timeout_seconds=$1
  shift
  local timed_out_file
  timed_out_file=$(mktemp -u "${TMPDIR:-/tmp}/test-ios-timeout.XXXXXX")

  set +e
  (
    set -m
    "$@" &
    local pid=$!
    (
      sleep "$timeout_seconds"
      if kill -0 "$pid" 2>/dev/null; then
        echo "error: xcodebuild timed out after ${timeout_seconds}s" >&2
        : >"$timed_out_file"
        kill -TERM -"$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
        sleep 2
        kill -KILL -"$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null
      fi
    ) &
    local watchdog=$!
    wait "$pid"
    local status=$?
    kill "$watchdog" 2>/dev/null || true
    wait "$watchdog" 2>/dev/null || true
    exit "$status"
  )
  local status=$?
  set -e

  if [[ -f "$timed_out_file" ]]; then
    rm -f "$timed_out_file"
    return 124
  fi
  rm -f "$timed_out_file"
  return "$status"
}

run_with_timeout 600 xcodebuild build-for-testing -scheme "$SCHEME" -destination "$DESTINATION"
run_with_timeout 600 xcodebuild test-without-building -scheme "$SCHEME" -destination "$DESTINATION" "$@"
