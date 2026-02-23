# Vendor blobs placeholder - Motorola Edge 70 EU (XT2601-2)

This directory is a placeholder for proprietary vendor blobs for the dedicated
XT2601-2 SKU.

## Expected workflow

1. Dump stock firmware images for XT2601-2
2. Populate `proprietary-files.txt` with required blob paths
3. Add extraction scripts if using a LineageOS-style workflow
4. Generate vendor makefiles from extracted files

## Stock camera parity path

For Motorola-like camera behavior and processing:

1. Place stock camera APK in:
   `vendor/motorola/edge70_xt2601_2/camera/prebuilt/`
2. Keep camera processing blobs (camx/mmcamera/ArcSoft/tuning libs) in
   `proprietary-files.txt`
3. Use:
   `scripts/camera/integrate_moto_camera.sh /path/to/aosp /path/to/stock_dump`
   to bootstrap APK + camera blob candidates from stock dump
