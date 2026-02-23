# Motorola Edge 70 XT2601-2 dedicated device skeleton

This is the dedicated device tree scaffold for **Motorola Edge 70 EU
(XT2601-2)**.

Reference identifiers:
- GTIN: `0840493606774`
- Product code: `XT2601-2`
- Default lunch target: `aosp_xt2601_2_eu`

## Current status

- Suitable as a bring-up starting point
- Not production-ready
- Contains placeholders that must be replaced with stock firmware-derived values

## Must-do bring-up tasks

1. Replace `TARGET_BOARD_PLATFORM` in `BoardConfig.mk`
2. Update partition sizes and dynamic partition layout
3. Add a real kernel source/config or prebuilt kernel workflow
4. Populate
   `vendor/motorola/edge70_xt2601_2/proprietary-files.txt` and extract blobs
5. Add SELinux policy, audio/camera/display/radio HAL configuration, and fstab
6. Confirm modem/radio and camera sub-variant details from stock firmware

## Secure release guidance

- Build release artifacts as `user`, not `userdebug`
- Keep AVB enabled and signed
- Run:
  `scripts/security/verify_release_security.sh out/target/product/edge70_xt2601_2`
- Block OTA packaging unless this passes:
  `scripts/security/release_gate.sh <product_out> <target_files.zip> <keys_dir>`
