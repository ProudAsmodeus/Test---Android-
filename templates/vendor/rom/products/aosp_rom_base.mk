$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base.mk)

$(call inherit-product, vendor/rom/config/common.mk)
$(call inherit-product, vendor/rom/config/version.mk)

PRODUCT_NAME := aosp_rom_base
PRODUCT_DEVICE := generic_arm64
PRODUCT_MANUFACTURER := AOSP
PRODUCT_MODEL := ROM Base Device
