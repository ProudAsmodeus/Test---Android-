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

echo "Copying dedicated Samsung Galaxy A53 5G (SM-A536B/DS) skeleton..."
copy_template_dir "${REPO_ROOT}/templates/device/samsung/a536b_ds" "device/samsung/a536b_ds"
copy_template_dir "${REPO_ROOT}/templates/vendor/samsung/a536b_ds" "vendor/samsung/a536b_ds"

echo "Copying built-in security firewall app..."
copy_template_dir "${REPO_ROOT}/templates/packages/apps/SecureConnectionGuard" "packages/apps/SecureConnectionGuard"

echo "Copying built-in AdGuard DNS control app..."
copy_template_dir "${REPO_ROOT}/templates/packages/apps/AdGuardControl" "packages/apps/AdGuardControl"

echo "Copying security automation scripts..."
copy_template_file "${REPO_ROOT}/scripts/security/sync_latest_security_patches.sh" "scripts/security/sync_latest_security_patches.sh"
copy_template_file "${REPO_ROOT}/scripts/security/verify_release_security.sh" "scripts/security/verify_release_security.sh"
copy_template_file "${REPO_ROOT}/scripts/security/release_gate.sh" "scripts/security/release_gate.sh"
copy_template_file "${REPO_ROOT}/scripts/security/package_secure_ota.sh" "scripts/security/package_secure_ota.sh"
copy_template_file "${REPO_ROOT}/scripts/security/check_kernel_hardening_config.sh" "scripts/security/check_kernel_hardening_config.sh"
copy_template_file "${REPO_ROOT}/scripts/security/kernel_hardening_required.config" "scripts/security/kernel_hardening_required.config"
chmod +x scripts/security/*.sh

echo "Copying quality and feature-readiness scripts..."
copy_template_file "${REPO_ROOT}/scripts/qa/validate_feature_readiness.sh" "scripts/qa/validate_feature_readiness.sh"
copy_template_file "${REPO_ROOT}/scripts/qa/run_device_acceptance_suite.sh" "scripts/qa/run_device_acceptance_suite.sh"
chmod +x scripts/qa/*.sh

echo "Copying camera integration helper scripts..."
copy_template_file "${REPO_ROOT}/scripts/camera/integrate_samsung_camera.sh" "scripts/camera/integrate_samsung_camera.sh"
chmod +x scripts/camera/*.sh

echo "Copying security baseline documentation..."
copy_template_file "${REPO_ROOT}/docs/security-baseline.md" "docs/security-baseline.md"
copy_template_file "${REPO_ROOT}/docs/feature-readiness.md" "docs/feature-readiness.md"
copy_template_file "${REPO_ROOT}/docs/camera-stock-parity.md" "docs/camera-stock-parity.md"

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
     lunch aosp_a536b_ds-user
     m -j\$(nproc)
     # SecureConnectionGuard and AdGuardControl apps are built into this product.
  4) Verify release security baseline:
     bash scripts/security/verify_release_security.sh \
       out/target/product/a536b_ds
  5) Run release gate before OTA packaging:
     RELEASE_GATE_MODE=presign bash scripts/security/release_gate.sh \
       out/target/product/a536b_ds \
       out/dist/aosp_a536b_ds-target_files-unsigned.zip \
       /path/to/release-keys
  6) Package signed OTA via secure wrapper:
     bash scripts/security/package_secure_ota.sh \
       "$(pwd)" \
       out/target/product/a536b_ds \
       out/dist/aosp_a536b_ds-target_files-unsigned.zip \
       /path/to/release-keys \
       out/dist/aosp_a536b_ds-ota-signed.zip
  7) (Optional) Audit kernel hardening config:
     bash scripts/security/check_kernel_hardening_config.sh \
       /path/to/kernel/.config
  8) Validate source-tree feature readiness before release:
     bash scripts/qa/validate_feature_readiness.sh "$(pwd)"
  9) Run on-device acceptance checks (after flashing build):
     bash scripts/qa/run_device_acceptance_suite.sh
  10) Bootstrap stock camera parity path (optional but recommended):
      bash scripts/camera/integrate_samsung_camera.sh "$(pwd)" /path/to/stock_dump

EOF
