# Vendor blobs scaffold - Samsung Galaxy S7 (SM-G930F)

This directory is a scaffold for proprietary blobs for **Samsung Galaxy S7
(SM-G930F / herolte)**.

## Expected workflow

1. Dump stock firmware images for your exact CSC/build
2. Populate or regenerate `proprietary-files.txt`
3. Run extraction scripts to create `g930f-vendor.mk`
4. Optionally sync shared Exynos 8890 vendor trees (`universal8890-common`)
5. Integrate stock camera APK path:
   - `scripts/camera/integrate_samsung_camera.sh /path/to/aosp /path/to/stock_dump`
   - or quick fetch:
     `VENDOR_PATH=vendor/samsung/g930f DEVICE_PROFILE=g930f bash scripts/camera/fetch_samsung_camera_prebuilt.sh /path/to/aosp`
