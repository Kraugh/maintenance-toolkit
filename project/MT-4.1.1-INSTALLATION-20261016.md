# MT 4.1.1 final installation pilot — 16 October 2026

User authorized VM installation verification and UAC confirmation. Inputs were downloaded from the actual signed hosting metadata and public GitHub URLs; signatures/catalogs/hashes passed. Plan: isolated previous-stable ZIP 4.0.6 -> exact public 4.1.1, then existing private MSI 4.0.9006 -> exact public MSI 4.1.1, preserving settings/exceptions/opt-in/logs/reports/InventoryShare/tasks. No downgrade, automatic reboot or maintenance-module execution.

## Result: blocked in preflight, no installation attempted

UAC confirmed. The protected Windows PowerShell 5.1 driver passed four checks (elevation, host version, authenticated candidate metadata, known installed pilot version) and stopped in Get-MTInstallKind before ZIP/MSI application, mutable-state changes or test-task creation. Native MSI exit-code list and created/removed task lists are empty. Installed runtime remains 4.0.9006. This is not successful installation evidence and #28 stays open.

The runtime enumerates HKLM uninstall entries and calls IO.Path.GetFullPath on every non-empty InstallLocation. One unrelated application's quoted location triggers an invalid-path exception under .NET Framework/Windows PowerShell 5.1, aborting classification of the valid MT MSI. The entry is not MT. The same diagnostic under PowerShell 7 does not reproduce the invalid-path rejection; Windows PowerShell 5.1 verification is essential. Registry was not changed or normalized to bypass this result.

## Prepared local correction, not a modified 4.1.1 package

Working-tree SelfUpdate.ps1 now ignores malformed locations only for unrelated applications and fails closed for malformed MT registrations. Existing valid-registration identity checks and Program Files no-ZIP fallback remain. Four meaningful regressions added: valid MT MSI plus unrelated quoted location, malformed MT rejection, unregistered Program Files rejection, standalone ZIP classification despite unrelated bad entry. **122 regressions passed** on Windows PowerShell 5.1, Foundation zero errors/warnings, and read-only classification against the actual VM returns MSI after the local fix. No version, manifest or published package changed for this correction.

A new 4.1.2 distribution/installation test is required if authorized; signed/published 4.1.1 payloads cannot silently incorporate this fix. Do not patch the protected signed candidate or its catalog to force the pilot to pass. The next release/test decision was requested from the user.

## Exact retained paths

- Pointer: `launcher/build/current-411-install.json`.
- Input/source: `dist/staging/mt411-install-20261016-075607`, including public inputs, local driver copy, read-only diagnostics and local-fix regression/Foundation logs.
- Protected failed preflight: `C:\ProgramData\MaintenanceToolkit-411-InstallTest-20261016-075607`, including installation-result.json and bootstrap-result.json. Bootstrap Completed means driver execution finished; installation-result Failed is authoritative.
- Generators: `launcher/build/Invoke-411InstallationPilot.ps1`, `launcher/build/Start-411InstallationPilot.ps1`; pinned copy manifest `launcher/build/411-install-copy-manifest.json`. No permanent task/helper installed by the test.
- Private registry diagnostic: source-directory `invalid-uninstall-locations-ps51-private.json`; do not publish application identity/path details. The PowerShell 7 diagnostic is retained separately and does not establish Framework compatibility.

Keep these artifacts as defect evidence. No manual cleanup requested. No external issue closure or successful installation claim is justified by the local repair tests.
