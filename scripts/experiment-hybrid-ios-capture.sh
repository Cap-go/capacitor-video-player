#!/usr/bin/env bash
# Captures iOS Simulator evidence for hybrid-ui + hybridSlot (workflow_dispatch only).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${1:-$ROOT_DIR/docs/experiment-hybrid-ui}"
TMP_ROOT="${RUNNER_TEMP:-$(mktemp -d)}"
DERIVED="$TMP_ROOT/hybrid-derived"
SIM_VIDEO_PID=""
BUNDLE_ID="app.capgo.video.player"
MIN_MP4_BYTES=50000

cleanup() {
  if [[ -n "$SIM_VIDEO_PID" ]] && kill -0 "$SIM_VIDEO_PID" 2>/dev/null; then
    kill "$SIM_VIDEO_PID" 2>/dev/null || true
    wait "$SIM_VIDEO_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

assert_app_running() {
  local sim_id="$1"
  if ! xcrun simctl listapps "$sim_id" 2>/dev/null | grep -Fq "$BUNDLE_ID"; then
    echo "App $BUNDLE_ID is not installed on simulator $sim_id" >&2
    return 1
  fi
  local pid
  pid="$(xcrun simctl spawn "$sim_id" pgrep -lf "$BUNDLE_ID" 2>/dev/null | head -1 || true)"
  if [[ -z "$pid" ]]; then
    echo "App $BUNDLE_ID is not running (likely crashed to home screen)" >&2
    dump_recent_crashes "$sim_id"
    return 1
  fi
}

dump_recent_crashes() {
  local sim_id="$1"
  local home
  home="$(xcrun simctl get_app_container "$sim_id" "$BUNDLE_ID" 2>/dev/null || true)"
  echo "--- recent DiagnosticReports (App*) ---"
  find "$HOME/Library/Logs/DiagnosticReports" -maxdepth 1 -name 'App*.crash' -mmin -15 -print -exec tail -n 40 {} \; 2>/dev/null || true
  echo "--- simulator log (last 2m, process App) ---"
  xcrun simctl spawn "$sim_id" log show --style compact --last 2m --predicate 'process CONTAINS "App"' 2>/dev/null | tail -n 80 || true
}

assert_mp4() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Missing mp4 at $path" >&2
    return 1
  fi
  local size
  size="$(wc -c <"$path" | tr -d ' ')"
  if [[ "$size" -lt "$MIN_MP4_BYTES" ]]; then
    echo "mp4 too small ($size bytes, need at least $MIN_MP4_BYTES): $path" >&2
    return 1
  fi
}

cd "$ROOT_DIR"
bun install
bun run build

if [[ ! -d "$ROOT_DIR/example-app/node_modules/@capgo/capacitor-hybrid-ui" ]]; then
  echo "example-app is missing @capgo/capacitor-hybrid-ui; run install-hybrid-ui-peer.sh first" >&2
  exit 1
fi

cd "$ROOT_DIR/example-app"
bun install
bun run build

cat > dist/index.html <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta http-equiv="refresh" content="0; url=hybrid.html?ci=1" />
    <title>Hybrid redirect</title>
  </head>
  <body></body>
</html>
EOF

bunx cap sync ios

SIMULATOR_ID="$(
  xcrun simctl list devices available |
    awk -F '[()]' '/iPhone 16 \(/ { print $2; exit }'
)"
if [[ -z "$SIMULATOR_ID" ]]; then
  SIMULATOR_ID="$(
    xcrun simctl list devices available |
      awk -F '[()]' '/iPhone/{ print $2; exit }'
  )"
fi
if [[ -z "$SIMULATOR_ID" ]]; then
  echo "No iOS simulator found" >&2
  exit 1
fi

xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true

xcodebuild \
  -project ios/App/App.xcodeproj \
  -scheme App \
  -destination "id=$SIMULATOR_ID" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing

xcodebuild \
  -project ios/App/App.xcodeproj \
  -scheme App \
  -destination "id=$SIMULATOR_ID" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:HybridSlotUITests \
  test-without-building

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/App.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found at $APP_PATH" >&2
  exit 1
fi

xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" 2>/dev/null || true

mkdir -p "$ARTIFACT_DIR"
VIDEO_PATH="$ARTIFACT_DIR/sim-ios-scroll.mov"
xcrun simctl io "$SIMULATOR_ID" recordVideo "$VIDEO_PATH" &
SIM_VIDEO_PID=$!

xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"
sleep 4
assert_app_running "$SIMULATOR_ID"
xcrun simctl io "$SIMULATOR_ID" screenshot "$ARTIFACT_DIR/sim-ios-unscrolled.png"
sleep 4
assert_app_running "$SIMULATOR_ID"
xcrun simctl io "$SIMULATOR_ID" screenshot "$ARTIFACT_DIR/sim-ios-scrolled.png"

if [[ -n "$SIM_VIDEO_PID" ]]; then
  kill -INT "$SIM_VIDEO_PID" 2>/dev/null || true
  wait "$SIM_VIDEO_PID" 2>/dev/null || true
  SIM_VIDEO_PID=""
fi

MP4_PATH="$ARTIFACT_DIR/sim-ios-scroll.mp4"
if command -v ffmpeg >/dev/null 2>&1 && [[ -f "$VIDEO_PATH" ]]; then
  ffmpeg -y -i "$VIDEO_PATH" -c:v libx264 -pix_fmt yuv420p "$MP4_PATH" 2>/dev/null || true
fi
assert_mp4 "$MP4_PATH"

echo "Wrote simulator captures under $ARTIFACT_DIR"
