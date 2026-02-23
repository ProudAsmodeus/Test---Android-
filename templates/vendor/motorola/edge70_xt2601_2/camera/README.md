# Stock Motorola camera integration (XT2601-2)

This folder provides an integration path for stock Motorola camera behavior and
processing.

## Expected files

- Prebuilt APK placed in:
  `vendor/motorola/edge70_xt2601_2/camera/prebuilt/`
  with one of these names:
  - `MotoCamera.apk`
  - `MotorolaCamera.apk`
  - `com.motorola.camera3.apk`

## Build behavior

- `camera-vendor.mk` adds `MotoStockCamera` only when a prebuilt APK exists.
- `Android.mk` registers the prebuilt as privileged app (`PRESIGNED`).

## Important

Stock-quality results also depend on proprietary camera processing blobs
(camx/mmcamera/ArcSoft/tuning libraries) listed in:

`vendor/motorola/edge70_xt2601_2/proprietary-files.txt`
