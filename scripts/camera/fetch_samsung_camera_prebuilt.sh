#!/usr/bin/env bash
set -euo pipefail

AOSP_ROOT="${1:-$(pwd)}"
VENDOR_PATH="${VENDOR_PATH:-vendor/samsung/a536b_ds}"
DEVICE_PROFILE="${DEVICE_PROFILE:-}"
TARGET_NAME="${TARGET_NAME:-}"
CAMERA_URL="${CAMERA_URL:-}"
CAMERA_SHA256="${CAMERA_SHA256:-}"
FORCE_DOWNLOAD="${FORCE_DOWNLOAD:-0}"

if [[ ! -d "${AOSP_ROOT}" ]]; then
  echo "Error: AOSP root not found: ${AOSP_ROOT}"
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required to download SamsungCamera prebuilt."
  exit 1
fi

if ! command -v sha256sum >/dev/null 2>&1; then
  echo "Error: sha256sum is required to verify SamsungCamera prebuilt."
  exit 1
fi

if [[ -z "${DEVICE_PROFILE}" ]]; then
  case "${VENDOR_PATH##*/}" in
    a536b_ds|a53x)
      DEVICE_PROFILE="a536b_ds"
      ;;
    g930f|herolte)
      DEVICE_PROFILE="g930f"
      ;;
    *)
      DEVICE_PROFILE="a536b_ds"
      ;;
  esac
fi

if [[ -z "${CAMERA_URL}" || -z "${CAMERA_SHA256}" || -z "${TARGET_NAME}" ]]; then
  case "${DEVICE_PROFILE}" in
    a536b_ds|a53x)
      TARGET_NAME="${TARGET_NAME:-SamsungCamera.apk}"
      CAMERA_URL="${CAMERA_URL:-https://raw.githubusercontent.com/s5e8825/samsung_a53x_dump/android-13.0/system/system/priv-app/SamsungCamera/SamsungCamera.apk}"
      CAMERA_SHA256="${CAMERA_SHA256:-4c0a00df076d553799df9a4fbee3eb0a21466b0c831e35871e6306599a2f5a46}"
      ;;
    g930f|herolte)
      TARGET_NAME="${TARGET_NAME:-SamsungCamera7.apk}"
      CAMERA_URL="${CAMERA_URL:-https://raw.githubusercontent.com/leddaz-dump-stash/samsung_herolte_dump/heroltexx-user-8.0.0-R16NW-G930FXXS8ETC3-release-keys/system/priv-app/SamsungCamera7/SamsungCamera7.apk}"
      CAMERA_SHA256="${CAMERA_SHA256:-8774267f3c9cf76d71ea63a5ea20f88f9927586009aa8c63bc53a8deb28806c9}"
      ;;
    *)
      echo "Error: unknown DEVICE_PROFILE='${DEVICE_PROFILE}'."
      echo "Set DEVICE_PROFILE to a supported value (a536b_ds, g930f) or set CAMERA_URL/CAMERA_SHA256/TARGET_NAME explicitly."
      exit 1
      ;;
  esac
fi

TARGET_DIR="${AOSP_ROOT}/${VENDOR_PATH}/camera/prebuilt"
TARGET_APK="${TARGET_DIR}/${TARGET_NAME}"

mkdir -p "${TARGET_DIR}"

if [[ -f "${TARGET_APK}" && "${FORCE_DOWNLOAD}" != "1" ]]; then
  existing_sha="$(sha256sum "${TARGET_APK}" | awk '{print $1}')"
  if [[ "${existing_sha}" == "${CAMERA_SHA256}" ]]; then
    echo "Samsung camera prebuilt already present and verified:"
    echo "  ${TARGET_APK}"
    exit 0
  fi
  echo "Existing APK checksum mismatch; refreshing ${TARGET_APK}."
fi

tmp_apk="$(mktemp)"
cleanup() {
  rm -f "${tmp_apk}"
}
trap cleanup EXIT

echo "Downloading Samsung camera prebuilt..."
echo "  profile: ${DEVICE_PROFILE}"
echo "  source:  ${CAMERA_URL}"
curl -L --fail --retry 3 --retry-delay 2 -o "${tmp_apk}" "${CAMERA_URL}"

downloaded_sha="$(sha256sum "${tmp_apk}" | awk '{print $1}')"
if [[ "${downloaded_sha}" != "${CAMERA_SHA256}" ]]; then
  echo "Error: checksum mismatch for downloaded Samsung camera prebuilt."
  echo "Expected: ${CAMERA_SHA256}"
  echo "Actual:   ${downloaded_sha}"
  exit 1
fi

mv "${tmp_apk}" "${TARGET_APK}"
chmod 0644 "${TARGET_APK}"

echo "Samsung camera prebuilt downloaded and verified:"
echo "  ${TARGET_APK}"
