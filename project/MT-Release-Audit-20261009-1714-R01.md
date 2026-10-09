# Maintenance Toolkit 4.0.4 release audit

Windows results provided by the maintainer on 2026-10-09:
- Five regression suites passed after correcting stale foundation-test tokens.
- Launcher compiled, signed and timestamp verified. Signed SHA256: A93C67EC3D093FBF16746C8115AFEAE4D74EF99E64952EEB2CB7FBA611FAB895.
- MSI signed and timestamp verified. SHA256: D38585A4575CBE1B46E0B917AC2F25DC87CBD1C0A8F9106238C2455B8097F80B.
- Portable ZIP SHA256: B92E44CE28AD24EEACD1C93A126F02D4956045234B210DA85BDC92ECC4411EC3.
- Portable elevated SelfTest passed with zero errors/warnings.
- MSI install, installed elevated SelfTest and uninstall passed, exit 0.

## Procedure correction

Unauthorized output-location changes introduced during release preparation are reverted to repository output folders. Public filenames use product/version only. The existing signed binaries are retained; copying them to the documented paths does not require recompilation or resigning. Build scripts and documentation are aligned by this correction. Artifact placement still requires verification on the Windows machine.

## Limits

These checks do not establish universal Dell/NVIDIA compatibility. The new restore-point scenarios use isolated mocks; live restore creation was verified with creation frequency 0. Public metadata and release publication remain pending. No corporate identifiers are included here.
