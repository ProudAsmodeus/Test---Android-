# Samsung Galaxy A53 5G SM-A536B/DS dedicated device skeleton

This is the dedicated device tree scaffold for **Samsung Galaxy A53 5G (SM-A536B/DS)**.

Reference identifiers:
- Product code: `SM-A536B/DS`
- Default lunch target: `aosp_a536b_ds`

## Current status

- Suitable as a bring-up starting point
- Not production-ready
- Contains placeholders that must be replaced with stock firmware-derived values

## Must-do bring-up tasks

1. Replace `TARGET_BOARD_PLATFORM` in `BoardConfig.mk`
2. Update partition sizes and dynamic partition layout
3. Add a real kernel source/config or prebuilt kernel workflow
4. Populate
   `vendor/samsung/a536b_ds/proprietary-files.txt` and extract blobs
5. Add SELinux policy, audio/camera/display/radio HAL configuration, and fstab
6. Confirm modem/radio and camera sub-variant details from stock firmware
7. Integrate stock camera app + processing candidates:
   `scripts/camera/integrate_samsung_camera.sh /path/to/aosp/tree /path/to/stock_dump`
8. Pass source-tree readiness gate:
   `scripts/qa/validate_feature_readiness.sh /path/to/aosp/tree`
9. Pass on-device acceptance suite after flashing:
   `scripts/qa/run_device_acceptance_suite.sh`

## Secure release guidance

- Build release artifacts as `user`, not `userdebug`
- Keep AVB enabled and signed
- Run:
  `scripts/security/verify_release_security.sh out/target/product/a536b_ds`
- Block OTA packaging unless this passes:
  `RELEASE_GATE_MODE=presign scripts/security/release_gate.sh <product_out> <unsigned_target_files.zip> <keys_dir>`
- Audit kernel baseline:
  `scripts/security/check_kernel_hardening_config.sh /path/to/kernel/.config`
- Include user-facing enforcement controls via:
  `packages/apps/SecureConnectionGuard`
