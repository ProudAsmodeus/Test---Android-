# AdGuardControl

Built-in ROM app that controls Android Private DNS modes for AdGuard endpoints
from both app UI and Quick Settings tiles.

## Included tiles

- `AdGuard Free` (toggle `dns.adguard-dns.com`)
- `AdGuard Paid` (toggle your configured paid/personal endpoint host)

## Behavior

- Tap tile when off: enable corresponding AdGuard DNS mode
- Tap tile when on: disable Private DNS filtering (set mode off)
- Configure paid endpoint in app (`AdGuard Control`) before using paid tile

## Note

This app provides DNS endpoint control for free/paid AdGuard DNS usage. It does
not bundle proprietary paid AdGuard app binaries.
