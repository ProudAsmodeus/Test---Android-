# Android ROM Base (Newest Android)

This repository provides a starter base for building a custom Android ROM on top
of the newest AOSP release branch.

## What this includes

- A bootstrap script to initialize and sync AOSP from
  `android-latest-release` (default)
- A local manifest template for adding your device/kernel/vendor repos
- Base ROM product + config makefiles under `vendor/rom`

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
   lunch aosp_rom_base-userdebug
   m -j$(nproc)
   ```

## Important notes

- This is a **base scaffold**. You still need device-specific trees and
  proprietary blobs for your hardware target.
- Edit `.repo/local_manifests/rom-base.xml` with your actual repositories.
- Replace or extend `vendor/rom` configs to match your ROM branding/features.
