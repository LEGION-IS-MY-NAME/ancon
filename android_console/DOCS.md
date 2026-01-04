# Android Console (USB scrcpy) Add-on

## Overview
The Android Console add-on streams and controls Android devices connected over USB directly inside Home Assistant via Ingress. It bundles the ws-scrcpy project (commit `2bde541263d7186a906f9efea008daffe58d7f52`) behind an ingress-locked nginx proxy so the UI is available from the Home Assistant sidebar without exposing host ports.

## Prerequisites
- Home Assistant OS/Supervised with USB access.
- Android device with **Developer Options** and **USB debugging** enabled.
- A high-quality USB data cable (avoid charge-only cables).
- The device must authorize the Home Assistant host when prompted on first connect.

## Installation
1. Add this repository URL to **Settings → Add-ons → Add-on store → ⋮ → Repositories**.
2. Install **Android Console (USB scrcpy)** from the list.
3. Enable “Show in sidebar” if desired.
4. Start the add-on. First-run logs will remind you to authorize USB debugging.
5. Click **Open Web UI**. The UI loads inside Home Assistant via Ingress; no host ports are exposed.

## Options
| Option | Default | Purpose |
| --- | --- | --- |
| `device_serial` | `null` | Preferred device serial for stay-awake toggling. |
| `max_size` | `1280` | Suggested maximum stream size (forwarded to clients). |
| `bitrate` | `8000000` | Suggested default bitrate in bps. |
| `fps` | `30` | Suggested default frames per second. |
| `stay_awake` | `true` | If a serial is provided, the add-on runs `adb shell svc power stayon true` at startup. |
| `autoconnect` | `true` | Allows future autoconnect behavior (UI already auto-selects when only one device exists). |
| `log_level` | `info` | `debug` enables verbose adb tracing. |

> Notes:
> - The ws-scrcpy UI already includes bitrate/FPS controls; the options above seed defaults for client behaviors and startup helpers.
> - ADB vendor keys are read from `/config/adb/adbkey` when present.

## How it works
- **Ingress gateway:** nginx listens on 8099, allows only `172.30.32.2`, and strips the Ingress path before proxying to the Node service at `127.0.0.1:3000`. WebSockets are forwarded with the required Upgrade/Connection headers.
- **Backend:** ws-scrcpy serves the UI and connects to the adb server running inside the container.
- **Device handling:** On start, the add-on launches `adb start-server`, lists devices in the logs, and optionally enables stay-awake on the configured serial.

## Troubleshooting
- **No devices listed:** Confirm the cable supports data, USB debugging is enabled, and the device shows as “authorized” in `adb devices -l` (view add-on logs). Replugging the device should make it reappear without restarting the add-on.
- **Black screen or lag:** Lower the bitrate/FPS in the UI, or reduce `max_size`.
- **Ingress errors:** Ensure you launch the UI via Home Assistant’s “Open Web UI”/sidebar entry; direct host access is blocked by design.
- **RSA prompt didn’t appear:** Unlock the device, plug it in again, and watch for the “Allow USB debugging” dialog.

## Build details
- Base image: Home Assistant Debian base (`bookworm`) per architecture.
- Included packages: `android-tools-adb`, `nodejs`, `npm`, `nginx`, build essentials.
- ws-scrcpy built at commit `2bde541263d7186a906f9efea008daffe58d7f52` using `npm ci` and `npm run dist`.

