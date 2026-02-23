#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="${SCRIPT_DIR}/verify_release_security.sh"

MAX_PATCH_AGE_DAYS="${MAX_PATCH_AGE_DAYS:-45}"
REQUIRED_KEYS="${REQUIRED_KEYS:-releasekey,platform,shared,media,networkstack,sdk_sandbox,bluetooth}"

failures=0

usage() {
  echo "Usage: $0 <product_out_path> <target_files_zip> <signing_keys_dir>"
  echo "Example:"
  echo "  $0 out/target/product/edge70_xt2601_2 \\"
  echo "     out/dist/aosp_xt2601_2_eu-target_files.zip \\"
  echo "     keys/release"
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

find_prop_file() {
  local candidate
  for candidate in "$@"; do
    if [[ -f "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done
  return 1
}

read_prop() {
  local key="$1"
  local file="$2"
  awk -F= -v k="${key}" '$1==k { print $2; exit }' "${file}"
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
  local apkcerts_tmp
  local miscinfo_tmp
  apkcerts_tmp="$(mktemp)"
  miscinfo_tmp="$(mktemp)"

  unzip -p "${target_files_zip}" META/apkcerts.txt > "${apkcerts_tmp}" || true
  unzip -p "${target_files_zip}" META/misc_info.txt > "${miscinfo_tmp}" || true

  if [[ ! -s "${apkcerts_tmp}" ]]; then
    echo "FAIL: META/apkcerts.txt missing or empty in ${target_files_zip}"
    failures=$((failures + 1))
  else
    echo "PASS: META/apkcerts.txt present"
    if grep -Eiq '(testkey|devkey)' "${apkcerts_tmp}"; then
      echo "FAIL: test/dev keys found in META/apkcerts.txt"
      failures=$((failures + 1))
    else
      echo "PASS: META/apkcerts.txt does not reference test/dev keys"
    fi
  fi

  if [[ ! -s "${miscinfo_tmp}" ]]; then
    echo "FAIL: META/misc_info.txt missing or empty in ${target_files_zip}"
    failures=$((failures + 1))
  else
    echo "PASS: META/misc_info.txt present"
    local default_cert
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

    if grep -Eiq '(testkey|devkey)' "${miscinfo_tmp}"; then
      echo "FAIL: test/dev key markers found in META/misc_info.txt"
      failures=$((failures + 1))
    else
      echo "PASS: META/misc_info.txt does not reference test/dev keys"
    fi

    local avb_enable
    avb_enable="$(awk -F= '$1=="avb_enable" { print $2; exit }' "${miscinfo_tmp}")"
    if [[ "${avb_enable}" != "true" ]]; then
      echo "FAIL: avb_enable=${avb_enable:-<missing>} in META/misc_info.txt (expected true)"
      failures=$((failures + 1))
    else
      echo "PASS: avb_enable=true"
    fi
  fi

  rm -f "${apkcerts_tmp}" "${miscinfo_tmp}"
}

if [[ $# -ne 3 ]]; then
  usage
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
MAX_PATCH_AGE_DAYS="${MAX_PATCH_AGE_DAYS}" bash "${VERIFY_SCRIPT}" "${PRODUCT_OUT}" || failures=$((failures + 1))

system_prop_file="$(find_prop_file \
  "${PRODUCT_OUT}/system/build.prop" \
  "${PRODUCT_OUT}/system/system/build.prop")" || {
    echo "FAIL: unable to locate system build.prop"
    failures=$((failures + 1))
  }

if [[ -n "${system_prop_file:-}" ]]; then
  build_tags="$(read_prop ro.build.tags "${system_prop_file}")"
  if [[ -z "${build_tags}" ]]; then
    echo "FAIL: ro.build.tags missing from system build.prop"
    failures=$((failures + 1))
  else
    if [[ "${build_tags}" != *release-keys* ]]; then
      echo "FAIL: ro.build.tags=${build_tags} (must include release-keys)"
      failures=$((failures + 1))
    else
      echo "PASS: ro.build.tags includes release-keys"
    fi
    if [[ "${build_tags}" == *test-keys* || "${build_tags}" == *dev-keys* ]]; then
      echo "FAIL: ro.build.tags contains test/dev keys (${build_tags})"
      failures=$((failures + 1))
    else
      echo "PASS: ro.build.tags does not contain test/dev keys"
    fi
  fi
fi

require_file "${TARGET_FILES_ZIP}" || true
require_dir "${SIGNING_KEYS_DIR}" || true

if [[ -d "${SIGNING_KEYS_DIR}" ]]; then
  check_signing_keys "${SIGNING_KEYS_DIR}"
fi

if [[ -f "${TARGET_FILES_ZIP}" ]]; then
  check_target_files_contents "${TARGET_FILES_ZIP}"
fi

if [[ "${failures}" -gt 0 ]]; then
  echo
  echo "Release gate FAILED with ${failures} issue(s). OTA packaging is blocked."
  exit 1
fi

echo
echo "Release gate PASSED. Secure OTA packaging may proceed."
