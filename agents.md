# agents.md — Home Assistant Add-on: “Android Console (USB scrcpy via Ingress)”

## Mission
Build a Home Assistant add-on installable via a custom add-on repository URL that:
1) Detects Android devices connected via USB to the HA host
2) Streams the device screen to the browser with low latency
3) Sends mouse/keyboard/touch input back to the device (scrcpy-style control)
4) Is accessible inside Home Assistant UI via Ingress + sidebar panel (no port-forwarding)

Primary MVP backend: NetrisTV/ws-scrcpy
Secondary (follow-up) backend option: gjovanov/scws

## Non-negotiables / Constraints
- Use HA Ingress (ingress: true). No exposed host ports.
- Enforce Ingress IP allowlist: ONLY allow 172.30.32.2, deny all others.
- Add-on must request USB mapping (usb: true) so ADB can reach /dev/bus/usb.
- Web UI must work under an arbitrary Ingress base path (X-Ingress-Path header exists; don’t assume “/”).
- WebSockets must work through the proxy path.

## Acceptance Criteria (MVP)
- Add repo URL in HA → add-on appears → installs → starts.
- “Open Web UI” opens an embedded panel; sidebar entry exists.
- UI shows a device picker with adb serial(s); when 1 device exists it can autoselect.
- Clicking “Connect” shows live video; clicking/tapping inside the view injects input.
- If device unplugged/replugged, UI can reconnect without restarting HA.
- First-run: logs clearly instruct user to enable USB debugging and accept RSA prompt on device.

## Architecture Overview
HA Supervisor
  └─ Add-on container
      ├─ adb server (platform-tools)
      ├─ scrcpy-over-ws backend (MVP: ws-scrcpy)
      ├─ UI static assets (served behind Ingress)
      └─ ingress gateway guard (nginx allow/deny 172.30.32.2 + reverse proxy)

Ingress requirement note:
- Only allow connections from 172.30.32.2; deny all others.
- Ingress supports WebSockets.
(Implement with nginx in front of the Node app.)

## Repo Layout (target)
repo-root/
  repository.yaml
  README.md
  android_console/
    config.yaml
    build.yaml
    Dockerfile
    run.sh
    ingress.conf
    DOCS.md
    translations/en.yaml
    rootfs/
      etc/
        services.d/
          nginx/
            run
          app/
            run
      usr/local/bin/
        entrypoint.sh

## Step 0 — Bootstrap from HA template
- Start from home-assistant/addons-example (as reference for repository.yaml + add-on folder structure).
- Ensure repository.yaml exists at repo root with name/url/maintainer fields.

## Step 1 — Add-on metadata: config.yaml
Implement android_console/config.yaml with:
- name/version/slug/description/arch
- ingress: true
- ingress_port: 8099
- panel_title + panel_icon (e.g., mdi:cellphone-link)
- usb: true
- udev: true (optional but helpful for device enumeration stability)
- init: true (default) unless you replace with your own init
- options/schema:
    device_serial: str?   (optional; default null = auto)
    max_size: int?        (e.g., 1280)
    bitrate: int?         (Mbps or bits/sec depending on backend)
    fps: int?             (e.g., 30)
    stay_awake: bool      (default true; adb shell svc power stayon true/false)
    autoconnect: bool     (default true if exactly one device)
    log_level: list/info/debug

## Step 2 — Ingress guard: nginx
Create ingress.conf that:
- listens on 8099
- allow 172.30.32.2; deny all
- serves / as reverse proxy to the app backend on 127.0.0.1:PORT
- correctly proxies WebSockets (Upgrade/Connection headers)
- preserves X-Ingress-Path behavior: ensure app works when mounted under a subpath
  - simplest: set `proxy_set_header X-Ingress-Path $http_x_ingress_path;`

## Step 3 — Choose backend approach (MVP)
### MVP backend: ws-scrcpy
Source: https://github.com/NetrisTV/ws-scrcpy

Implementation approach:
- Vendor ws-scrcpy into the add-on image during build (git clone at a pinned tag/commit).
- Build UI assets at image build time (npm ci + npm run build if available).
- Run the ws-scrcpy server on localhost (e.g., 3000) behind nginx.

Notes:
- ws-scrcpy expects `adb` available in PATH. Ensure Android platform-tools are installed.
- If ws-scrcpy hardcodes assumptions about root paths, patch to respect a basePath:
  - Read X-Ingress-Path, set publicPath for bundles, and configure WS endpoint URLs relative to that base.
  - If easiest: have nginx rewrite the Ingress path prefix away before proxying to the Node app.

### Alternative backend: scws (post-MVP)
Source: https://github.com/gjovanov/scws
- Evaluate replacing ws-scrcpy after HA wrapper is proven.
- Keep interface contract identical: /api/devices, /ws/session, etc.

## Step 4 — Device management layer (thin wrapper)
Add a small “manager” module (Node or shell) that provides:
- `adb start-server`
- `adb devices -l` parsing
- optional “set stay-awake” toggle
- stable selection by serial

Expose to frontend via HTTP endpoints proxied by nginx:
- GET /api/devices → [{serial, model, device, transport_id, state}]
- POST /api/connect {serial?} → returns session id / or triggers ws-scrcpy to bind session
- POST /api/disconnect {serial?}

If ws-scrcpy already has its own device selection UI:
- keep it, but still add /api/devices endpoint for future HA-friendly UI polish.

## Step 5 — Dockerfile / build.yaml
### Base image choice
- Prefer Debian-based HA community base images if native modules are painful to compile on Alpine.
- Otherwise, use BUILD_FROM default and install nodejs/npm + build toolchain.

Must install:
- android-tools/adb (platform-tools)
- nodejs + npm (or node from nodesource)
- build-essential/python3 for node-gyp native deps (ws-scrcpy uses node-gyp)

### build.yaml
- Define build_from per arch if needed (amd64/aarch64/armv7).
- Keep versions pinned; avoid floating “latest” unless unavoidable.

## Step 6 — Process supervision (S6)
Run two services:
1) app service (Node): starts adb server, starts ws-scrcpy server on localhost
2) nginx service: binds 0.0.0.0:8099, allow/deny 172.30.32.2, proxies to app

Ensure clean shutdown:
- stop Node
- stop adb server (adb kill-server) (optional)

## Step 7 — Ingress path correctness (hard requirement)
Ingress mounts the UI under a prefix path. Implement one of:

A) nginx rewrite strategy (preferred):
- If request comes in as /<ingress-prefix>/..., strip the prefix before proxying to Node.
- Also rewrite websocket paths similarly.
- Ensure relative asset URLs work (serve with relative paths; avoid absolute /static/...).

B) Node basePath awareness:
- Read X-Ingress-Path and set router base accordingly.

Pick A for fastest MVP; document it in DOCS.md.

## Step 8 — Documentation (DOCS.md)
Include:
- How to enable Android Developer Options + USB Debugging
- First-time RSA prompt acceptance (must be done on-device)
- Tips: use a good USB cable; disable “Charge only” USB mode if needed
- Add-on options meanings (bitrate/fps/max_size)
- Troubleshooting: “no devices found”, “unauthorized”, “offline”

## Step 9 — Testing Plan
Local dev:
- Use HA add-on local testing guidance (devcontainer optional).
- Validate on amd64 first.
Runtime tests:
- Plug device → verify it appears in `adb devices -l` inside container.
- Open UI in HA → connect → video + input works.
- Validate Ingress-only: no host port exposed; direct LAN access to add-on blocked (deny all but 172.30.32.2).
- Replug device; ensure reconnect works.

## Deliverables Checklist
- [ ] repository.yaml at repo root
- [ ] android_console/ add-on folder with required files
- [ ] Ingress-secured nginx proxy with WS support
- [ ] ADB USB mapping enabled (usb: true)
- [ ] UI reachable via HA sidebar panel
- [ ] README + DOCS with clear setup/troubleshooting
- [ ] Pinned upstream commit/tag for ws-scrcpy (record in DOCS)

## Implementation Notes / Gotchas
- ADB over USB requires /dev/bus/usb mapped + sometimes udev DB mounted for stable device node handling.
- Some Android builds require extra dev setting to allow full input control over adb.
- Expect to patch frontend asset paths for Ingress; treat base path as variable always.
