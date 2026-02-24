# DSU sideloading workflow (SM-A536B/DS)

This project includes host-side helpers to test builds through Android Dynamic
System Updates (DSU) without flashing permanent partitions.

## 1) Prerequisites

- Built images exist under `out/target/product/a536b_ds/`
- `adb` is installed on your host
- Device supports:
  - Android 10+ (`API 29+`)
  - Treble
  - dynamic partitions
- Recommended:
  - unlocked bootloader
  - at least 10 GiB free on `/data`

## 2) Build DSU artifacts from your output

From AOSP root:

```bash
bash scripts/dsu/build_dsu_sideload_artifacts.sh \
  "$(pwd)" \
  out/target/product/a536b_ds
```

This generates:

- `out/dist/dsu/system.raw` (non-sparse)
- `out/dist/dsu/system.raw.gz` (for DSU VerificationActivity)
- `out/dist/dsu/dsu-artifacts.env` (sizes/paths for launch script)
- optional `out/dist/dsu/aosp_a536b_ds-dsu.zip` (image bundle for DSU package flow)

## 3) Check connected device DSU readiness

```bash
bash scripts/dsu/check_device_dsu_prereqs.sh
```

This checks API level, Treble, dynamic partitions, `/data` free space, and DSU
frontend visibility.

## 4) Start DSU sideload install (non-root adb path)

```bash
source out/dist/dsu/dsu-artifacts.env
bash scripts/dsu/run_dsu_sideload.sh \
  "${SYSTEM_RAW_GZ_PATH}" \
  "${SYSTEM_RAW_SIZE}"
```

After command submission, confirm the DSU prompt on-device and wait for image
allocation/install to complete.

## 5) Manual fallback (official AOSP command path)

If you want direct commands:

```bash
adb push out/dist/dsu/system.raw.gz /storage/emulated/0/Download/system.raw.gz
adb shell am start-activity \
  -n com.android.dynsystem/com.android.dynsystem.VerificationActivity \
  -a android.os.image.action.START_INSTALL \
  -d file:///storage/emulated/0/Download/system.raw.gz \
  --el KEY_SYSTEM_SIZE "$(stat -c%s out/dist/dsu/system.raw)" \
  --el KEY_USERDATA_SIZE 8589934592
```

## Notes

- DSU boot can fail on locked bootloaders when non-OEM-signed images are used.
- `system.raw.gz` must be derived from a non-sparse image (`simg2img` path).
- If DSU install succeeds but boot fails, verify AVB/verification policy on host
  firmware and ensure the image is compatible with the host vendor stack.
