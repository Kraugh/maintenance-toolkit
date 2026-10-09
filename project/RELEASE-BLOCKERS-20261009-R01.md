# 4.0.4-dev.9: release blocker validation

Base: 002583a833d2b517effbcee1b73ab37c534355ad. Source-only package; no built/signed EXE or MSI.

## Changes

- Revalidate restore-point session markers against actual completed points, accepting a verified point no older than 24 hours from Windows, MT or another vendor. Reject future, incomplete, missing and stale points. Fail closed when restore points cannot be read or creation cannot be verified. No registry writes.
- Log DCU process termination as INFO pending operation verification; preserve and report native exit evidence separately. Do not mask process failure/timeout with a native success.
- Keep BIOS and NVIDIA policies unchanged. Public manifest remains byte-identical at 4.0.3.
- Use unique external ZIP/checksum/MSI names. MSI build outputs use a fresh C:\temp directory.

## Validation

Static checks: JSON parsed, EN/IT/SV key sets equal, stable manifest unchanged, source diff whitespace check clean. Tests have NOT been executed in the preparation environment: it has no PowerShell runtime; downloading one was blocked by automatic approval review as an unauthorized dependency. Execute on existing Windows PowerShell 5.1 before compilation/signing.

Run the new Test-MTReleaseBlockers-20261009-1620-R01.ps1 and the four existing regression suites. New tests mock restore queries/creation and processes, without changing Windows protection, registry, drivers or installing software.

After isolated tests pass, validate real recent-point reuse with default restore frequency on an available test Windows client, then complete stable-version preparation, build, signing, installation/uninstallation checks and public release. Creation and verification were observed separately with frequency 0; default-frequency live testing is still pending.
