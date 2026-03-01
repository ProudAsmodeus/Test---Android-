#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <aosp_root> [product_out_path] [output_dir]"
  echo
  echo "Builds DSU sideload artifacts from a compiled product output:"
  echo "  - non-sparse system.raw"
  echo "  - gzipped system.raw.gz for VerificationActivity sideload"
  echo "  - optional dsu.zip package with selected partition images"
  echo
  echo "Environment:"
  echo "  SYSTEM_IMAGE=<path>                (default: <product_out>/system.img)"
  echo "  INCLUDE_DSU_ZIP=1|0                (default: 1)"
  echo "  DSU_ZIP_PARTITIONS=\"system product system_ext\""
  echo "                                     (default: system product system_ext)"
  echo "  DSU_ZIP_NAME=<filename.zip>        (default: aosp_a536b_ds-dsu.zip)"
  echo "  SYSTEM_RAW_NAME=<filename>         (default: system.raw)"
  echo "  SYSTEM_RAW_GZ_NAME=<filename>      (default: system.raw.gz)"
  echo "  USERDATA_SIZE_BYTES=<bytes>        (default: 8589934592)"
}

require_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    echo "Error: required file missing: ${path}"
    exit 1
  fi
}

require_dir() {
  local path="$1"
  if [[ ! -d "${path}" ]]; then
    echo "Error: required directory missing: ${path}"
    exit 1
  fi
}

require_cmd() {
  local name="$1"
  if ! command -v "${name}" >/dev/null 2>&1; then
    echo "Error: command not found: ${name}"
    exit 1
  fi
}

find_simg2img() {
  local host_tool="$1"
  if [[ -x "${host_tool}" ]]; then
    printf '%s\n' "${host_tool}"
    return 0
  fi

  if command -v simg2img >/dev/null 2>&1; then
    command -v simg2img
    return 0
  fi

  return 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

AOSP_ROOT="${1:-$(pwd)}"
PRODUCT_OUT="${2:-${AOSP_ROOT}/out/target/product/a536b_ds}"
OUTPUT_DIR="${3:-${AOSP_ROOT}/out/dist/dsu}"

SYSTEM_IMAGE="${SYSTEM_IMAGE:-${PRODUCT_OUT}/system.img}"
SYSTEM_RAW_NAME="${SYSTEM_RAW_NAME:-system.raw}"
SYSTEM_RAW_GZ_NAME="${SYSTEM_RAW_GZ_NAME:-system.raw.gz}"
INCLUDE_DSU_ZIP="${INCLUDE_DSU_ZIP:-1}"
DSU_ZIP_PARTITIONS="${DSU_ZIP_PARTITIONS:-system product system_ext}"
DSU_ZIP_NAME="${DSU_ZIP_NAME:-aosp_a536b_ds-dsu.zip}"
USERDATA_SIZE_BYTES="${USERDATA_SIZE_BYTES:-8589934592}"

require_dir "${AOSP_ROOT}"
require_dir "${PRODUCT_OUT}"
require_file "${SYSTEM_IMAGE}"
require_cmd stat
require_cmd gzip
require_cmd od

mkdir -p "${OUTPUT_DIR}"

SYSTEM_RAW_PATH="${OUTPUT_DIR}/${SYSTEM_RAW_NAME}"
SYSTEM_RAW_GZ_PATH="${OUTPUT_DIR}/${SYSTEM_RAW_GZ_NAME}"
DSU_ENV_PATH="${OUTPUT_DIR}/dsu-artifacts.env"
DSU_INSTALL_HELPER="${OUTPUT_DIR}/install_dsu_from_host.sh"
DSU_ZIP_PATH="${OUTPUT_DIR}/${DSU_ZIP_NAME}"

rm -f "${SYSTEM_RAW_PATH}" "${SYSTEM_RAW_GZ_PATH}" "${DSU_ENV_PATH}" "${DSU_INSTALL_HELPER}"

echo "Preparing DSU artifacts..."
echo "- AOSP root:   ${AOSP_ROOT}"
echo "- Product out: ${PRODUCT_OUT}"
echo "- Output dir:  ${OUTPUT_DIR}"

sparse_magic="$(od -An -tx4 -N4 "${SYSTEM_IMAGE}" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"
is_sparse_image=0
if [[ "${sparse_magic}" == "ED26FF3A" ]]; then
  is_sparse_image=1
fi

if [[ "${is_sparse_image}" -eq 1 ]]; then
  host_simg2img="${AOSP_ROOT}/out/host/linux-x86/bin/simg2img"
  simg2img_bin="$(find_simg2img "${host_simg2img}" || true)"
  if [[ -z "${simg2img_bin}" ]]; then
    echo "Error: ${SYSTEM_IMAGE} is sparse and simg2img is unavailable."
    echo "Build host tools first or install simg2img in PATH."
    exit 1
  fi
  echo "Converting sparse image to raw with: ${simg2img_bin}"
  "${simg2img_bin}" "${SYSTEM_IMAGE}" "${SYSTEM_RAW_PATH}"
else
  echo "system image is already non-sparse; copying to ${SYSTEM_RAW_PATH}"
  cp "${SYSTEM_IMAGE}" "${SYSTEM_RAW_PATH}"
fi

echo "Compressing raw image to ${SYSTEM_RAW_GZ_PATH}"
gzip -c "${SYSTEM_RAW_PATH}" > "${SYSTEM_RAW_GZ_PATH}"

system_raw_size="$(stat -c%s "${SYSTEM_RAW_PATH}")"
system_raw_gz_size="$(stat -c%s "${SYSTEM_RAW_GZ_PATH}")"
remote_path="/storage/emulated/0/Download/${SYSTEM_RAW_GZ_NAME}"

zip_included_images=()
if [[ "${INCLUDE_DSU_ZIP}" == "1" ]]; then
  require_cmd zip
  staging_dir="${OUTPUT_DIR}/.dsu_zip_staging"
  rm -rf "${staging_dir}"
  mkdir -p "${staging_dir}"

  while IFS= read -r partition_name; do
    [[ -z "${partition_name}" ]] && continue
    partition_img="${PRODUCT_OUT}/${partition_name}.img"
    if [[ -f "${partition_img}" ]]; then
      cp "${partition_img}" "${staging_dir}/${partition_name}.img"
      zip_included_images+=("${partition_name}.img")
    fi
  done < <(printf '%s\n' "${DSU_ZIP_PARTITIONS}" | tr ',' ' ' | awk '{for (i = 1; i <= NF; i++) print $i}')

  if [[ "${#zip_included_images[@]}" -eq 0 ]]; then
    echo "Warning: no DSU zip partitions found from DSU_ZIP_PARTITIONS='${DSU_ZIP_PARTITIONS}'."
    echo "Skipping DSU ZIP package creation."
    rm -rf "${staging_dir}"
  else
    has_system_image=0
    for image_name in "${zip_included_images[@]}"; do
      if [[ "${image_name}" == "system.img" ]]; then
        has_system_image=1
        break
      fi
    done
    if [[ "${has_system_image}" -ne 1 ]]; then
      echo "Error: DSU ZIP set does not include system.img."
      echo "Add 'system' to DSU_ZIP_PARTITIONS."
      exit 1
    fi

    echo "Creating DSU package ${DSU_ZIP_PATH} with: ${zip_included_images[*]}"
    rm -f "${DSU_ZIP_PATH}"
    (
      cd "${staging_dir}"
      zip -q -9 "${DSU_ZIP_PATH}" "${zip_included_images[@]}"
    )
    rm -rf "${staging_dir}"
  fi
fi

cat > "${DSU_ENV_PATH}" <<EOF
SYSTEM_RAW_PATH="${SYSTEM_RAW_PATH}"
SYSTEM_RAW_SIZE="${system_raw_size}"
SYSTEM_RAW_GZ_PATH="${SYSTEM_RAW_GZ_PATH}"
SYSTEM_RAW_GZ_SIZE="${system_raw_gz_size}"
REMOTE_GSI_PATH="${remote_path}"
USERDATA_SIZE_BYTES="${USERDATA_SIZE_BYTES}"
EOF

cat > "${DSU_INSTALL_HELPER}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

adb push "${SYSTEM_RAW_GZ_PATH}" "${remote_path}"
adb shell am start-activity \\
  -n com.android.dynsystem/com.android.dynsystem.VerificationActivity \\
  -a android.os.image.action.START_INSTALL \\
  -d "file://${remote_path}" \\
  --el KEY_SYSTEM_SIZE "${system_raw_size}" \\
  --el KEY_USERDATA_SIZE "${USERDATA_SIZE_BYTES}"
EOF
chmod +x "${DSU_INSTALL_HELPER}"

echo
echo "DSU artifacts ready:"
echo "- Raw system image:      ${SYSTEM_RAW_PATH} (${system_raw_size} bytes)"
echo "- Gzipped sideload image:${SYSTEM_RAW_GZ_PATH} (${system_raw_gz_size} bytes)"
if [[ -f "${DSU_ZIP_PATH}" ]]; then
  echo "- DSU package zip:       ${DSU_ZIP_PATH}"
fi
echo "- Env metadata:          ${DSU_ENV_PATH}"
echo "- Host install helper:   ${DSU_INSTALL_HELPER}"
echo
echo "Next:"
echo "  source \"${DSU_ENV_PATH}\""
echo "  bash scripts/dsu/run_dsu_sideload.sh \"\${SYSTEM_RAW_GZ_PATH}\" \"\${SYSTEM_RAW_SIZE}\""
