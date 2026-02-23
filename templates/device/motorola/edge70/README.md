# Motorola Edge 70 device skeleton

This is a starter device tree scaffold for **Motorola Edge 70 (12GB RAM / 512GB
storage)**.

Reference identifiers provided:
- GTIN: `0840493606774`
- Product code: `XT2601-2`
- EU-targeted build flavors: `aosp_edge70_eu`, `aosp_xt2601_2_eu`

## Current status

- Suitable as a bring-up starting point
- Not production-ready
- Contains placeholders that must be replaced with real values from stock
  firmware, kernel source, and dumps

## Must-do bring-up tasks

1. Replace `TARGET_BOARD_PLATFORM` in `BoardConfig.mk`
2. Update partition sizes and dynamic partition layout
3. Add a real kernel source/config or prebuilt kernel workflow
4. Populate `vendor/motorola/edge70/proprietary-files.txt` and extract blobs
5. Add SELinux policy, audio/camera/display/radio HAL configuration, and fstab
6. Confirm modem/radio and camera sub-variant details from stock firmware to
   avoid cross-SKU incompatibilities
