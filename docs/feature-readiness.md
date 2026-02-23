# Feature readiness and smoothness sign-off

This checklist is for "daily-driver complete" quality expectations:

- smooth and responsive UI
- stable calls and SMS
- mobile data with 5G coverage support
- eSIM provisioning and usage
- all physical cameras and video paths
- core system services expected in a modern Android ROM

## 1) Source-tree readiness gate

Run:

```bash
bash scripts/qa/validate_feature_readiness.sh /path/to/aosp/tree
```

This gate verifies:

- no placeholder/TODO values in key device config files
- telephony base inheritance in device product config
- meaningful proprietary blob population
- blob category coverage for:
  - telephony/radio/IMS
  - 5G/modem
  - eSIM/eUICC
  - camera
  - audio/voice
  - Wi-Fi/Bluetooth

## 2) Device acceptance suite (post-flash)

Run:

```bash
bash scripts/qa/run_device_acceptance_suite.sh
```

Automated checks include:

- telephony-related Binder services
- eSIM service visibility
- camera service visibility
- 5G indicators in telephony dumps
- IMS/RCS service visibility
- subscription info visibility

The script also prints a required manual checklist:

- outgoing and incoming calls
- SMS send/receive
- mobile data
- 5G registration in target area
- eSIM profile download/enable
- front/rear cameras and video recording

## 3) Smooth/optimized/clean defaults

`vendor/rom/config/optimization.mk` provides baseline performance defaults and
clean release-oriented properties. Tune only with measured profiling data.

## 4) Release policy

Do not treat the ROM as production-ready until:

1. Security gates pass (`scripts/security/*`)
2. Source-tree feature gate passes (`scripts/qa/validate_feature_readiness.sh`)
3. Device acceptance checks pass on real hardware
4. Camera parity workflow is completed (`docs/camera-stock-parity.md`)
