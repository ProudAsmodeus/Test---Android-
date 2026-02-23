DEVICE_PATH := device/motorola/edge70_xt2601_2

# CPU architecture (64-bit)
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic

# Replace this with the actual SoC platform ID from stock sources/dumps.
TARGET_BOARD_PLATFORM := TODO_XT2601_2_SOC

# Kernel placeholders; update to your real source/config.
TARGET_KERNEL_SOURCE := kernel/motorola/edge70_xt2601_2
TARGET_KERNEL_CONFIG := vendor/edge70_xt2601_2_defconfig
BOARD_KERNEL_IMAGE_NAME := Image

AB_OTA_UPDATER := true
BOARD_USES_RECOVERY_AS_BOOT := true
BOARD_BUILD_SYSTEM_ROOT_IMAGE := false

# Partition sizes in bytes (placeholders; must be replaced).
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_DTBOIMG_PARTITION_SIZE := 33554432
BOARD_SUPER_PARTITION_SIZE := 9126805504
BOARD_SUPER_PARTITION_GROUPS := moto_dynamic_partitions
BOARD_MOTO_DYNAMIC_PARTITIONS_PARTITION_LIST := system system_ext product vendor odm
BOARD_MOTO_DYNAMIC_PARTITIONS_SIZE := 9122611200

TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_ODM := odm
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := erofs

TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop

BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3

-include vendor/motorola/edge70_xt2601_2/BoardConfigVendor.mk
