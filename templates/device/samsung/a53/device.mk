DEVICE_PATH := device/samsung/a53

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

$(call inherit-product, vendor/rom/config/common.mk)
$(call inherit-product, vendor/rom/config/version.mk)

PRODUCT_DEVICE := a53
PRODUCT_NAME := aosp_a53
PRODUCT_BRAND := samsung
PRODUCT_MODEL := Samsung Galaxy A53 5G (SM-A536B/DS)
PRODUCT_MANUFACTURER := samsung

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/init/init.a53.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.a53.rc
