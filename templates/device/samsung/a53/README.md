# Samsung Galaxy A53 5G device skeleton

This is a starter device tree scaffold for **Samsung Galaxy A53 5G (SM-A536B/DS dual-SIM variant)**.

For a dedicated SM-A536B/DS layout, prefer:
`device/samsung/a536b_ds`.

Reference identifiers provided:
- Product code: `SM-A536B/DS`
- Dual-SIM build flavor: `aosp_a53_ds`

## Current status

- Suitable as a bring-up starting point
- Not production-ready
- Contains placeholders that must be replaced with real values from stock
  firmware, kernel source, and dumps

## Must-do bring-up tasks

1. Replace `TARGET_BOARD_PLATFORM` in `BoardConfig.mk`
2. Update partition sizes and dynamic partition layout
3. Add a real kernel source/config or prebuilt kernel workflow
4. Populate `vendor/samsung/a53/proprietary-files.txt` and extract blobs
5. Add SELinux policy, audio/camera/display/radio HAL configuration, and fstab
6. Confirm modem/radio and camera sub-variant details from stock firmware to
   avoid cross-SKU incompatibilities
