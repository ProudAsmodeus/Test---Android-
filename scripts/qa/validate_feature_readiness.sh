#!/usr/bin/env bash
set -euo pipefail

AOSP_ROOT="${1:-$(pwd)}"
DEVICE_PATH="${DEVICE_PATH:-device/samsung/a536b_ds}"
VENDOR_PATH="${VENDOR_PATH:-vendor/samsung/a536b_ds}"
MIN_BLOB_LINES="${MIN_BLOB_LINES:-80}"
REQUIRE_STOCK_CAMERA_APP="${REQUIRE_STOCK_CAMERA_APP:-1}"
REQUIRE_ESIM_SUPPORT="${REQUIRE_ESIM_SUPPORT:-0}"

DEVICE_DIR="${AOSP_ROOT}/${DEVICE_PATH}"
VENDOR_DIR="${AOSP_ROOT}/${VENDOR_PATH}"
BOARD_CONFIG="${DEVICE_DIR}/BoardConfig.mk"
DEVICE_MK="${DEVICE_DIR}/device.mk"
SYSTEM_PROP="${DEVICE_DIR}/system.prop"
INIT_RC="${DEVICE_DIR}/init/init.a536b_ds.rc"
BLOB_FILE="${VENDOR_DIR}/proprietary-files.txt"
CAMERA_VENDOR_MK="${VENDOR_DIR}/camera/camera-vendor.mk"
CAMERA_PREBUILT_DIR="${VENDOR_DIR}/camera/prebuilt"

failures=0

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

require_file() {
  local path="$1"
  local label="$2"
  if [[ -f "${path}" ]]; then
    pass "${label} present (${path})"
  else
    fail "${label} missing (${path})"
  fi
}

check_no_placeholders() {
  local path="$1"
  local label="$2"
  if [[ ! -f "${path}" ]]; then
    fail "${label} missing while checking placeholders (${path})"
    return
  fi
  if rg -n -i "TODO_|placeholder|replace this" "${path}" >/dev/null 2>&1; then
    fail "${label} still contains placeholder values (${path})"
  else
    pass "${label} has no placeholder markers"
  fi
}

check_blob_group() {
  local group_label="$1"
  local pattern="$2"
  if rg -n -i "${pattern}" "${BLOB_FILE}" >/dev/null 2>&1; then
    pass "Blob coverage includes ${group_label}"
  else
    fail "Blob coverage missing ${group_label} (${pattern})"
  fi
}

echo "Validating standard feature readiness..."
echo "- AOSP root: ${AOSP_ROOT}"
echo "- Device path: ${DEVICE_PATH}"
echo "- Vendor path: ${VENDOR_PATH}"
echo

require_file "${BOARD_CONFIG}" "BoardConfig"
require_file "${DEVICE_MK}" "device.mk"
require_file "${SYSTEM_PROP}" "system.prop"
require_file "${INIT_RC}" "init rc"
require_file "${BLOB_FILE}" "proprietary-files"
require_file "${CAMERA_VENDOR_MK}" "camera-vendor.mk"

if [[ -f "${DEVICE_MK}" ]]; then
  if rg -n "full_base_telephony\.mk" "${DEVICE_MK}" >/dev/null 2>&1; then
    pass "device.mk inherits full_base_telephony"
  else
    fail "device.mk must inherit full_base_telephony for calls/SMS/mobile data"
  fi

  if rg -n "camera/camera-vendor\.mk" "${DEVICE_MK}" >/dev/null 2>&1; then
    pass "device.mk includes camera-vendor integration"
  else
    fail "device.mk should include vendor camera integration makefile"
  fi
fi

check_no_placeholders "${BOARD_CONFIG}" "BoardConfig"
check_no_placeholders "${SYSTEM_PROP}" "system.prop"

if [[ -f "${BLOB_FILE}" ]]; then
  blob_count="$(rg -n "^[^#[:space:]].+" "${BLOB_FILE}" || true)"
  blob_count="$(printf '%s\n' "${blob_count}" | awk 'NF{c++} END{print c+0}')"
  if [[ "${blob_count}" -lt "${MIN_BLOB_LINES}" ]]; then
    fail "proprietary-files has only ${blob_count} active entries (min ${MIN_BLOB_LINES})"
  else
    pass "proprietary-files has ${blob_count} active entries"
  fi

  check_blob_group "telephony/radio stack" "(radio|ril|ims|qcril|telephony)"
  check_blob_group "5G/modem support" "(nr|5g|modem)"
  if [[ "${REQUIRE_ESIM_SUPPORT}" == "1" ]]; then
    check_blob_group "eSIM/eUICC support" "(euicc|esim|lpa|uicc)"
  else
    echo "INFO: eSIM/eUICC coverage check skipped (REQUIRE_ESIM_SUPPORT=0)"
  fi
  check_blob_group "camera stack" "(camera|camx|mmcamera)"
  check_blob_group "camera processing stack" "(arcsoft|bokeh|hdr|eis|ois|depth|chi|ais)"
  check_blob_group "camera app package blobs" "(samsung.*camera|sec.*camera|com\.sec\.android\.app\.camera)"
  check_blob_group "audio/voice stack" "(audio|soundtrigger|voice)"
  check_blob_group "wifi/bluetooth stack" "(wlan|wifi|bluetooth|bt)"
fi

if [[ "${REQUIRE_STOCK_CAMERA_APP}" == "1" ]]; then
  camera_apk=""
  for candidate in \
    "${CAMERA_PREBUILT_DIR}/SamsungCamera.apk" \
    "${CAMERA_PREBUILT_DIR}/SecCamera.apk" \
    "${CAMERA_PREBUILT_DIR}/com.sec.android.app.camera.apk"; do
    if [[ -f "${candidate}" ]]; then
      camera_apk="${candidate}"
      break
    fi
  done

  if [[ -n "${camera_apk}" ]]; then
    pass "stock camera APK present (${camera_apk})"
  else
    fail "stock camera APK missing in ${CAMERA_PREBUILT_DIR} (set REQUIRE_STOCK_CAMERA_APP=0 to bypass)"
  fi
fi

if [[ "${failures}" -gt 0 ]]; then
  echo
  echo "Feature readiness FAILED with ${failures} issue(s)."
  exit 1
fi

echo
echo "Feature readiness PASSED."
