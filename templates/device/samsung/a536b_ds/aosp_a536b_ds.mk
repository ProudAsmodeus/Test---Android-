$(call inherit-product, device/samsung/a536b_ds/device.mk)

PRODUCT_NAME := aosp_a536b_ds
PRODUCT_DEVICE := a536b_ds
PRODUCT_BRAND := samsung
PRODUCT_MODEL := Samsung Galaxy A53 5G (SM-A536B/DS)
PRODUCT_MANUFACTURER := samsung

PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.vendor.rom.region=GLOBAL \
    ro.vendor.device.sku=SM-A536B/DS \
    ro.product.locale=en-US
