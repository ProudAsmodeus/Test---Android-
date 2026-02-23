$(call inherit-product, device/motorola/edge70/device.mk)

PRODUCT_NAME := aosp_edge70_eu
PRODUCT_DEVICE := edge70
PRODUCT_BRAND := motorola
PRODUCT_MODEL := Motorola Edge 70 EU (12GB/512GB)
PRODUCT_MANUFACTURER := motorola

# Regional marker for EU build flavor.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.vendor.rom.region=EU \
    ro.product.locale=en-GB
