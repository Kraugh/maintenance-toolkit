# OEM updates

**Compatible with:** Maintenance Toolkit `4.0.3-rc.3` and later

The OEM module installs eligible vendor updates while preserving three safety boundaries: BIOS updates are never installed unattended, Windows is never restarted automatically, and non-BIOS installation cannot begin without a verified restore point.

## Supported vendors

| Vendor | Integration | Behaviour |
|---|---|---|
| Dell | Locally installed, Authenticode-valid Dell Command Update CLI | Scans BIOS separately; installs only non-BIOS categories. |
| HP | Signed HP Image Assistant package acquired from HP | Analyses recommendations; installs eligible non-BIOS updates. BIOS requires an interactive, explicit confirmation. |

Unsupported manufacturers are reported as `SKIP`, not as an error.

## System Restore prerequisite

Before any driver, firmware, application or utility update is applied, MT creates or reuses a restore point from the current session and verifies that it has actually been recorded. If Windows System Restore is disabled or the point cannot be verified, the OEM module stops without applying updates.

For domain-managed computers, configure the same computer GPO used for Maintenance Toolkit:

**Computer Configuration → Policies → Administrative Templates → System → System Restore → Turn off System Restore = Disabled**

`Disabled` means that the policy which turns System Restore off is itself disabled. Ensure this GPO has precedence over any inherited policy that enables **Turn off System Restore**; link it to the target child OU or give it the winning link order. After policy refresh, verify the resulting policy on a pilot computer before enabling OEM updates in production.

MT enables protection for the system drive when possible, but it does not bypass a domain policy that prohibits System Restore.

## Dell workflow

1. Detect Dell hardware independently of Dell Command Update availability.
2. If DCU is absent, create and verify the restore point, install the exact `Dell.CommandUpdate` package silently from the Winget source, then locate the CLI and validate its Dell Authenticode signature. If Winget is unavailable or validation fails, stop without scanning or applying updates.
3. Run a BIOS-only scan and report an available BIOS as an urgent action without installing it.
4. Run a separate non-BIOS scan for drivers, firmware, applications, utilities and other supported categories.
5. If eligible updates exist and no session restore point exists yet, create and verify it.
6. Apply the exact non-BIOS selection with automatic reboot disabled.
7. If Dell Command Update updates itself through its separate installer, wait up to 15 minutes and validate the resulting signed executable and version.
8. Run a fresh verification scan; if DCU is still finalizing its self-update and produces no XML report, retry for up to 15 minutes.
9. Classify each attempted update as installed, still applicable or verification failed, and record any required restart separately.

DCU exit codes `0`, `1` and `500` are interpreted according to the operation. Code `500` during a scan means that no applicable update was found. Other codes and malformed or missing XML reports are not treated as success.

## HP workflow

HP Image Assistant is downloaded only from the configured trusted HP source and its signature is validated. Eligible non-BIOS recommendations may be installed after the restore-point gate. BIOS installation is blocked in scheduled, GPO, `SYSTEM` and other unattended sessions. In an interactive console, a critical HP BIOS recommendation uses a separate guided confirmation and checks pending reboot and BitLocker recovery readiness.

## Running and reviewing a pilot

Run only the OEM module from an elevated console:

```powershell
.\MaintenanceToolkit.exe -Only OEM
```

Start with a test computer or pilot OU. Keep AC power connected, close business applications and allow vendor installers to finish. Do not interrupt the process merely because it is quiet for several minutes.

Review the final session summary, the detailed session log and `oem-status.json`. A successful process exit does not replace the post-install verification result. A requested reboot is recorded but never performed automatically.

For a production pilot, confirm beforehand that the device is backed up, BitLocker recovery information is escrowed, there is no pending reboot, and a maintenance window is active.

## Release channels

`4.0.3-rc.3` is an opt-in portable release candidate intended for the final production pilot. It does not replace the stable `4.0.2` update manifest. The signed MSI is produced when the tested candidate is promoted to final `4.0.3`.
