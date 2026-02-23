DEVICE_PATH := device/samsung/a536b_ds

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

$(call inherit-product, vendor/rom/config/common.mk)
$(call inherit-product, vendor/rom/config/version.mk)

# Include stock Samsung camera prebuilt when provided.
-include vendor/samsung/a536b_ds/camera/camera-vendor.mk

PRODUCT_DEVICE := a536b_ds
PRODUCT_NAME := aosp_a536b_ds
PRODUCT_BRAND := samsung
PRODUCT_MODEL := Samsung Galaxy A53 5G (SM-A536B/DS)
PRODUCT_MANUFACTURER := samsung

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/init/init.a536b_ds.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.a536b_ds.rc
