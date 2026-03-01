# Samsung Galaxy A53 5G SM-A536B/DS dedicated device skeleton

This is the dedicated device tree scaffold for **Samsung Galaxy A53 5G (SM-A536B/DS)**.

Reference identifiers:
- Product code: `SM-A536B/DS`
- Default lunch target: `aosp_a536b_ds`

## Current status

- Suitable as a bring-up starting point with stock-backed board/kernel defaults
- Not production-ready yet (still requires full extract + device testing)
- Aligned to recent public Exynos 1280 bring-up trees for SM-A536B

## Must-do bring-up tasks

1. Sync companion trees in local manifests:
   - `device/samsung/s5e8825-common`
   - `vendor/samsung/a53x`
   - `vendor/samsung/s5e8825-common`
   - `kernel/samsung/s5e8825`
2. Run extract + setup scripts to generate vendor makefiles from stock firmware
3. Verify modem/radio and camera sub-variant details for your exact CSC
4. Integrate stock camera app + processing candidates:
   `scripts/camera/integrate_samsung_camera.sh /path/to/aosp/tree /path/to/stock_dump`
   or fetch verified prebuilt quickly:
   `scripts/camera/fetch_samsung_camera_prebuilt.sh /path/to/aosp/tree`
5. Pass source-tree readiness gate:
   `scripts/qa/validate_feature_readiness.sh /path/to/aosp/tree`
6. Pass on-device acceptance suite after flashing:
   `scripts/qa/run_device_acceptance_suite.sh`
7. Prepare DSU sideload artifacts from build output:
   `scripts/dsu/build_dsu_sideload_artifacts.sh /path/to/aosp/tree /path/to/aosp/tree/out/target/product/a536b_ds`
8. Check DSU device prerequisites and launch sideload:
   `scripts/dsu/check_device_dsu_prereqs.sh`
   then:
   `source out/dist/dsu/dsu-artifacts.env && bash scripts/dsu/run_dsu_sideload.sh "${SYSTEM_RAW_GZ_PATH}" "${SYSTEM_RAW_SIZE}"`

## Secure release guidance

- Build release artifacts as `user`, not `userdebug`
- Keep AVB enabled and signed
- Run:
  `scripts/security/verify_release_security.sh out/target/product/a536b_ds`
- Block OTA packaging unless this passes:
  `RELEASE_GATE_MODE=presign scripts/security/release_gate.sh <product_out> <unsigned_target_files.zip> <keys_dir>`
- Audit kernel baseline:
  `scripts/security/check_kernel_hardening_config.sh /path/to/kernel/.config`
- Include user-facing enforcement controls via:
  `packages/apps/SecureConnectionGuard`
