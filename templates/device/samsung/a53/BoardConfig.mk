DEVICE_PATH := device/samsung/a53

# CPU architecture (64-bit)
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic

# Replace this with the actual SoC platform ID from stock sources/dumps.
# Applies to both generic and dual-SIM product flavors until split is required.
TARGET_BOARD_PLATFORM := TODO_A53_SOC

# Kernel placeholders; update to your real source/config.
TARGET_KERNEL_SOURCE := kernel/samsung/a53
TARGET_KERNEL_CONFIG := vendor/a53_defconfig
BOARD_KERNEL_IMAGE_NAME := Image

# Typical modern Samsung layout assumptions; verify from stock firmware.
AB_OTA_UPDATER := true
BOARD_USES_RECOVERY_AS_BOOT := true
BOARD_BUILD_SYSTEM_ROOT_IMAGE := false

# Partition sizes in bytes (placeholders; must be replaced).
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_DTBOIMG_PARTITION_SIZE := 33554432
BOARD_SUPER_PARTITION_SIZE := 9126805504
BOARD_SUPER_PARTITION_GROUPS := samsung_dynamic_partitions
BOARD_SAMSUNG_DYNAMIC_PARTITIONS_PARTITION_LIST := system system_ext product vendor odm
BOARD_SAMSUNG_DYNAMIC_PARTITIONS_SIZE := 9122611200

TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_ODM := odm
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := erofs

# Include device property overrides.
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop

# AVB placeholder setup.
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3

# Vendor blob-specific board flags live here once generated.
-include vendor/samsung/a53/BoardConfigVendor.mk
