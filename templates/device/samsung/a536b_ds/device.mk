DEVICE_PATH := device/samsung/a536b_ds

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/non_ab_device.mk)

# Inherit Samsung Exynos common + ROM overlays.
$(call inherit-product, device/samsung/s5e8825-common/common.mk)
$(call inherit-product, vendor/rom/config/common.mk)
$(call inherit-product, vendor/rom/config/version.mk)

# Inherit generated proprietary package mappings when available.
-include vendor/samsung/a536b_ds/a536b_ds-vendor.mk

# Include stock Samsung camera prebuilt when provided.
-include vendor/samsung/a536b_ds/camera/camera-vendor.mk

PRODUCT_DEVICE := a536b_ds
PRODUCT_NAME := aosp_a536b_ds
PRODUCT_BRAND := samsung
PRODUCT_MODEL := Samsung Galaxy A53 5G (SM-A536B/DS)
PRODUCT_MANUFACTURER := samsung
PRODUCT_CHARACTERISTICS := phone
PRODUCT_SHIPPING_API_LEVEL := 34

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/init/init.a536b_ds.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.a536b_ds.rc
