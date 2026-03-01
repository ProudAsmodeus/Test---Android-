#include <android-base/logging.h>

extern "C" void vendor_load_properties() {
    LOG(INFO) << "libinit_g930f: using static SM-G930F property baseline";
}
