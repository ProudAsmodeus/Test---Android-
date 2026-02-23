DEVICE_PATH := device/motorola/edge70_xt2601_2

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

$(call inherit-product, vendor/rom/config/common.mk)
$(call inherit-product, vendor/rom/config/version.mk)

# Include stock Motorola camera prebuilt when provided.
-include vendor/motorola/edge70_xt2601_2/camera/camera-vendor.mk

PRODUCT_DEVICE := edge70_xt2601_2
PRODUCT_NAME := aosp_xt2601_2_eu
PRODUCT_BRAND := motorola
PRODUCT_MODEL := Motorola Edge 70 EU (XT2601-2)
PRODUCT_MANUFACTURER := motorola

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/init/init.edge70_xt2601_2.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.edge70_xt2601_2.rc
