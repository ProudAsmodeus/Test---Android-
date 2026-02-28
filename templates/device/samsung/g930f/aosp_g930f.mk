$(call inherit-product, device/samsung/g930f/device.mk)

PRODUCT_NAME := aosp_g930f
PRODUCT_DEVICE := g930f
PRODUCT_BRAND := samsung
PRODUCT_MODEL := Samsung Galaxy S7 (SM-G930F)
PRODUCT_MANUFACTURER := samsung

PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.vendor.rom.region=GLOBAL \
    ro.vendor.device.sku=SM-G930F \
    ro.product.locale=en-US
