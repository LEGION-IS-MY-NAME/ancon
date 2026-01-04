#!/usr/bin/env bash

set -euo pipefail

# Helper script for local debugging. It starts the ws-scrcpy server with the
# same configuration used in the Home Assistant add-on image.

export WS_SCRCPY_CONFIG=${WS_SCRCPY_CONFIG:-/data/ws-scrcpy.yaml}
export WS_SCRCPY_PATHNAME=${WS_SCRCPY_PATHNAME:-/}

if [ ! -f "${WS_SCRCPY_CONFIG}" ]; then
  cat > "${WS_SCRCPY_CONFIG}" <<EOF
server:
  - secure: false
    port: 3000
runGoogTracker: true
announceGoogTracker: true
runApplTracker: false
announceApplTracker: false
EOF
fi

adb start-server
node /opt/ws-scrcpy/dist/index.js
