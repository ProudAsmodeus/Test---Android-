#!/usr/bin/env bash
set -euo pipefail

AOSP_ROOT="${1:-$(pwd)}"
DEVICE_PATH="${DEVICE_PATH:-device/motorola/edge70_xt2601_2}"
VENDOR_PATH="${VENDOR_PATH:-vendor/motorola/edge70_xt2601_2}"
MIN_BLOB_LINES="${MIN_BLOB_LINES:-80}"

DEVICE_DIR="${AOSP_ROOT}/${DEVICE_PATH}"
VENDOR_DIR="${AOSP_ROOT}/${VENDOR_PATH}"
BOARD_CONFIG="${DEVICE_DIR}/BoardConfig.mk"
DEVICE_MK="${DEVICE_DIR}/device.mk"
SYSTEM_PROP="${DEVICE_DIR}/system.prop"
INIT_RC="${DEVICE_DIR}/init/init.edge70_xt2601_2.rc"
BLOB_FILE="${VENDOR_DIR}/proprietary-files.txt"

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

if [[ -f "${DEVICE_MK}" ]]; then
  if rg -n "full_base_telephony\.mk" "${DEVICE_MK}" >/dev/null 2>&1; then
    pass "device.mk inherits full_base_telephony"
  else
    fail "device.mk must inherit full_base_telephony for calls/SMS/mobile data"
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
  check_blob_group "eSIM/eUICC support" "(euicc|esim|lpa)"
  check_blob_group "camera stack" "(camera|camx|mmcamera)"
  check_blob_group "audio/voice stack" "(audio|soundtrigger|voice)"
  check_blob_group "wifi/bluetooth stack" "(wlan|wifi|bluetooth|bt)"
fi

if [[ "${failures}" -gt 0 ]]; then
  echo
  echo "Feature readiness FAILED with ${failures} issue(s)."
  exit 1
fi

echo
echo "Feature readiness PASSED."
