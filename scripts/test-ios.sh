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
SCRIPT_TIMEOUT_SECONDS=600
DEADLINE=$((SECONDS + SCRIPT_TIMEOUT_SECONDS))

BUILD_ARGS=()
TEST_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -only-testing|-skip-testing|-resultBundlePath)
      TEST_ARGS+=("$1")
      shift
      if [[ $# -gt 0 ]]; then
        TEST_ARGS+=("$1")
        shift
      fi
      ;;
    -testPlan)
      BUILD_ARGS+=("$1")
      TEST_ARGS+=("$1")
      shift
      if [[ $# -gt 0 ]]; then
        BUILD_ARGS+=("$1")
        TEST_ARGS+=("$1")
        shift
      fi
      ;;
    -only-testing:*|-skip-testing:*|-resultBundlePath=*)
      TEST_ARGS+=("$1")
      shift
      ;;
    -testPlan=*)
      BUILD_ARGS+=("$1")
      TEST_ARGS+=("$1")
      shift
      ;;
    *)
      BUILD_ARGS+=("$1")
      TEST_ARGS+=("$1")
      shift
      ;;
  esac
done

timeout_dir=$(mktemp -d "${TMPDIR:-/tmp}/test-ios-timeout.XXXXXX")
timeout_marker="${timeout_dir}/timed-out"
trap 'rm -rf "$timeout_dir"' EXIT

run_with_timeout() {
  local remaining=$((DEADLINE - SECONDS))
  if [[ "$remaining" -le 0 ]]; then
    echo "error: xcodebuild timed out after ${SCRIPT_TIMEOUT_SECONDS}s" >&2
    : >"$timeout_marker"
    return 124
  fi

  set +e
  (
    set -m
    "$@" &
    local pid=$!
    (
      sleep "$remaining"
      if kill -0 "$pid" 2>/dev/null; then
        echo "error: xcodebuild timed out after ${SCRIPT_TIMEOUT_SECONDS}s" >&2
        : >"$timeout_marker"
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

  if [[ -f "$timeout_marker" ]]; then
    return 124
  fi
  return "$status"
}

run_with_timeout xcodebuild build-for-testing \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  "${BUILD_ARGS[@]}"

run_with_timeout xcodebuild test-without-building \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  "${TEST_ARGS[@]}"
