# Security baseline and update policy

This project is security-focused and takes a GrapheneOS-inspired approach to
hardening, but it does **not** claim full GrapheneOS feature parity.

## Important reality check

No Android ROM can be honestly labeled "100% secure". Security is a continuous
process that depends on:

- update cadence
- secure signing and release operations
- hardware and firmware trust boundaries
- ongoing vulnerability response

## Release hardening requirements

1. Build release artifacts with `TARGET_BUILD_VARIANT=user`
2. Keep AVB enabled and verify `vbmeta.img` is generated
3. Use locked bootloader policy for release devices
4. Enforce privileged app permissions (`ro.control_privapp_permissions=enforce`)
5. Keep security patch levels current (system + vendor)
6. Sign OTA and target files with protected offline keys

## CVE/update workflow

1. Sync latest AOSP sources on `android-latest-release`:

   ```bash
   bash scripts/security/sync_latest_security_patches.sh /path/to/aosp/tree
   ```

2. Build release image for dedicated target:

   ```bash
   source build/envsetup.sh
   lunch aosp_xt2601_2_eu-user
   m -j$(nproc)
   ```

3. Verify security posture of build output:

   ```bash
   bash scripts/security/verify_release_security.sh \
     out/target/product/edge70_xt2601_2
   ```

   Optional strictness:

   ```bash
   MAX_PATCH_AGE_DAYS=30 bash scripts/security/verify_release_security.sh \
     out/target/product/edge70_xt2601_2
   ```

## GrapheneOS resemblance goals (baseline)

- Minimal attack surface by default
- Strong permission enforcement
- Fast upstream security update intake
- Release validation gates before distribution

Further hardening beyond this scaffold should include dedicated kernel hardening,
SELinux policy tightening, memory allocator hardening work, and exploit
mitigation backports where applicable.
