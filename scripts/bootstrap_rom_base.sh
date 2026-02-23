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

copy_template_file() {
  local source_file="$1"
  local target_file="$2"

  if [[ -f "${target_file}" ]]; then
    echo "Existing ${target_file} detected; leaving current file untouched."
    return 0
  fi

  mkdir -p "$(dirname "${target_file}")"
  cp "${source_file}" "${target_file}"
  echo "Copied template ${source_file} -> ${target_file}"
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

echo "Copying dedicated Motorola Edge 70 XT2601-2 EU skeleton..."
copy_template_dir "${REPO_ROOT}/templates/device/motorola/edge70_xt2601_2" "device/motorola/edge70_xt2601_2"
copy_template_dir "${REPO_ROOT}/templates/vendor/motorola/edge70_xt2601_2" "vendor/motorola/edge70_xt2601_2"

echo "Copying security automation scripts..."
copy_template_file "${REPO_ROOT}/scripts/security/sync_latest_security_patches.sh" "scripts/security/sync_latest_security_patches.sh"
copy_template_file "${REPO_ROOT}/scripts/security/verify_release_security.sh" "scripts/security/verify_release_security.sh"
copy_template_file "${REPO_ROOT}/scripts/security/release_gate.sh" "scripts/security/release_gate.sh"
copy_template_file "${REPO_ROOT}/scripts/security/package_secure_ota.sh" "scripts/security/package_secure_ota.sh"
copy_template_file "${REPO_ROOT}/scripts/security/check_kernel_hardening_config.sh" "scripts/security/check_kernel_hardening_config.sh"
copy_template_file "${REPO_ROOT}/scripts/security/kernel_hardening_required.config" "scripts/security/kernel_hardening_required.config"
chmod +x scripts/security/*.sh

echo "Copying security baseline documentation..."
copy_template_file "${REPO_ROOT}/docs/security-baseline.md" "docs/security-baseline.md"

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
     lunch aosp_xt2601_2_eu-user
     m -j\$(nproc)
  4) Verify release security baseline:
     bash scripts/security/verify_release_security.sh \
       out/target/product/edge70_xt2601_2
  5) Run release gate before OTA packaging:
     RELEASE_GATE_MODE=presign bash scripts/security/release_gate.sh \
       out/target/product/edge70_xt2601_2 \
       out/dist/aosp_xt2601_2_eu-target_files-unsigned.zip \
       /path/to/release-keys
  6) Package signed OTA via secure wrapper:
     bash scripts/security/package_secure_ota.sh \
       "$(pwd)" \
       out/target/product/edge70_xt2601_2 \
       out/dist/aosp_xt2601_2_eu-target_files-unsigned.zip \
       /path/to/release-keys \
       out/dist/aosp_xt2601_2_eu-ota-signed.zip
  7) (Optional) Audit kernel hardening config:
     bash scripts/security/check_kernel_hardening_config.sh \
       /path/to/kernel/.config

EOF
