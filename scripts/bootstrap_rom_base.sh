#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_DIR="${1:-$(pwd)}"

AOSP_MANIFEST_URL="${AOSP_MANIFEST_URL:-https://android.googlesource.com/platform/manifest}"
AOSP_BRANCH="${AOSP_BRANCH:-android-latest-release}"
ROM_NAME="${ROM_NAME:-BaseROM}"
ROM_VERSION="${ROM_VERSION:-0.1.0}"
SKIP_SYNC="${SKIP_SYNC:-0}"

if [[ ! -d "${TARGET_DIR}" ]]; then
  mkdir -p "${TARGET_DIR}"
fi
cd "${TARGET_DIR}"
echo "Using target source directory: ${TARGET_DIR}"

copy_template_dir() {
  local source_dir="$1"
  local target_dir="$2"

  if [[ -d "${target_dir}" ]]; then
    echo "Existing ${target_dir} detected; leaving current files untouched."
    return 0
  fi

  mkdir -p "${target_dir}"
  cp -R "${source_dir}/." "${target_dir}/"
  echo "Copied template ${source_dir} -> ${target_dir}"
}

if ! command -v repo >/dev/null 2>&1; then
  echo "Error: repo tool not found in PATH."
  echo "Install instructions: https://source.android.com/docs/setup/download"
  exit 1
fi

if [[ ! -d .repo ]]; then
  echo "Initializing AOSP manifest from ${AOSP_MANIFEST_URL} (${AOSP_BRANCH})..."
  repo init -u "${AOSP_MANIFEST_URL}" -b "${AOSP_BRANCH}"
else
  echo "Existing .repo detected; skipping repo init."
fi

mkdir -p .repo/local_manifests

LOCAL_MANIFEST_TEMPLATE="${REPO_ROOT}/templates/local_manifests/rom-base.xml"
LOCAL_MANIFEST_TARGET=".repo/local_manifests/rom-base.xml"
cp "${LOCAL_MANIFEST_TEMPLATE}" "${LOCAL_MANIFEST_TARGET}"
echo "Copied local manifest template to ${LOCAL_MANIFEST_TARGET}"

echo "Copying ROM vendor base..."
mkdir -p vendor/rom
cp -R "${REPO_ROOT}/templates/vendor/rom/." vendor/rom/

echo "Copying Motorola Edge 70 (12GB/512GB) skeleton..."
copy_template_dir "${REPO_ROOT}/templates/device/motorola/edge70" "device/motorola/edge70"
copy_template_dir "${REPO_ROOT}/templates/vendor/motorola/edge70" "vendor/motorola/edge70"

VERSION_FILE="vendor/rom/config/version.mk"
ESCAPED_ROM_NAME="$(printf '%s\n' "${ROM_NAME}" | sed 's/[&|]/\\&/g')"
ESCAPED_ROM_VERSION="$(printf '%s\n' "${ROM_VERSION}" | sed 's/[&|]/\\&/g')"
sed -i "s|^ROM_NAME := .*|ROM_NAME := ${ESCAPED_ROM_NAME}|" "${VERSION_FILE}"
sed -i "s|^ROM_VERSION := .*|ROM_VERSION := ${ESCAPED_ROM_VERSION}|" "${VERSION_FILE}"

if [[ "${SKIP_SYNC}" != "1" ]]; then
  JOBS="$(nproc)"
  echo "Syncing sources with repo sync -c -j${JOBS} ..."
  repo sync -c -j"${JOBS}" --fail-fast
else
  echo "SKIP_SYNC=1 set; skipping repo sync."
fi

cat <<EOF

ROM base bootstrap complete.

Next steps:
  1) Add your device/kernel/vendor projects in:
     .repo/local_manifests/rom-base.xml
  2) Sync again after updating manifests:
     repo sync -c -j\$(nproc)
  3) Build:
     source build/envsetup.sh
     lunch aosp_edge70_eu-userdebug
     m -j\$(nproc)

EOF
