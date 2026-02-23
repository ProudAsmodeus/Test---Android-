DEVICE_PATH := device/motorola/edge70

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

$(call inherit-product, vendor/rom/config/common.mk)
$(call inherit-product, vendor/rom/config/version.mk)

PRODUCT_DEVICE := edge70
PRODUCT_NAME := aosp_edge70
PRODUCT_BRAND := motorola
PRODUCT_MODEL := Motorola Edge 70 (12GB/512GB)
PRODUCT_MANUFACTURER := motorola

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/init/init.edge70.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.edge70.rc
