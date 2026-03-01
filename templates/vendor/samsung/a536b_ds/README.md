# Vendor blobs placeholder - Samsung Galaxy A53 5G (SM-A536B/DS)

This directory is a placeholder for proprietary vendor blobs for the dedicated
SM-A536B/DS SKU.

## Expected workflow

1. Dump stock firmware images for SM-A536B/DS
2. Populate `proprietary-files.txt` with required blob paths
3. Add extraction scripts if using a LineageOS-style workflow
4. Generate vendor makefiles from extracted files

## Stock camera parity path

For Samsung-like camera behavior and processing:

1. Place stock camera APK in:
   `vendor/samsung/a536b_ds/camera/prebuilt/`
2. Keep camera processing blobs (camx/mmcamera/ArcSoft/tuning libs) in
   `proprietary-files.txt`
3. Use:
   `scripts/camera/integrate_samsung_camera.sh /path/to/aosp /path/to/stock_dump`
   to bootstrap APK + camera blob candidates from stock dump
4. For strict readiness without a local dump, fetch verified camera prebuilt:
   `scripts/camera/fetch_samsung_camera_prebuilt.sh /path/to/aosp`
