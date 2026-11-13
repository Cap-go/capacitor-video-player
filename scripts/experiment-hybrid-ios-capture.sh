#!/usr/bin/env bash
# Captures iOS Simulator evidence for hybrid-ui + hybridSlot (CI or workflow_dispatch).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/docs/experiment-hybrid-ui"
ARTIFACT_DIR="${1:-$OUT_DIR}"
TMP_ROOT="${RUNNER_TEMP:-$(mktemp -d)}"
DERIVED="$TMP_ROOT/hybrid-derived"
SIM_VIDEO_PID=""

cleanup() {
  if [[ -n "$SIM_VIDEO_PID" ]] && kill -0 "$SIM_VIDEO_PID" 2>/dev/null; then
    kill "$SIM_VIDEO_PID" 2>/dev/null || true
    wait "$SIM_VIDEO_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

cd "$ROOT_DIR"
bun install
bun run build
(
  cd "$ROOT_DIR/vendor/capacitor-hybrid-ui"
  bun install
  bun run build
)
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
  build

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/App.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found at $APP_PATH" >&2
  exit 1
fi

xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
xcrun simctl terminate "$SIMULATOR_ID" app.capgo.video.player 2>/dev/null || true

mkdir -p "$ARTIFACT_DIR"
VIDEO_PATH="$ARTIFACT_DIR/sim-ios-scroll.mov"
xcrun simctl io "$SIMULATOR_ID" recordVideo "$VIDEO_PATH" &
SIM_VIDEO_PID=$!

xcrun simctl launch "$SIMULATOR_ID" app.capgo.video.player
sleep 5
xcrun simctl io "$SIMULATOR_ID" screenshot "$ARTIFACT_DIR/sim-ios-unscrolled.png"
sleep 5
xcrun simctl io "$SIMULATOR_ID" screenshot "$ARTIFACT_DIR/sim-ios-scrolled.png"

if [[ -n "$SIM_VIDEO_PID" ]]; then
  kill -INT "$SIM_VIDEO_PID" 2>/dev/null || true
  wait "$SIM_VIDEO_PID" 2>/dev/null || true
  SIM_VIDEO_PID=""
fi

if command -v ffmpeg >/dev/null 2>&1 && [[ -f "$VIDEO_PATH" ]]; then
  ffmpeg -y -i "$VIDEO_PATH" -c:v libx264 -pix_fmt yuv420p "$ARTIFACT_DIR/sim-ios-scroll.mp4" >/dev/null 2>&1 || true
fi

echo "Wrote simulator captures under $ARTIFACT_DIR"
