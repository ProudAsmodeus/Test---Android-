#
# Shared ROM settings. Extend this list as your ROM grows.
#

PRODUCT_BRAND := Android
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.rom.base=true

$(call inherit-product, vendor/rom/config/security_hardening.mk)
$(call inherit-product, vendor/rom/config/optimization.mk)

PRODUCT_PACKAGES += \
    SecureConnectionGuard \
    AdGuardControl

# Example package hook:
# PRODUCT_PACKAGES += \
#     SomeExtraPackage
