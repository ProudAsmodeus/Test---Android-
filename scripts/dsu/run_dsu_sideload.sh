#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <system_raw_gz_path> <system_raw_size_bytes>"
  echo
  echo "Pushes a prepared non-sparse gzipped system image and starts DSU install"
  echo "through com.android.dynsystem VerificationActivity."
  echo
  echo "Environment:"
  echo "  ADB_SERIAL=<serial>                (optional)"
  echo "  USERDATA_SIZE_BYTES=<bytes>        (default: 8589934592)"
  echo "  REMOTE_GSI_PATH=<device_file_uri>  (default: /storage/emulated/0/Download/<basename>)"
  echo "  AUTO_PUSH=1|0                      (default: 1)"
  echo "  RUN_PREFLIGHT=1|0                  (default: 1)"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

SYSTEM_RAW_GZ_PATH="$1"
SYSTEM_RAW_SIZE="$2"

USERDATA_SIZE_BYTES="${USERDATA_SIZE_BYTES:-8589934592}"
AUTO_PUSH="${AUTO_PUSH:-1}"
RUN_PREFLIGHT="${RUN_PREFLIGHT:-1}"
ADB_SERIAL="${ADB_SERIAL:-}"
REMOTE_GSI_PATH="${REMOTE_GSI_PATH:-/storage/emulated/0/Download/$(basename "${SYSTEM_RAW_GZ_PATH}")}"

if [[ ! -f "${SYSTEM_RAW_GZ_PATH}" ]]; then
  echo "Error: system image not found: ${SYSTEM_RAW_GZ_PATH}"
  exit 1
fi

if ! [[ "${SYSTEM_RAW_SIZE}" =~ ^[0-9]+$ ]]; then
  echo "Error: system_raw_size_bytes must be an integer."
  exit 1
fi

if ! [[ "${USERDATA_SIZE_BYTES}" =~ ^[0-9]+$ ]]; then
  echo "Error: USERDATA_SIZE_BYTES must be an integer."
  exit 1
fi

if ! command -v adb >/dev/null 2>&1; then
  echo "Error: adb not found in PATH."
  exit 1
fi

adb_cmd() {
  if [[ -n "${ADB_SERIAL}" ]]; then
    adb -s "${ADB_SERIAL}" "$@"
  else
    adb "$@"
  fi
}

if [[ "${RUN_PREFLIGHT}" == "1" ]]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  preflight_script="${script_dir}/check_device_dsu_prereqs.sh"
  if [[ -f "${preflight_script}" ]]; then
    ADB_SERIAL="${ADB_SERIAL}" bash "${preflight_script}"
  else
    echo "Warning: preflight script not found at ${preflight_script}; continuing."
  fi
fi

if ! adb_cmd get-state >/dev/null 2>&1; then
  echo "Error: no adb device detected."
  exit 1
fi

sdk="$(adb_cmd shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')"
if [[ "${sdk}" =~ ^[0-9]+$ ]]; then
  if (( sdk < 29 )); then
    echo "Error: connected device API level ${sdk} does not support DSU."
    exit 1
  fi
else
  echo "Warning: unable to read device API level."
fi

if [[ "${AUTO_PUSH}" == "1" ]]; then
  echo "Pushing ${SYSTEM_RAW_GZ_PATH} -> ${REMOTE_GSI_PATH}"
  adb_cmd push "${SYSTEM_RAW_GZ_PATH}" "${REMOTE_GSI_PATH}"
else
  echo "AUTO_PUSH=0 set; expecting image already present at ${REMOTE_GSI_PATH}"
fi

echo "Launching DSU VerificationActivity..."
launch_output="$(
  adb_cmd shell am start-activity \
    -n com.android.dynsystem/com.android.dynsystem.VerificationActivity \
    -a android.os.image.action.START_INSTALL \
    -d "file://${REMOTE_GSI_PATH}" \
    --el KEY_SYSTEM_SIZE "${SYSTEM_RAW_SIZE}" \
    --el KEY_USERDATA_SIZE "${USERDATA_SIZE_BYTES}" 2>&1
)"
printf '%s\n' "${launch_output}"

if [[ "${launch_output}" == *"Error:"* ]]; then
  echo "Error: activity launch reported an error."
  exit 1
fi

echo
echo "DSU sideload request submitted."
echo "On the device, confirm the DSU prompt and wait for installation to finish."
