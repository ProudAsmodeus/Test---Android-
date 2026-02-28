# Stock Samsung camera integration (SM-G930F)

This folder provides an integration path for stock Samsung camera behavior.

## Expected files

- Prebuilt APK in:
  `vendor/samsung/g930f/camera/prebuilt/`
- Supported names:
  - `SamsungCamera7.apk`
  - `SamsungCamera6.apk`
  - `SamsungCamera.apk`
  - `SecCamera.apk`
  - `com.sec.android.app.camera.apk`

## Build behavior

- `camera-vendor.mk` adds `SamsungStockCamera` only when a prebuilt APK exists.
- `Android.mk` registers the prebuilt as privileged app (`PRESIGNED`).

## Important

Stock-like results still require matching proprietary camera stack blobs from
your stock firmware.
