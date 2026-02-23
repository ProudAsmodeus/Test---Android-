# SecureConnectionGuard

Built-in ROM security app for connection oversight and rule enforcement.

## Features

- Lists recent connection entries captured by the guard service
- Attempts active socket snapshot listing from `/proc/net/*`
- Stores destination block rules persistently (SharedPreferences)
- Enforces destination rules via system backend (iptables) when available
- Falls back to local VPN routing + packet drop when system backend is unavailable
- Restores protection on boot if previously enabled
- Colors each detected connection by severity:
  - Green: low risk
  - Orange: medium risk (sketchy source app or risk-watchlist country)
  - Red: high risk (blocked or combined risk signals)
- Separate "Security News" section with Android app vulnerability/attack feed
- Hourly automatic news updates through scheduled background receiver

## Rule format

- `198.51.100.42`
- `203.0.113.0/24`

## Notes

- The app is intended as an on-device control plane for defensive blocking.
- It complements (not replaces) release-time security controls in
  `scripts/security/*`.
- System backend success depends on device policy/SELinux allowing iptables
  commands from the privileged app context.
