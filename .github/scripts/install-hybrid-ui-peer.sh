#!/usr/bin/env bash
set -euo pipefail

# Installs optional @capgo/capacitor-hybrid-ui into example-app using a shallow clone
# of the private Cap-go/hybrid-ui repo (CI only, never committed).
if [[ -z "${HYBRID_UI_INSTALL_TOKEN:-}" ]]; then
  echo "HYBRID_UI_INSTALL_TOKEN is required to install the hybrid-ui peer for example builds" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmpdir="${RUNNER_TEMP:-/tmp}/hybrid-ui-install"
rm -rf "$tmpdir"
mkdir -p "$tmpdir"

git -c http.extraHeader="AUTHORIZATION: bearer ${HYBRID_UI_INSTALL_TOKEN}" \
  clone --depth 1 https://github.com/Cap-go/hybrid-ui.git "$tmpdir/hybrid-ui"

cd "$repo_root/example-app"
bun add "@capgo/capacitor-hybrid-ui@file:${tmpdir}/hybrid-ui"
