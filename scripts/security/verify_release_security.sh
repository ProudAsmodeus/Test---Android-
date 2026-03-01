#!/usr/bin/env bash
set -euo pipefail

PRODUCT_OUT="${1:-}"
MAX_PATCH_AGE_DAYS="${MAX_PATCH_AGE_DAYS:-45}"
ENFORCE_RELEASE_TAGS="${ENFORCE_RELEASE_TAGS:-0}"
failures=0

usage() {
  echo "Usage: $0 <product_out_path>"
  echo "Example: $0 out/target/product/a536b_ds"
}

if [[ -z "${PRODUCT_OUT}" ]]; then
  usage
  exit 1
fi

if [[ ! -d "${PRODUCT_OUT}" ]]; then
  echo "Error: product_out_path does not exist: ${PRODUCT_OUT}"
  exit 1
fi

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

patch_age_days() {
  local patch_date="$1"
  python3 - "${patch_date}" <<'PY'
import datetime
import sys

patch = sys.argv[1].strip()
try:
    d = datetime.datetime.strptime(patch, "%Y-%m-%d").date()
except ValueError:
    print(-1)
    raise SystemExit(0)

today = datetime.date.today()
print((today - d).days)
PY
}

system_prop_file="$(find_prop_file \
  "${PRODUCT_OUT}/system/build.prop" \
  "${PRODUCT_OUT}/system/system/build.prop")" || {
    echo "Error: could not find system build.prop in ${PRODUCT_OUT}"
    exit 1
  }

vendor_prop_file="$(find_prop_file \
  "${PRODUCT_OUT}/vendor/build.prop" \
  "${PRODUCT_OUT}/vendor/vendor/build.prop" || true)"

system_patch="$(read_prop ro.build.version.security_patch "${system_prop_file}")"
build_type="$(read_prop ro.build.type "${system_prop_file}")"
debuggable="$(read_prop ro.debuggable "${system_prop_file}")"
build_tags="$(read_prop ro.build.tags "${system_prop_file}")"
checkjni="$(read_prop ro.kernel.android.checkjni "${system_prop_file}")"
adb_secure="$(read_prop ro.adb.secure "${system_prop_file}")"

vendor_patch=""
if [[ -n "${vendor_prop_file:-}" ]]; then
  vendor_patch="$(read_prop ro.vendor.build.security_patch "${vendor_prop_file}")"
  if [[ -z "${vendor_patch}" ]]; then
    vendor_patch="$(read_prop ro.build.version.security_patch "${vendor_prop_file}")"
  fi
fi

echo "System prop file: ${system_prop_file}"
if [[ -n "${vendor_prop_file:-}" ]]; then
  echo "Vendor prop file: ${vendor_prop_file}"
else
  echo "Vendor prop file: not found (vendor patch check skipped)"
fi

if [[ -z "${system_patch}" ]]; then
  echo "FAIL: ro.build.version.security_patch missing in system build.prop"
  failures=$((failures + 1))
else
  age="$(patch_age_days "${system_patch}")"
  if [[ "${age}" -lt 0 ]]; then
    echo "FAIL: invalid system security patch date format: ${system_patch}"
    failures=$((failures + 1))
  elif [[ "${age}" -gt "${MAX_PATCH_AGE_DAYS}" ]]; then
    echo "FAIL: system patch level ${system_patch} is ${age} days old (max ${MAX_PATCH_AGE_DAYS})"
    failures=$((failures + 1))
  else
    echo "PASS: system patch level ${system_patch} (${age} days old)"
  fi
fi

if [[ -n "${vendor_patch}" ]]; then
  v_age="$(patch_age_days "${vendor_patch}")"
  if [[ "${v_age}" -lt 0 ]]; then
    echo "FAIL: invalid vendor security patch date format: ${vendor_patch}"
    failures=$((failures + 1))
  elif [[ "${v_age}" -gt "${MAX_PATCH_AGE_DAYS}" ]]; then
    echo "FAIL: vendor patch level ${vendor_patch} is ${v_age} days old (max ${MAX_PATCH_AGE_DAYS})"
    failures=$((failures + 1))
  else
    echo "PASS: vendor patch level ${vendor_patch} (${v_age} days old)"
  fi
elif [[ -n "${vendor_prop_file:-}" ]]; then
  echo "FAIL: vendor build.prop present but no vendor security patch property found"
  failures=$((failures + 1))
fi

if [[ "${build_type}" != "user" ]]; then
  echo "FAIL: ro.build.type=${build_type:-<missing>} (expected user for secure release)"
  failures=$((failures + 1))
else
  echo "PASS: ro.build.type=user"
fi

if [[ "${debuggable}" != "0" ]]; then
  echo "FAIL: ro.debuggable=${debuggable:-<missing>} (expected 0 for secure release)"
  failures=$((failures + 1))
else
  echo "PASS: ro.debuggable=0"
fi

if [[ -n "${adb_secure}" && "${adb_secure}" != "1" ]]; then
  echo "FAIL: ro.adb.secure=${adb_secure} (expected 1 for secure release)"
  failures=$((failures + 1))
else
  if [[ -n "${adb_secure}" ]]; then
    echo "PASS: ro.adb.secure=1"
  else
    echo "INFO: ro.adb.secure not present in system build.prop"
  fi
fi

if [[ -n "${checkjni}" && "${checkjni}" != "0" ]]; then
  echo "FAIL: ro.kernel.android.checkjni=${checkjni} (expected 0 for release)"
  failures=$((failures + 1))
else
  if [[ -n "${checkjni}" ]]; then
    echo "PASS: ro.kernel.android.checkjni=0"
  else
    echo "INFO: ro.kernel.android.checkjni not present in system build.prop"
  fi
fi

if [[ "${ENFORCE_RELEASE_TAGS}" == "1" ]]; then
  if [[ -z "${build_tags}" ]]; then
    echo "FAIL: ro.build.tags missing (expected release-keys)"
    failures=$((failures + 1))
  else
    if [[ "${build_tags}" != *release-keys* ]]; then
      echo "FAIL: ro.build.tags=${build_tags} (must include release-keys)"
      failures=$((failures + 1))
    else
      echo "PASS: ro.build.tags includes release-keys"
    fi

    if [[ "${build_tags}" == *test-keys* || "${build_tags}" == *dev-keys* ]]; then
      echo "FAIL: ro.build.tags=${build_tags} (must not include test/dev keys)"
      failures=$((failures + 1))
    else
      echo "PASS: ro.build.tags excludes test/dev keys"
    fi
  fi
else
  echo "INFO: ro.build.tags strict check skipped (ENFORCE_RELEASE_TAGS=0)"
fi

if [[ ! -f "${PRODUCT_OUT}/vbmeta.img" ]]; then
  echo "FAIL: vbmeta.img missing in product output (AVB artifact required)"
  failures=$((failures + 1))
else
  echo "PASS: vbmeta.img present"
fi

if [[ "${failures}" -gt 0 ]]; then
  echo
  echo "Security verification FAILED with ${failures} issue(s)."
  exit 1
fi

echo
echo "Security verification PASSED."
