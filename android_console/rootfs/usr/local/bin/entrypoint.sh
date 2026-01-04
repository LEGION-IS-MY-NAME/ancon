#!/usr/bin/with-contenv bash

set -euo pipefail

OPTIONS_FILE="/data/options.json"
CONFIG_PATH="/data/ws-scrcpy.yaml"

log() {
    echo "[entrypoint] $*"
}

get_option() {
    local key=$1 default=$2 value
    if [ -f "${OPTIONS_FILE}" ]; then
        value=$(jq -er --arg key "${key}" 'if has($key) and .[$key] != null then .[$key] else empty end' "${OPTIONS_FILE}" 2>/dev/null || true)
        if [ -n "${value}" ]; then
            echo "${value}"
            return
        fi
    fi
    echo "${default}"
}

LOG_LEVEL=$(get_option "log_level" "info")
STAY_AWAKE=$(get_option "stay_awake" "true")
DEVICE_SERIAL=$(get_option "device_serial" "")
MAX_SIZE=$(get_option "max_size" "1280")
BITRATE=$(get_option "bitrate" "8000000")
FPS=$(get_option "fps" "30")
AUTOCONNECT=$(get_option "autoconnect" "true")

cat > "${CONFIG_PATH}" <<EOF
server:
  - secure: false
    port: 3000
runGoogTracker: true
announceGoogTracker: true
runApplTracker: false
announceApplTracker: false
EOF

export WS_SCRCPY_CONFIG="${CONFIG_PATH}"
export WS_SCRCPY_PATHNAME="/"
export WS_SCRCPY_DEFAULT_MAX_SIZE="${MAX_SIZE}"
export WS_SCRCPY_DEFAULT_BITRATE="${BITRATE}"
export WS_SCRCPY_DEFAULT_FPS="${FPS}"
export WS_SCRCPY_AUTOCONNECT="${AUTOCONNECT}"
export ADB_VENDOR_KEYS="/config/adb/adbkey"

if [ "${LOG_LEVEL}" = "debug" ]; then
    export ADB_TRACE=all
fi

log "Starting adb server"
adb start-server

log "Connected Android devices:"
adb devices -l || true

if [ "${STAY_AWAKE}" = "true" ] && [ -n "${DEVICE_SERIAL}" ]; then
    log "Requesting stay-awake on device ${DEVICE_SERIAL}"
    adb -s "${DEVICE_SERIAL}" shell svc power stayon true || log "Unable to enable stay-awake on ${DEVICE_SERIAL}"
fi

log "If no devices appear above, confirm USB debugging is enabled and authorize the host when prompted."
log "Client defaults -> max_size=${MAX_SIZE}, bitrate=${BITRATE}, fps=${FPS}, autoconnect=${AUTOCONNECT}"

exec node /opt/ws-scrcpy/dist/index.js
