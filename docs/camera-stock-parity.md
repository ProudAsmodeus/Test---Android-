# Stock camera parity guide (XT2601-2)

To approach Motorola stock camera behavior and processing quality, use the stock
camera app and proprietary camera processing stack from the same firmware family
as your target build.

## 1) Integrate stock camera package and candidate blobs

```bash
bash scripts/camera/integrate_moto_camera.sh /path/to/aosp/tree /path/to/stock_dump
```

This script:

- finds a Motorola camera APK candidate and copies it as:
  `vendor/motorola/edge70_xt2601_2/camera/prebuilt/MotoCamera.apk`
- appends camera-related candidate blob paths into:
  `vendor/motorola/edge70_xt2601_2/proprietary-files.txt`

## 2) Ensure camera prebuilt path is active

- `vendor/motorola/edge70_xt2601_2/camera/camera-vendor.mk` should exist
- `device/motorola/edge70_xt2601_2/device.mk` should include this makefile

## 3) Validate feature readiness

```bash
bash scripts/qa/validate_feature_readiness.sh /path/to/aosp/tree
```

This includes camera-specific checks for:

- stock camera integration files
- camera app package references in blobs
- camera processing blob coverage (camx/mmcamera/ArcSoft/etc.)

## 4) Validate on real hardware

```bash
bash scripts/qa/run_device_acceptance_suite.sh
```

Then complete manual tests:

- front/rear cameras
- ultrawide/tele/macro if present
- HDR/night/portrait modes
- video stabilization and recording quality

## Important

Exact parity depends on matching:

- firmware generation,
- proprietary processing libraries,
- tuning/calibration files,
- camera HAL/kernel compatibility.

Optional bypass controls (not recommended for production parity):

- `REQUIRE_STOCK_CAMERA_APP=0` for source-tree readiness script
- `REQUIRE_STOCK_CAMERA_PACKAGE=0` for on-device acceptance suite
