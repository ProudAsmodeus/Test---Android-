#
# Smooth, optimized, clean baseline for release builds.
# Keep settings conservative and broadly compatible across modern Android.
#

# Runtime smoothness and responsiveness defaults.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.lmk.use_psi=true \
    ro.lmk.kill_heaviest_task=true \
    persist.device_config.runtime_native.usap_pool_enabled=true \
    dalvik.vm.dex2oat-filter=speed-profile \
    dalvik.vm.image-dex2oat-filter=speed-profile

# Keep network debugging surface minimal on user devices.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    persist.adb.tcp.port=-1
