DEVICE_PATH := device/samsung/g930f

# Inherit Exynos 8890 common board settings.
include device/samsung/universal8890-common/BoardConfigCommon.mk

# Inherit device-specific proprietary flags.
include vendor/samsung/g930f/BoardConfigVendor.mk

# Assert valid Galaxy S7 unified variants.
TARGET_OTA_ASSERT_DEVICE := heroltebmc,herolteskt,heroltektt,heroltelgt,heroltexx,herolte

# Device-specific Bluetooth config path.
BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR := $(DEVICE_PATH)/bluetooth

# Fingerprint behavior.
TARGET_SEC_FP_USES_PERCENTAGE_SAMPLES := true

# Init library for per-SKU property overrides.
TARGET_INIT_VENDOR_LIB := //$(DEVICE_PATH):libinit_g930f

# Kernel source/defconfig baseline for herolte.
TARGET_KERNEL_SOURCE := kernel/samsung/universal8890
TARGET_KERNEL_CONFIG := exynos8890-herolte_defconfig
BOARD_KERNEL_IMAGE_NAME := Image

# Vendor patch level baseline from public bring-up trees.
VENDOR_SECURITY_PATCH := 2020-08-01

# Legacy non-A/B OTA behavior.
AB_OTA_UPDATER := false
ENABLE_VENDOR_RIL_SERVICE := true

# Device property overrides.
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop

# Keep device-specific Soong modules visible.
PRODUCT_SOONG_NAMESPACES += $(DEVICE_PATH)
