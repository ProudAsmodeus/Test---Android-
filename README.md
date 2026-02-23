# Android ROM Base (Newest Android)

This repository provides a starter base for building a custom Android ROM on top
of the newest AOSP release branch.

## What this includes

- A bootstrap script to initialize and sync AOSP from
  `android-latest-release` (default)
- A local manifest template for adding your device/kernel/vendor repos
- Base ROM product + config makefiles under `vendor/rom`
- Motorola Edge 70 XT2601-2 **dedicated** starter skeleton:
  - `device/motorola/edge70_xt2601_2`
  - `vendor/motorola/edge70_xt2601_2`
  - Includes `aosp_xt2601_2_eu` lunch target (SKU: `XT2601-2`)
- Security baseline tooling:
  - `vendor/rom/config/security_hardening.mk`
  - `scripts/security/sync_latest_security_patches.sh`
  - `scripts/security/verify_release_security.sh`
  - `scripts/security/release_gate.sh`
  - `scripts/security/package_secure_ota.sh`
  - `scripts/security/check_kernel_hardening_config.sh`
- Built-in security app:
  - `packages/apps/SecureConnectionGuard`

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
   lunch aosp_xt2601_2_eu-user
   m -j$(nproc)
   ```

   For bring-up debugging only:

   ```bash
   lunch aosp_xt2601_2_eu-userdebug
   ```

## Important notes

- This is a **base scaffold**. You still need device-specific trees and
  proprietary blobs for your hardware target.
- Edit `.repo/local_manifests/rom-base.xml` with your actual repositories.
- Replace or extend `vendor/rom` configs to match your ROM branding/features.
- Update placeholder values in
  `device/motorola/edge70_xt2601_2/BoardConfig.mk` before attempting a full
  device bring-up.
- GTIN `0840493606774` and product code `XT2601-2` are stored as reference
  inputs. Confirm additional hardware identifiers from stock firmware before
  finalizing kernel and modem/radio config.

## Security update workflow

After bootstrap, run these commands from your AOSP tree root.

1. Sync latest upstream patches (including newest Android security updates):

   ```bash
   bash scripts/security/sync_latest_security_patches.sh /path/to/aosp/tree
   ```

2. Verify release build posture:

   ```bash
   bash scripts/security/verify_release_security.sh \
     out/target/product/edge70_xt2601_2
   ```

3. Block OTA packaging unless release/security checks pass:

   ```bash
   RELEASE_GATE_MODE=presign bash scripts/security/release_gate.sh \
     out/target/product/edge70_xt2601_2 \
     out/dist/aosp_xt2601_2_eu-target_files-unsigned.zip \
     /path/to/release-keys
   ```

   Note:
   - `presign` mode is for unsigned target-files checks
   - default strict mode is for signed target-files checks

   Optional key-set override for branches with fewer key aliases:

   ```bash
   REQUIRED_KEYS="releasekey,platform,shared,media" \
   bash scripts/security/release_gate.sh \
     out/target/product/edge70_xt2601_2 \
     out/dist/aosp_xt2601_2_eu-target_files-unsigned.zip \
     /path/to/release-keys
   ```

4. Package signed OTA only after gate passes:

   ```bash
   bash scripts/security/package_secure_ota.sh \
     /path/to/aosp/tree \
     out/target/product/edge70_xt2601_2 \
     out/dist/aosp_xt2601_2_eu-target_files-unsigned.zip \
     /path/to/release-keys \
     out/dist/aosp_xt2601_2_eu-ota-signed.zip
   ```

5. Review detailed policy:

   - `docs/security-baseline.md`

6. Optional kernel hardening audit:

   ```bash
   bash scripts/security/check_kernel_hardening_config.sh \
     /path/to/kernel/.config
   ```

## Built-in connection firewall app

`Secure Connection Guard` is included in the product build and provides:

- Connection snapshots from `/proc/net/*` when available on-device
- Persistent block rules (stored across reboots)
- Rule enforcement through a local VPN service
- Boot-time restart when protection was previously enabled

Rule format:

- IPv4 host: `198.51.100.42`
- IPv4 CIDR: `203.0.113.0/24`

Usage:

1. Open **Secure Connection Guard**
2. Add destination rules and enable protection
3. Long-press a listed connection to quickly block that destination

Security note:

- This template enforces destination blocking by routing selected destinations
  into the local VPN interface and dropping captured packets.
