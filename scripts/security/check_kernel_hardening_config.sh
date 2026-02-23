#!/usr/bin/env bash
set -euo pipefail

KERNEL_CONFIG="${1:-}"
PROFILE_FILE="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kernel_hardening_required.config}"
failures=0

usage() {
  echo "Usage: $0 <kernel_config_path> [hardening_profile]"
  echo "Example:"
  echo "  $0 out/kernel/.config"
  echo "  $0 out/kernel/.config scripts/security/kernel_hardening_required.config"
}

if [[ -z "${KERNEL_CONFIG}" ]]; then
  usage
  exit 1
fi

if [[ ! -f "${KERNEL_CONFIG}" ]]; then
  echo "Error: kernel config not found: ${KERNEL_CONFIG}"
  exit 1
fi

if [[ ! -f "${PROFILE_FILE}" ]]; then
  echo "Error: hardening profile not found: ${PROFILE_FILE}"
  exit 1
fi

line_number=0
while IFS= read -r line || [[ -n "${line}" ]]; do
  line_number=$((line_number + 1))
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"

  if [[ -z "${line}" || "${line}" == \#* ]]; then
    continue
  fi

  if [[ "${line}" != CONFIG_*=* ]]; then
    echo "FAIL: invalid profile entry at ${PROFILE_FILE}:${line_number}: ${line}"
    failures=$((failures + 1))
    continue
  fi

  key="${line%%=*}"
  expected="${line#*=}"

  if [[ "${expected}" == "n" ]]; then
    if rg "^# ${key} is not set$" "${KERNEL_CONFIG}" >/dev/null 2>&1; then
      echo "PASS: ${key}=n"
    else
      echo "FAIL: ${key} expected n but is not disabled"
      failures=$((failures + 1))
    fi
  else
    if rg "^${key}=${expected}$" "${KERNEL_CONFIG}" >/dev/null 2>&1; then
      echo "PASS: ${key}=${expected}"
    else
      echo "FAIL: ${key} expected ${expected} but not found"
      failures=$((failures + 1))
    fi
  fi
done < "${PROFILE_FILE}"

if [[ "${failures}" -gt 0 ]]; then
  echo
  echo "Kernel hardening config audit FAILED with ${failures} issue(s)."
  exit 1
fi

echo
echo "Kernel hardening config audit PASSED."
