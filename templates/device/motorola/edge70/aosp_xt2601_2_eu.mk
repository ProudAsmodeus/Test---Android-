$(call inherit-product, device/motorola/edge70/device.mk)

PRODUCT_NAME := aosp_xt2601_2_eu
PRODUCT_DEVICE := edge70
PRODUCT_BRAND := motorola
PRODUCT_MODEL := Motorola Edge 70 EU (XT2601-2)
PRODUCT_MANUFACTURER := motorola

# SKU/region marker for XT2601-2 EU builds.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.vendor.rom.region=EU \
    ro.vendor.device.xt_code=XT2601-2 \
    ro.product.locale=en-GB
