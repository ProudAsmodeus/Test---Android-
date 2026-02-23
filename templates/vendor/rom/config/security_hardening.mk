#
# GrapheneOS-inspired baseline hardening for this ROM template.
# This is a strong baseline, not an equivalence claim with GrapheneOS.
#

# Enforce strict handling of privileged app permissions.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.control_privapp_permissions=enforce

# Enable additional userspace hardening where supported by platform components.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    security.perf_harden=1

# Reduce network attack surface defaults.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.com.android.dataroaming=false

# Default USB function to locked-down mode.
# Users can still change USB mode in Settings after unlock.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    persist.sys.usb.config=none

# Release security policy reminder.
ifneq ($(TARGET_BUILD_VARIANT),user)
$(warning [rom-security] Release artifacts should use TARGET_BUILD_VARIANT=user)
endif
