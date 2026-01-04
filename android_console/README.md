# Android Console (USB scrcpy)

Stream and control Android devices connected via USB through Home Assistant’s Ingress UI. This add-on wraps [ws-scrcpy](https://github.com/NetrisTV/ws-scrcpy) behind an ingress-locked nginx proxy so no host ports are exposed.

- ✅ USB adb server inside the add-on container
- ✅ Ingress-only access with a hard IP allowlist (`172.30.32.2`)
- ✅ WebSocket-friendly proxy that strips the Ingress path prefix
- ✅ First-run logs remind you to enable and authorize USB debugging

Read the full guide in [DOCS.md](DOCS.md).
