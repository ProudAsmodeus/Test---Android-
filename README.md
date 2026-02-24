# Android ROM Base (Newest Android)

This repository provides a starter base for building a custom Android ROM on top
of the newest AOSP release branch.

## What this includes

- A bootstrap script to initialize and sync AOSP from
  `android-latest-release` (default)
- A local manifest template for adding your device/kernel/vendor repos
- Base ROM product + config makefiles under `vendor/rom`
- Samsung Galaxy A53 5G (`SM-A536B/DS`) **dedicated** starter skeleton:
  - `device/samsung/a536b_ds`
  - `vendor/samsung/a536b_ds`
  - Includes `aosp_a536b_ds` lunch target (SKU: `SM-A536B/DS`)
- Security baseline tooling:
  - `vendor/rom/config/security_hardening.mk`
  - `vendor/rom/config/optimization.mk`
  - `scripts/security/sync_latest_security_patches.sh`
  - `scripts/security/verify_release_security.sh`
  - `scripts/security/release_gate.sh`
  - `scripts/security/package_secure_ota.sh`
  - `scripts/security/check_kernel_hardening_config.sh`
- Feature-readiness tooling:
  - `scripts/qa/validate_feature_readiness.sh`
  - `scripts/qa/run_device_acceptance_suite.sh`
- Camera parity tooling:
  - `scripts/camera/integrate_samsung_camera.sh`
  - `docs/camera-stock-parity.md`
- Built-in security app:
  - `packages/apps/SecureConnectionGuard`
- Built-in DNS control app:
  - `packages/apps/AdGuardControl`

## Quick start

1. Create a workspace directory for your full source tree:

   ```bash
   mkdir -p ~/android/rom
   cd ~/android/rom
   ```

2. Run the bootstrap script from this repository:

   ```bash
   bash /path/to/this/repo/scripts/bootstrap_rom_base.sh ~/android/rom
   ```

   Optional environment variables:

   - `AOSP_BRANCH` (default: `android-latest-release`)
   - `AOSP_MANIFEST_URL` (default: `https://android.googlesource.com/platform/manifest`)
   - `ROM_NAME` (default: `BaseROM`)
   - `ROM_VERSION` (default: `0.1.0`)
   - `SKIP_SYNC=1` to skip `repo sync`

3. Enter the synced tree and build:

   ```bash
   source build/envsetup.sh
   lunch aosp_a536b_ds-user
   m -j$(nproc)
   ```

   For bring-up debugging only:

   ```bash
   lunch aosp_a536b_ds-userdebug
   ```

## Important notes

- This is a **base scaffold**. You still need device-specific trees and
  proprietary blobs for your hardware target.
- Edit `.repo/local_manifests/rom-base.xml` with your actual repositories.
- Replace or extend `vendor/rom` configs to match your ROM branding/features.
- Update placeholder values in
  `device/samsung/a536b_ds/BoardConfig.mk` before attempting a full
  device bring-up.
- Product code `SM-A536B/DS` is stored as a reference input. Confirm additional
  hardware identifiers from stock firmware before finalizing kernel and
  modem/radio config.
- "Smooth, optimized, clean" is addressed with conservative runtime defaults in
  `vendor/rom/config/optimization.mk`.
- "Everything works" (calls/SMS/5G/cameras) must be validated with both:
  - source-tree readiness checks
  - real-device acceptance tests
- "Samsung-like camera behavior/processing" requires stock camera app +
  matching proprietary camera processing stack from stock firmware.

## Security update workflow

After bootstrap, run these commands from your AOSP tree root.

1. Sync latest upstream patches (including newest Android security updates):

   ```bash
   bash scripts/security/sync_latest_security_patches.sh /path/to/aosp/tree
   ```

2. Verify release build posture:

   ```bash
   bash scripts/security/verify_release_security.sh \
     out/target/product/a536b_ds
   ```

3. Block OTA packaging unless release/security checks pass:

   ```bash
   RELEASE_GATE_MODE=presign bash scripts/security/release_gate.sh \
     out/target/product/a536b_ds \
     out/dist/aosp_a536b_ds-target_files-unsigned.zip \
     /path/to/release-keys
   ```

   Note:
   - `presign` mode is for unsigned target-files checks
   - default strict mode is for signed target-files checks

   Optional key-set override for branches with fewer key aliases:

   ```bash
   REQUIRED_KEYS="releasekey,platform,shared,media" \
   bash scripts/security/release_gate.sh \
     out/target/product/a536b_ds \
     out/dist/aosp_a536b_ds-target_files-unsigned.zip \
     /path/to/release-keys
   ```

4. Package signed OTA only after gate passes:

   ```bash
   bash scripts/security/package_secure_ota.sh \
     /path/to/aosp/tree \
     out/target/product/a536b_ds \
     out/dist/aosp_a536b_ds-target_files-unsigned.zip \
     /path/to/release-keys \
     out/dist/aosp_a536b_ds-ota-signed.zip
   ```

5. Review detailed policy:

   - `docs/security-baseline.md`
   - `docs/feature-readiness.md`
   - `docs/camera-stock-parity.md`

6. Optional kernel hardening audit:

   ```bash
   bash scripts/security/check_kernel_hardening_config.sh \
     /path/to/kernel/.config
   ```

7. Validate source-tree feature completeness:

   ```bash
   bash scripts/qa/validate_feature_readiness.sh /path/to/aosp/tree
   ```

8. Run real-device acceptance checks after flashing:

   ```bash
   bash scripts/qa/run_device_acceptance_suite.sh
   ```

9. Bootstrap stock camera app + candidate processing blobs:

   ```bash
   bash scripts/camera/integrate_samsung_camera.sh /path/to/aosp/tree /path/to/stock_dump
   ```

## Built-in connection firewall app

`Secure Connection Guard` is included in the product build and provides:

- Connection snapshots from `/proc/net/*` when available on-device
- Persistent block rules (stored across reboots)
- Rule enforcement through system backend (iptables) when available
- Automatic fallback to VPN enforcement when system backend is unavailable
- Boot-time restart when protection was previously enabled
- Severity colors per connection:
  - Green (low), Orange (medium), Red (high)
- Risk elevation when source app appears sketchy or destination country is in
  a high-risk watchlist
- Dedicated security news section for Android app vulnerabilities and active
  attack reporting
- Automatic news refresh every hour

Rule format:

- IPv4 host: `198.51.100.42`
- IPv4 CIDR: `203.0.113.0/24`

Usage:

1. Open **Secure Connection Guard**
2. Add destination rules and enable protection
3. Long-press a listed connection to quickly block that destination

Security note:

- System backend mode uses iptables-based rules from a privileged app context.
- VPN fallback mode enforces blocking by routing selected destinations into the
  local VPN interface and dropping captured packets.

## Built-in AdGuard DNS quick toggles

`AdGuard Control` is included in the product and adds Quick Settings tiles:

- **AdGuard Free**: toggles Private DNS to `dns.adguard-dns.com`
- **AdGuard Paid**: toggles a user-configured paid/personal endpoint host

Setup:

1. Open **AdGuard Control**
2. Set your paid endpoint host (example: `example.d.adguard-dns.com`)
3. Add **AdGuard Free** and **AdGuard Paid** tiles to Quick Settings
4. Toggle either tile from the drop-down shade to enable/disable

Important note:

- This integration manages Android Private DNS endpoints for AdGuard free/paid
  DNS modes. It does not redistribute proprietary paid AdGuard binaries.

## Samsung camera parity path

To approach stock Samsung camera behavior/processing:

1. Run:
   `bash scripts/camera/integrate_samsung_camera.sh /path/to/aosp/tree /path/to/stock_dump`
2. Verify camera blobs and app packaging with:
   `bash scripts/qa/validate_feature_readiness.sh /path/to/aosp/tree`
3. Flash build and run:
   `bash scripts/qa/run_device_acceptance_suite.sh`
4. Complete manual camera mode checks (HDR/Night/Portrait/ultrawide/tele/video)

See:

- `docs/camera-stock-parity.md`
