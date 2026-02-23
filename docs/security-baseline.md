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
7. Block OTA packaging if release gate checks fail

## CVE/update workflow

After running `bootstrap_rom_base.sh`, these scripts are available directly
inside your AOSP tree under `scripts/security/`.

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

4. Run release gate before any OTA packaging:

   ```bash
   RELEASE_GATE_MODE=presign bash scripts/security/release_gate.sh \
     out/target/product/edge70_xt2601_2 \
     out/dist/aosp_xt2601_2_eu-target_files-unsigned.zip \
     /path/to/release-keys
   ```

   Optional: customize required key set for your branch:

   ```bash
   REQUIRED_KEYS="releasekey,platform,shared,media" \
   bash scripts/security/release_gate.sh \
     out/target/product/edge70_xt2601_2 \
     out/dist/aosp_xt2601_2_eu-target_files-unsigned.zip \
     /path/to/release-keys
   ```

   For signed target files (strict release check):

   ```bash
   bash scripts/security/release_gate.sh \
     out/target/product/edge70_xt2601_2 \
     out/dist/aosp_xt2601_2_eu-target_files-signed.zip \
     /path/to/release-keys
   ```

5. Generate signed OTA via secure wrapper:

   ```bash
   bash scripts/security/package_secure_ota.sh \
     /path/to/aosp/tree \
     out/target/product/edge70_xt2601_2 \
     out/dist/aosp_xt2601_2_eu-target_files-unsigned.zip \
     /path/to/release-keys \
     out/dist/aosp_xt2601_2_eu-ota-signed.zip
   ```

6. Audit kernel config hardening baseline:

   ```bash
   bash scripts/security/check_kernel_hardening_config.sh \
     /path/to/kernel/.config
   ```

## GrapheneOS resemblance goals (baseline)

- Minimal attack surface by default
- Strong permission enforcement
- Fast upstream security update intake
- Release validation gates before distribution

Further hardening beyond this scaffold should include dedicated kernel hardening,
SELinux policy tightening, memory allocator hardening work, and exploit
mitigation backports where applicable.

For core telephony/camera/eSIM/5G production readiness alongside security,
follow `docs/feature-readiness.md` and the `scripts/qa/*` gates.

## On-device firewall controls

This template also includes a built-in app:

- `SecureConnectionGuard` (`packages/apps/SecureConnectionGuard`)
- `AdGuardControl` (`packages/apps/AdGuardControl`)

It provides persistent destination rules and on-device enforcement through a
system backend (iptables) when available, with fallback to a local VPN service,
plus connection visibility via kernel socket table snapshots where available.
This is intended as a practical user-facing control layer on top of the release
pipeline hardening checks above.

Additional app-side protections include:

- Severity coloring (green/orange/red) for observed connections
- Risk heuristics based on source app naming and destination-country watchlist
- A dedicated security news feed section with hourly automatic updates
- Quick Settings DNS toggles for AdGuard free and paid/personal DNS endpoints
