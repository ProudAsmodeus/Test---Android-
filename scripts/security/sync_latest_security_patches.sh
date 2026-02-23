#!/usr/bin/env bash
set -euo pipefail

AOSP_DIR="${1:-$(pwd)}"
JOBS="${JOBS:-$(nproc)}"
EXPECTED_BRANCH="${AOSP_BRANCH:-android-latest-release}"

if [[ ! -d "${AOSP_DIR}" ]]; then
  echo "Error: AOSP directory does not exist: ${AOSP_DIR}"
  exit 1
fi

cd "${AOSP_DIR}"

if [[ ! -d .repo ]]; then
  echo "Error: ${AOSP_DIR} is not a repo-initialized AOSP tree (.repo missing)."
  exit 1
fi

echo "Syncing latest sources from tracked branch..."
repo sync -c -j"${JOBS}" --fail-fast

mkdir -p out/security
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOCKFILE="out/security/manifest-lock-${STAMP}.xml"
repo manifest -r -o "${LOCKFILE}"

if [[ -f .repo/manifests/default.xml ]]; then
  if rg "revision=\"${EXPECTED_BRANCH}\"" .repo/manifests/default.xml >/dev/null 2>&1; then
    BRANCH_STATUS="matches expected ${EXPECTED_BRANCH}"
  else
    BRANCH_STATUS="does not explicitly match ${EXPECTED_BRANCH} in default.xml"
  fi
else
  BRANCH_STATUS="unknown (default.xml not found)"
fi

cat <<EOF

Security sync completed.

- AOSP tree: ${AOSP_DIR}
- Jobs used: ${JOBS}
- Manifest lock snapshot: ${LOCKFILE}
- Branch check: ${BRANCH_STATUS}

Next recommended step:
  Run scripts/security/verify_release_security.sh on your built product output.

EOF
