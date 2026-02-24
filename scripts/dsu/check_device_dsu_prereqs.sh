#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0"
  echo
  echo "Checks whether a connected device is ready for DSU sideload testing."
  echo
  echo "Environment:"
  echo "  ADB_SERIAL=<serial>         (optional)"
  echo "  MIN_FREE_DATA_GB=<number>   (default: 10)"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

MIN_FREE_DATA_GB="${MIN_FREE_DATA_GB:-10}"
ADB_SERIAL="${ADB_SERIAL:-}"

if ! [[ "${MIN_FREE_DATA_GB}" =~ ^[0-9]+$ ]]; then
  echo "Error: MIN_FREE_DATA_GB must be an integer"
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

get_prop() {
  local key="$1"
  adb_cmd shell getprop "${key}" 2>/dev/null | tr -d '\r'
}

pass() {
  echo "PASS: $1"
}

warn() {
  echo "WARN: $1"
  warnings=$((warnings + 1))
}

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

failures=0
warnings=0

echo "Checking connected device for DSU sideload readiness..."

if ! adb_cmd get-state >/dev/null 2>&1; then
  echo "Error: no adb device detected."
  exit 1
fi
pass "adb device is reachable"

sdk="$(get_prop ro.build.version.sdk)"
if [[ "${sdk}" =~ ^[0-9]+$ ]]; then
  if (( sdk >= 29 )); then
    pass "Android API level is ${sdk} (>= 29)"
  else
    fail "Android API level is ${sdk}; DSU requires API level 29+"
  fi
else
  fail "Could not read ro.build.version.sdk"
fi

treble="$(get_prop ro.treble.enabled)"
if [[ "${treble}" == "true" ]]; then
  pass "Treble is enabled (ro.treble.enabled=true)"
else
  fail "Treble is not enabled (ro.treble.enabled=${treble:-<empty>})"
fi

dynamic_partitions_boot="$(get_prop ro.boot.dynamic_partitions)"
dynamic_partitions_runtime="$(get_prop ro.dynamic_partitions)"
if [[ "${dynamic_partitions_boot}" == "true" || "${dynamic_partitions_runtime}" == "true" ]]; then
  pass "Dynamic partitions appear enabled"
else
  fail "Dynamic partitions not detected (ro.boot.dynamic_partitions=${dynamic_partitions_boot:-<empty>}, ro.dynamic_partitions=${dynamic_partitions_runtime:-<empty>})"
fi

dsu_pkg_path="$(adb_cmd shell pm path com.android.dynsystem 2>/dev/null | tr -d '\r')"
if [[ -n "${dsu_pkg_path}" ]]; then
  pass "DSU system app package is present (${dsu_pkg_path})"
else
  warn "DSU system app package not visible (com.android.dynsystem)"
fi

flash_locked="$(get_prop ro.boot.flash.locked)"
if [[ "${flash_locked}" == "0" ]]; then
  pass "Bootloader appears unlocked (ro.boot.flash.locked=0)"
elif [[ "${flash_locked}" == "1" ]]; then
  warn "Bootloader appears locked; non-OEM DSU images may fail verification"
else
  warn "Bootloader lock state unavailable (ro.boot.flash.locked=${flash_locked:-<empty>})"
fi

data_free_kb="$(adb_cmd shell df -k /data 2>/dev/null | awk 'NR==2 {print $4}' | tr -d '\r')"
min_free_kb=$((MIN_FREE_DATA_GB * 1024 * 1024))
if [[ "${data_free_kb}" =~ ^[0-9]+$ ]]; then
  if (( data_free_kb >= min_free_kb )); then
    pass "Free /data space is $((${data_free_kb} / 1024 / 1024)) GiB (target >= ${MIN_FREE_DATA_GB} GiB)"
  else
    warn "Free /data space is only $((${data_free_kb} / 1024 / 1024)) GiB; DSU installs can fail with low storage"
  fi
else
  warn "Could not parse free /data space from 'df -k /data'"
fi

echo
if (( failures > 0 )); then
  echo "DSU preflight FAILED with ${failures} issue(s) and ${warnings} warning(s)."
  exit 1
fi

echo "DSU preflight PASSED with ${warnings} warning(s)."
