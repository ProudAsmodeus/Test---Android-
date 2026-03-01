$(call inherit-product, device/samsung/a53/device.mk)

PRODUCT_NAME := aosp_a53_ds
PRODUCT_DEVICE := a53
PRODUCT_BRAND := samsung
PRODUCT_MODEL := Samsung Galaxy A53 5G (SM-A536B/DS)
PRODUCT_MANUFACTURER := samsung

# Regional marker for dual-SIM build flavor.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.vendor.rom.region=GLOBAL \
    ro.vendor.device.sku=SM-A536B/DS \
    ro.product.locale=en-US
