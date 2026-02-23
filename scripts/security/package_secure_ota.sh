#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_GATE_SCRIPT="${SCRIPT_DIR}/release_gate.sh"

usage() {
  echo "Usage: $0 <aosp_root> <product_out_path> <unsigned_target_files_zip> <signing_keys_dir> <output_ota_zip>"
  echo "Example:"
  echo "  $0 ~/android/rom \\"
  echo "     ~/android/rom/out/target/product/edge70_xt2601_2 \\"
  echo "     ~/android/rom/out/dist/aosp_xt2601_2_eu-target_files-unsigned.zip \\"
  echo "     ~/android/keys/release \\"
  echo "     ~/android/rom/out/dist/aosp_xt2601_2_eu-ota-signed.zip"
}

require_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    echo "Error: required file missing: ${path}"
    exit 1
  fi
}

require_dir() {
  local path="$1"
  if [[ ! -d "${path}" ]]; then
    echo "Error: required directory missing: ${path}"
    exit 1
  fi
}

if [[ $# -ne 5 ]]; then
  usage
  exit 1
fi

AOSP_ROOT="$1"
PRODUCT_OUT="$2"
UNSIGNED_TARGET_FILES="$3"
SIGNING_KEYS_DIR="$4"
OUTPUT_OTA_ZIP="$5"

require_file "${RELEASE_GATE_SCRIPT}"
require_dir "${AOSP_ROOT}"
require_dir "${PRODUCT_OUT}"
require_file "${UNSIGNED_TARGET_FILES}"
require_dir "${SIGNING_KEYS_DIR}"

HOST_BIN="${AOSP_ROOT}/out/host/linux-x86/bin"
SIGN_TARGET_FILES_APKS="${HOST_BIN}/sign_target_files_apks"
OTA_FROM_TARGET_FILES="${HOST_BIN}/ota_from_target_files"

require_file "${SIGN_TARGET_FILES_APKS}"
require_file "${OTA_FROM_TARGET_FILES}"

SIGNED_TARGET_FILES="${OUTPUT_OTA_ZIP%.zip}-signed-target_files.zip"

mkdir -p "$(dirname "${SIGNED_TARGET_FILES}")"
mkdir -p "$(dirname "${OUTPUT_OTA_ZIP}")"

echo "Running release gate on unsigned target files..."
RELEASE_GATE_MODE=presign bash "${RELEASE_GATE_SCRIPT}" \
  "${PRODUCT_OUT}" "${UNSIGNED_TARGET_FILES}" "${SIGNING_KEYS_DIR}"

echo "Signing target files with release keys..."
"${SIGN_TARGET_FILES_APKS}" \
  -o \
  --default_key_mappings "${SIGNING_KEYS_DIR}" \
  "${UNSIGNED_TARGET_FILES}" \
  "${SIGNED_TARGET_FILES}"

echo "Running release gate on signed target files..."
RELEASE_GATE_MODE=strict bash "${RELEASE_GATE_SCRIPT}" \
  "${PRODUCT_OUT}" "${SIGNED_TARGET_FILES}" "${SIGNING_KEYS_DIR}"

echo "Creating signed OTA package..."
"${OTA_FROM_TARGET_FILES}" \
  -k "${SIGNING_KEYS_DIR}/releasekey" \
  "${SIGNED_TARGET_FILES}" \
  "${OUTPUT_OTA_ZIP}"

echo
echo "Secure OTA packaging completed successfully."
echo "- Signed target files: ${SIGNED_TARGET_FILES}"
echo "- Signed OTA package:  ${OUTPUT_OTA_ZIP}"
