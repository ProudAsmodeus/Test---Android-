#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="${SCRIPT_DIR}/verify_release_security.sh"
KERNEL_CHECK_SCRIPT="${SCRIPT_DIR}/check_kernel_hardening_config.sh"

MAX_PATCH_AGE_DAYS="${MAX_PATCH_AGE_DAYS:-45}"
REQUIRED_KEYS="${REQUIRED_KEYS:-releasekey,platform,shared,media,networkstack,sdk_sandbox,bluetooth}"
RELEASE_GATE_MODE="${RELEASE_GATE_MODE:-strict}" # strict|presign
KERNEL_CONFIG="${KERNEL_CONFIG:-}"
KERNEL_HARDENING_PROFILE="${KERNEL_HARDENING_PROFILE:-}"

failures=0

usage() {
  echo "Usage: $0 <product_out_path> <target_files_zip> <signing_keys_dir>"
  echo "Example:"
  echo "  $0 out/target/product/a536b_ds \\"
  echo "     out/dist/aosp_a536b_ds-target_files.zip \\"
  echo "     keys/release"
  echo
  echo "Environment:"
  echo "  RELEASE_GATE_MODE=strict|presign   (default: strict)"
  echo "  MAX_PATCH_AGE_DAYS=45              (default: 45)"
  echo "  REQUIRED_KEYS=releasekey,...       (comma separated key aliases)"
  echo "  KERNEL_CONFIG=/path/to/.config     (optional kernel hardening audit)"
  echo "  KERNEL_HARDENING_PROFILE=/path/to/profile (optional)"
}

require_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    echo "FAIL: required file missing: ${path}"
    failures=$((failures + 1))
    return 1
  fi
  return 0
}

require_dir() {
  local path="$1"
  if [[ ! -d "${path}" ]]; then
    echo "FAIL: required directory missing: ${path}"
    failures=$((failures + 1))
    return 1
  fi
  return 0
}

zip_extract_to_tmp() {
  local zip_file="$1"
  local entry="$2"
  local tmp_file
  tmp_file="$(mktemp)"
  if unzip -p "${zip_file}" "${entry}" > "${tmp_file}" 2>/dev/null; then
    if [[ -s "${tmp_file}" ]]; then
      echo "${tmp_file}"
      return 0
    fi
  fi
  rm -f "${tmp_file}"
  return 1
}

read_prop() {
  local key="$1"
  local file="$2"
  awk -F= -v k="${key}" '$1==k { print $2; exit }' "${file}"
}

contains_test_or_dev_keys() {
  local file="$1"
  grep -Eiq '(testkey|test-keys|devkey|dev-keys)' "${file}"
}

extract_system_build_prop_from_target_files() {
  local target_files_zip="$1"
  local entry
  local tmp_file
  for entry in \
    "SYSTEM/build.prop" \
    "SYSTEM/etc/build.prop" \
    "SYSTEM/system/build.prop"; do
    if tmp_file="$(zip_extract_to_tmp "${target_files_zip}" "${entry}")"; then
      echo "${tmp_file}"
      return 0
    fi
  done
  return 1
}

check_signing_keys() {
  local keys_dir="$1"
  local key_name
  IFS=',' read -r -a key_list <<< "${REQUIRED_KEYS}"

  for key_name in "${key_list[@]}"; do
    key_name="${key_name//[[:space:]]/}"
    [[ -z "${key_name}" ]] && continue
    require_file "${keys_dir}/${key_name}.pk8" || true
    require_file "${keys_dir}/${key_name}.x509.pem" || true
  done
}

check_target_files_contents() {
  local target_files_zip="$1"
  local mode="$2"
  local apkcerts_tmp=""
  local miscinfo_tmp=""
  local apexkeys_tmp=""
  local otakeys_tmp=""
  local build_prop_tmp=""

  apkcerts_tmp="$(zip_extract_to_tmp "${target_files_zip}" "META/apkcerts.txt" || true)"
  miscinfo_tmp="$(zip_extract_to_tmp "${target_files_zip}" "META/misc_info.txt" || true)"
  apexkeys_tmp="$(zip_extract_to_tmp "${target_files_zip}" "META/apexkeys.txt" || true)"
  otakeys_tmp="$(zip_extract_to_tmp "${target_files_zip}" "META/otakeys.txt" || true)"
  build_prop_tmp="$(extract_system_build_prop_from_target_files "${target_files_zip}" || true)"

  if [[ -z "${apkcerts_tmp}" ]]; then
    echo "FAIL: META/apkcerts.txt missing or empty in ${target_files_zip}"
    failures=$((failures + 1))
  else
    echo "PASS: META/apkcerts.txt present"
  fi

  if [[ -z "${miscinfo_tmp}" ]]; then
    echo "FAIL: META/misc_info.txt missing or empty in ${target_files_zip}"
    failures=$((failures + 1))
  else
    echo "PASS: META/misc_info.txt present"
    local avb_enable
    avb_enable="$(awk -F= '$1=="avb_enable" { print $2; exit }' "${miscinfo_tmp}")"
    if [[ "${avb_enable}" != "true" ]]; then
      echo "FAIL: avb_enable=${avb_enable:-<missing>} in META/misc_info.txt (expected true)"
      failures=$((failures + 1))
    else
      echo "PASS: avb_enable=true"
    fi
  fi

  if [[ -z "${build_prop_tmp}" ]]; then
    echo "FAIL: SYSTEM build.prop missing in target_files zip"
    failures=$((failures + 1))
  else
    echo "PASS: SYSTEM build.prop present in target_files zip"
  fi

  if [[ "${mode}" == "strict" ]]; then
    local default_cert
    local build_tags

    if [[ -n "${apkcerts_tmp}" ]]; then
      if contains_test_or_dev_keys "${apkcerts_tmp}"; then
        echo "FAIL: test/dev keys found in META/apkcerts.txt"
        failures=$((failures + 1))
      else
        echo "PASS: META/apkcerts.txt does not reference test/dev keys"
      fi
    fi

    if [[ -n "${miscinfo_tmp}" ]]; then
      default_cert="$(awk -F= '$1=="default_system_dev_certificate" { print $2; exit }' "${miscinfo_tmp}")"
      if [[ -z "${default_cert}" ]]; then
        echo "FAIL: default_system_dev_certificate missing in META/misc_info.txt"
        failures=$((failures + 1))
      else
        echo "PASS: default_system_dev_certificate=${default_cert}"
        if [[ "${default_cert}" == *testkey* || "${default_cert}" == *devkey* ]]; then
          echo "FAIL: default_system_dev_certificate references test/dev key"
          failures=$((failures + 1))
        fi
      fi

      if contains_test_or_dev_keys "${miscinfo_tmp}"; then
        echo "FAIL: test/dev key markers found in META/misc_info.txt"
        failures=$((failures + 1))
      else
        echo "PASS: META/misc_info.txt does not reference test/dev keys"
      fi
    fi

    if [[ -n "${apexkeys_tmp}" ]]; then
      if contains_test_or_dev_keys "${apexkeys_tmp}"; then
        echo "FAIL: test/dev keys found in META/apexkeys.txt"
        failures=$((failures + 1))
      else
        echo "PASS: META/apexkeys.txt does not reference test/dev keys"
      fi
    else
      echo "INFO: META/apexkeys.txt not found (skipping apex key check)"
    fi

    if [[ -n "${otakeys_tmp}" ]]; then
      if contains_test_or_dev_keys "${otakeys_tmp}"; then
        echo "FAIL: test/dev keys found in META/otakeys.txt"
        failures=$((failures + 1))
      else
        echo "PASS: META/otakeys.txt does not reference test/dev keys"
      fi
    else
      echo "INFO: META/otakeys.txt not found (skipping OTA key list check)"
    fi

    if [[ -n "${build_prop_tmp}" ]]; then
      build_tags="$(read_prop ro.build.tags "${build_prop_tmp}")"
      if [[ -z "${build_tags}" ]]; then
        echo "FAIL: ro.build.tags missing from target_files SYSTEM build.prop"
        failures=$((failures + 1))
      else
        if [[ "${build_tags}" != *release-keys* ]]; then
          echo "FAIL: ro.build.tags=${build_tags} in target_files (must include release-keys)"
          failures=$((failures + 1))
        else
          echo "PASS: target_files ro.build.tags includes release-keys"
        fi
        if [[ "${build_tags}" == *test-keys* || "${build_tags}" == *dev-keys* ]]; then
          echo "FAIL: ro.build.tags=${build_tags} in target_files contains test/dev keys"
          failures=$((failures + 1))
        else
          echo "PASS: target_files ro.build.tags excludes test/dev keys"
        fi
      fi
    fi
  else
    echo "INFO: presign mode active; test/dev key checks are deferred until post-sign gate."
  fi

  rm -f "${apkcerts_tmp}" "${miscinfo_tmp}" "${apexkeys_tmp}" "${otakeys_tmp}" "${build_prop_tmp}"
}

if [[ $# -ne 3 ]]; then
  usage
  exit 1
fi

if [[ "${RELEASE_GATE_MODE}" != "strict" && "${RELEASE_GATE_MODE}" != "presign" ]]; then
  echo "Error: invalid RELEASE_GATE_MODE=${RELEASE_GATE_MODE} (expected strict or presign)"
  exit 1
fi

PRODUCT_OUT="$1"
TARGET_FILES_ZIP="$2"
SIGNING_KEYS_DIR="$3"

if [[ ! -f "${VERIFY_SCRIPT}" ]]; then
  echo "Error: verify script not found: ${VERIFY_SCRIPT}"
  exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "Error: unzip command is required but not found."
  exit 1
fi

echo "Running security verification baseline..."
ENFORCE_RELEASE_TAGS=0 MAX_PATCH_AGE_DAYS="${MAX_PATCH_AGE_DAYS}" \
  bash "${VERIFY_SCRIPT}" "${PRODUCT_OUT}" || failures=$((failures + 1))

require_file "${TARGET_FILES_ZIP}" || true
require_dir "${SIGNING_KEYS_DIR}" || true

if [[ -d "${SIGNING_KEYS_DIR}" ]]; then
  check_signing_keys "${SIGNING_KEYS_DIR}"
fi

if [[ -f "${TARGET_FILES_ZIP}" ]]; then
  check_target_files_contents "${TARGET_FILES_ZIP}" "${RELEASE_GATE_MODE}"
fi

if [[ -n "${KERNEL_CONFIG}" ]]; then
  if [[ ! -f "${KERNEL_CHECK_SCRIPT}" ]]; then
    echo "FAIL: kernel check script missing: ${KERNEL_CHECK_SCRIPT}"
    failures=$((failures + 1))
  else
    echo "Running kernel hardening config audit..."
    if [[ -n "${KERNEL_HARDENING_PROFILE}" ]]; then
      bash "${KERNEL_CHECK_SCRIPT}" "${KERNEL_CONFIG}" "${KERNEL_HARDENING_PROFILE}" || failures=$((failures + 1))
    else
      bash "${KERNEL_CHECK_SCRIPT}" "${KERNEL_CONFIG}" || failures=$((failures + 1))
    fi
  fi
else
  echo "INFO: KERNEL_CONFIG not set; kernel hardening audit skipped."
fi

if [[ "${failures}" -gt 0 ]]; then
  echo
  echo "Release gate FAILED with ${failures} issue(s). OTA packaging is blocked."
  exit 1
fi

echo
echo "Release gate PASSED. Secure OTA packaging may proceed."
