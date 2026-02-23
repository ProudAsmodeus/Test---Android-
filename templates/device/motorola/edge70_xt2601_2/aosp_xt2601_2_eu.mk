$(call inherit-product, device/motorola/edge70_xt2601_2/device.mk)

PRODUCT_NAME := aosp_xt2601_2_eu
PRODUCT_DEVICE := edge70_xt2601_2
PRODUCT_BRAND := motorola
PRODUCT_MODEL := Motorola Edge 70 EU (XT2601-2)
PRODUCT_MANUFACTURER := motorola

PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.vendor.rom.region=EU \
    ro.vendor.device.xt_code=XT2601-2 \
    ro.product.locale=en-GB
