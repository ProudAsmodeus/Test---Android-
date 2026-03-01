DEVICE_PATH := device/samsung/g930f

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/non_ab_device.mk)

# Inherit Exynos 8890 common platform configuration.
$(call inherit-product, device/samsung/universal8890-common/device-common.mk)
$(call inherit-product, vendor/rom/config/common.mk)
$(call inherit-product, vendor/rom/config/version.mk)

# Inherit generated proprietary package mappings when available.
-include vendor/samsung/g930f/g930f-vendor.mk
-include vendor/samsung/universal8890-common/universal8890-common-vendor.mk

# Include stock Samsung camera prebuilt integration when present.
-include vendor/samsung/g930f/camera/camera-vendor.mk

PRODUCT_DEVICE := g930f
PRODUCT_NAME := aosp_g930f
PRODUCT_BRAND := samsung
PRODUCT_MODEL := Samsung Galaxy S7 (SM-G930F)
PRODUCT_MANUFACTURER := samsung
PRODUCT_CHARACTERISTICS := phone
PRODUCT_SHIPPING_API_LEVEL := 23

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_NAME=heroltexx \
    PRIVATE_BUILD_DESC="heroltexx-user 8.0.0 R16NW G930FXXS8ETC3 release-keys"

BUILD_FINGERPRINT := samsung/heroltexx/herolte:8.0.0/R16NW/G930FXXS8ETC3:user/release-keys

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/init/init.g930f.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.g930f.rc
