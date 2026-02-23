#!/usr/bin/env bash
set -euo pipefail

AOSP_ROOT="${1:-$(pwd)}"
STOCK_DUMP="${2:-}"
VENDOR_PATH="${VENDOR_PATH:-vendor/motorola/edge70_xt2601_2}"

if [[ -z "${STOCK_DUMP}" ]]; then
  echo "Usage: $0 <aosp_root> <stock_dump_dir>"
  echo "Example: $0 ~/android/rom ~/dumps/xt2601_2_stock"
  exit 1
fi

if [[ ! -d "${AOSP_ROOT}" ]]; then
  echo "Error: AOSP root not found: ${AOSP_ROOT}"
  exit 1
fi

if [[ ! -d "${STOCK_DUMP}" ]]; then
  echo "Error: stock dump dir not found: ${STOCK_DUMP}"
  exit 1
fi

VENDOR_ROOT="${AOSP_ROOT}/${VENDOR_PATH}"
CAMERA_PREBUILT_DIR="${VENDOR_ROOT}/camera/prebuilt"
BLOB_FILE="${VENDOR_ROOT}/proprietary-files.txt"

mkdir -p "${CAMERA_PREBUILT_DIR}"
mkdir -p "$(dirname "${BLOB_FILE}")"

python3 - "${STOCK_DUMP}" "${CAMERA_PREBUILT_DIR}" "${BLOB_FILE}" <<'PY'
import pathlib
import re
import shutil
import sys

stock_root = pathlib.Path(sys.argv[1]).resolve()
prebuilt_dir = pathlib.Path(sys.argv[2]).resolve()
blob_file = pathlib.Path(sys.argv[3]).resolve()

def score_apk(path: pathlib.Path) -> int:
    p = str(path).lower()
    name = path.name.lower()
    score = 0
    if name in ("motocamera.apk", "motorolacamera.apk", "com.motorola.camera3.apk"):
        score += 1000
    if "motorola" in p or "moto" in p:
        score += 200
    if "camera" in p:
        score += 200
    if "/priv-app/" in p or "\\priv-app\\" in p:
        score += 150
    if "/system_ext/" in p or "\\system_ext\\" in p:
        score += 80
    if name.endswith(".apk"):
        score += 20
    return score

apk_candidates = []
for apk in stock_root.rglob("*.apk"):
    low = str(apk).lower()
    if "camera" in low and ("moto" in low or "motorola" in low or "com.motorola.camera" in low):
        apk_candidates.append(apk)

selected_apk = None
if apk_candidates:
    selected_apk = max(apk_candidates, key=score_apk)
    target_apk = prebuilt_dir / "MotoCamera.apk"
    shutil.copy2(selected_apk, target_apk)
    print(f"Selected stock camera APK: {selected_apk}")
    print(f"Copied to: {target_apk}")
else:
    print("No Motorola camera APK candidate found in stock dump.")

allowed_roots = ("vendor/", "system/", "system_ext/", "product/", "odm/")
cam_keywords = re.compile(
    r"(camera|camx|mmcamera|arcsoft|eis|ois|hdr|bokeh|portrait|depth|chi|ais|sensor)",
    re.IGNORECASE,
)

blob_candidates = set()
for p in stock_root.rglob("*"):
    if not p.is_file():
        continue
    rel = p.relative_to(stock_root).as_posix()
    if not rel.startswith(allowed_roots):
        continue
    if cam_keywords.search(rel):
        blob_candidates.add(rel)

existing_lines = []
existing_set = set()
if blob_file.exists():
    for line in blob_file.read_text().splitlines():
        existing_lines.append(line)
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            existing_set.add(stripped)
else:
    existing_lines = [
        "# Motorola Edge 70 EU (XT2601-2) proprietary blobs",
        "#",
        "# Auto-generated additions can be appended below.",
    ]

new_entries = sorted(x for x in blob_candidates if x not in existing_set)

if new_entries:
    existing_lines.append("")
    existing_lines.append("# ---- Auto-added camera-related candidates ----")
    existing_lines.extend(new_entries)
    blob_file.write_text("\n".join(existing_lines) + "\n")
    print(f"Appended {len(new_entries)} camera-related blob candidates to {blob_file}")
else:
    print("No new camera-related blob candidates to append.")

print("Camera integration bootstrap complete.")
PY
