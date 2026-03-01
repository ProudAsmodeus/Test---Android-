# Samsung Galaxy S7 SM-G930F dedicated device skeleton

This is the dedicated device tree scaffold for **Samsung Galaxy S7 (SM-G930F)**.

Reference identifiers:
- Product code: `SM-G930F`
- Legacy codename family: `herolte`
- Default lunch target: `aosp_g930f`

## Current status

- Suitable as a bring-up starting point with stock-backed Exynos 8890 defaults
- Not production-ready yet (still requires full extract + device testing)
- Aligned to public `lineage-18.1` herolte/universal8890 trees

## Must-do bring-up tasks

1. Sync companion trees in local manifests:
   - `device/samsung/herolte` (or map to `device/samsung/g930f`)
   - `device/samsung/universal8890-common`
   - `kernel/samsung/universal8890`
   - vendor blobs (`vendor/samsung/herolte` + `vendor/samsung/universal8890-common`)
2. Run extract + setup scripts to generate vendor makefiles from stock firmware
3. Integrate stock camera app candidates:
   `scripts/camera/integrate_samsung_camera.sh /path/to/aosp/tree /path/to/stock_dump`
   or fetch verified prebuilt quickly:
   `VENDOR_PATH=vendor/samsung/g930f DEVICE_PROFILE=g930f bash scripts/camera/fetch_samsung_camera_prebuilt.sh /path/to/aosp/tree`
4. Pass source-tree readiness gate:
   `DEVICE_PATH=device/samsung/g930f VENDOR_PATH=vendor/samsung/g930f REQUIRE_5G_SUPPORT=0 AUTO_FETCH_STOCK_CAMERA_APP=1 bash scripts/qa/validate_feature_readiness.sh /path/to/aosp/tree`
5. Pass on-device acceptance suite after flashing (legacy profile):
   `REQUIRE_5G_SUPPORT=0 bash scripts/qa/run_device_acceptance_suite.sh`

## Legacy platform note

SM-G930F is a pre-dynamic-partition platform. DSU sideloading is generally not
available on this hardware generation. Keep `REQUIRE_DSU_SUPPORT=0` if you force
manual readiness checks.
