# SecureConnectionGuard

Built-in ROM security app for connection oversight and rule enforcement.

## Features

- Lists recent connection entries captured by the guard service
- Attempts active socket snapshot listing from `/proc/net/*`
- Stores destination block rules persistently (SharedPreferences)
- Enforces destination rules via local VPN routing + packet drop
- Restores protection on boot if previously enabled

## Rule format

- `198.51.100.42`
- `203.0.113.0/24`

## Notes

- The app is intended as an on-device control plane for defensive blocking.
- It complements (not replaces) release-time security controls in
  `scripts/security/*`.
