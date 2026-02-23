#!/usr/bin/env bash
set -euo pipefail

SERIAL="${ANDROID_SERIAL:-${1:-}}"
REPORT_DIR="${REPORT_DIR:-out/qa}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_FILE="${REPORT_DIR}/device-acceptance-${TIMESTAMP}.log"
failures=0

if ! command -v adb >/dev/null 2>&1; then
  echo "Error: adb not found in PATH."
  exit 1
fi

ADB=(adb)
if [[ -n "${SERIAL}" ]]; then
  ADB=(adb -s "${SERIAL}")
fi

mkdir -p "${REPORT_DIR}"

log() {
  echo "$1" | tee -a "${REPORT_FILE}"
}

pass() {
  log "PASS: $1"
}

fail() {
  log "FAIL: $1"
  failures=$((failures + 1))
}

run_shell_check() {
  local label="$1"
  local cmd="$2"
  local pattern="$3"
  local output

  output="$("${ADB[@]}" shell "${cmd}" 2>&1 || true)"
  {
    echo "----- ${label} -----"
    echo "CMD: ${cmd}"
    echo "${output}"
    echo
  } >> "${REPORT_FILE}"

  if printf '%s\n' "${output}" | rg -i "${pattern}" >/dev/null 2>&1; then
    pass "${label}"
  else
    fail "${label} (pattern not found: ${pattern})"
  fi
}

log "Running on-device acceptance suite..."
log "- Report: ${REPORT_FILE}"

if ! "${ADB[@]}" get-state >/dev/null 2>&1; then
  fail "adb device not available"
  echo "Device must be connected and authorized."
  exit 1
fi

run_shell_check "Telephony services present" "service list" "(phone|isub|iphonesubinfo|isms)"
run_shell_check "eSIM service present" "service list" "(euicc|euicc_service)"
run_shell_check "Camera services present" "service list" "(media\\.camera|cameraproxy)"
run_shell_check "5G indicators in telephony registry" "dumpsys telephony.registry" "(nrState|NETWORK_TYPE_NR|5g)"
run_shell_check "IMS/RCS stack visibility" "service list" "(ims|rcs)"
run_shell_check "SIM/eSIM subscription visibility" "dumpsys isub" "(SubInfo|Subscription)"

log
log "Manual checklist (must be verified on real network and SIM profile):"
log "  [ ] Place outgoing call"
log "  [ ] Receive incoming call"
log "  [ ] Send SMS"
log "  [ ] Receive SMS"
log "  [ ] Confirm mobile data attach"
log "  [ ] Confirm 5G NSA/SA registration in normal usage area"
log "  [ ] Download/enable eSIM profile"
log "  [ ] Test rear main camera"
log "  [ ] Test rear ultrawide/tele/macro cameras (if present)"
log "  [ ] Test front camera"
log "  [ ] Test video recording all cameras"

if [[ "${failures}" -gt 0 ]]; then
  echo
  echo "Device acceptance suite FAILED with ${failures} issue(s)."
  exit 1
fi

echo
echo "Device acceptance suite PASSED (automated checks)."
echo "Complete manual checklist before release sign-off."
