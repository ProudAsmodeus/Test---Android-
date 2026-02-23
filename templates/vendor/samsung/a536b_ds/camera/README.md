# Stock Samsung camera integration (SM-A536B/DS)

This folder provides an integration path for stock Samsung camera behavior and
processing.

## Expected files

- Prebuilt APK placed in:
  `vendor/samsung/a536b_ds/camera/prebuilt/`
  with one of these names:
  - `SamsungCamera.apk`
  - `SecCamera.apk`
  - `com.sec.android.app.camera.apk`

## Build behavior

- `camera-vendor.mk` adds `SamsungStockCamera` only when a prebuilt APK exists.
- `Android.mk` registers the prebuilt as privileged app (`PRESIGNED`).

## Important

Stock-quality results also depend on proprietary camera processing blobs
(camx/mmcamera/ArcSoft/tuning libraries) listed in:

`vendor/samsung/a536b_ds/proprietary-files.txt`
