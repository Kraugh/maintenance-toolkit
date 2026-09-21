# Enterprise deployment — MSI and Group Policy

This guide describes the supported installation path for Maintenance Toolkit 4.0.2. It covers standalone MSI installation and centrally managed Active Directory deployment without attempting to catalogue environment-specific troubleshooting cases.

## 1. Deployment model

Maintenance Toolkit uses the same runtime in both distribution channels:

- portable ZIP for manual and field use;
- per-machine x64 MSI for local installation and managed deployment.

The MSI installs MT under:

```text
C:\Program Files\Kraugh\Maintenance Toolkit
```

Scheduling has one owner:

- standalone MSI: the MSI may create `\Kraugh\Maintenance Toolkit - MSI Managed`;
- Active Directory: install with `CREATE_TASK=0` and let Group Policy Preferences own a separately named task.

Maintenance Toolkit must not run as a Domain Administrator and never reboots the computer automatically.

## 2. Prerequisites

- Windows x64 supported by the organisation;
- local administrative rights or a computer-assigned software deployment policy;
- the signed `MaintenanceToolkit-4.0.2-x64.msi` from the official release;
- network access required by the enabled MT modules;
- for inventory publication, a dedicated SMB destination writable by computer accounts.

Before production deployment, validate the exact MSI, policy, execution account and share permissions on a test computer or pilot OU.

### OEM updates and System Restore policy (4.0.3+)

The OEM module requires a restore point that MT can create and verify before it applies non-BIOS updates. In the same computer GPO used to manage MT, configure:

**Computer Configuration → Policies → Administrative Templates → System → System Restore → Turn off System Restore = Disabled**

Make sure this setting wins over any inherited GPO that enables **Turn off System Restore**. Use the target child OU or the winning link order, then validate the resultant set of policy on a pilot computer. MT stops the OEM update operation if the restore point cannot be verified; it does not bypass a domain prohibition. See [OEM updates](../eng/OEM-UPDATES.md).

## 3. Verify the installer

In File Explorer, open **Properties → Digital Signatures** and verify that the signature is valid and belongs to the expected Maintenance Toolkit publisher.

PowerShell verification:

```powershell
$r = Get-AuthenticodeSignature '.\MaintenanceToolkit-4.0.2-x64.msi' | Select-Object Status,StatusMessage,@{N='Signer';E={$_.SignerCertificate.Subject}},@{N='Timestamp';E={$_.TimeStamperCertificate.Subject}} | Format-List | Out-String -Width 500; $r | Set-Clipboard; $r
```

SHA-256 verification:

```powershell
$r = Get-FileHash '.\MaintenanceToolkit-4.0.2-x64.msi' -Algorithm SHA256 | Format-List | Out-String -Width 500; $r | Set-Clipboard; $r
```

Compare the resulting hash with the checksum published alongside the release asset.

## 4. Manual and silent installation

For an interactive installation, start the MSI with administrative privileges.

Default silent per-machine installation, without an MSI-managed task:

```powershell
msiexec.exe /i ".\MaintenanceToolkit-4.0.2-x64.msi" /qn /norestart CREATE_TASK=0 /L*v "$env:TEMP\MaintenanceToolkit-4.0.2-install.log"
```

Standalone silent installation with the optional daily MSI-managed task:

```powershell
msiexec.exe /i ".\MaintenanceToolkit-4.0.2-x64.msi" /qn /norestart CREATE_TASK=1 TASK_TIME=03:00 INVENTORY_SHARE="\\SERVER\MT" /L*v "$env:TEMP\MaintenanceToolkit-4.0.2-install.log"
```

Public MSI properties:

| Property | Default | Purpose |
|---|---:|---|
| `CREATE_TASK` | `0` | Set to `1` only for the MSI-managed standalone task. |
| `TASK_TIME` | `03:00` | Daily start time for the MSI-managed task. |
| `INVENTORY_SHARE` | empty | Optional UNC destination for inventory snapshots. |

## 5. Verify a local installation

The canonical installed version comes from `config\version.json`, not from a launcher `-Version` argument or its file metadata:

```powershell
$r = "MT " + (Get-Content 'C:\Program Files\Kraugh\Maintenance Toolkit\config\version.json' -Raw | ConvertFrom-Json).Version; $r | Set-Clipboard; $r
```

Confirm that `MaintenanceToolkit.exe` exists in the installation directory. If `CREATE_TASK=1` was used, also confirm the task `\Kraugh\Maintenance Toolkit - MSI Managed` and its next run time.

## 6. Upgrade

Maintenance Toolkit keeps a stable MSI `UpgradeCode`. Deploy the administrator-approved newer MSI as a normal major upgrade:

```powershell
msiexec.exe /i ".\MaintenanceToolkit-NEWVERSION-x64.msi" /qn /norestart CREATE_TASK=0 /L*v "$env:TEMP\MaintenanceToolkit-upgrade.log"
```

For GPO deployments, keep versioned source folders and assign only the approved MSI:

```text
\\SERVER\Software\MaintenanceToolkit\
    4.0.2\MaintenanceToolkit-4.0.2-x64.msi
    NEWVERSION\MaintenanceToolkit-NEWVERSION-x64.msi
```

Pilot the upgrade before changing the production assignment. Do not silently replace an MSI file already assigned by Group Policy.

## 7. Uninstall

Use **Installed apps**, the organisation's software-management platform, or the original MSI:

```powershell
msiexec.exe /x ".\MaintenanceToolkit-4.0.2-x64.msi" /qn /norestart /L*v "$env:TEMP\MaintenanceToolkit-4.0.2-uninstall.log"
```

Uninstall removes only the uniquely named MSI-managed task. A GPO-managed task remains owned by Group Policy and must be removed or disabled in that policy.

## 8. Active Directory MSI deployment

1. Store the approved MSI in a versioned UNC folder readable by target computer accounts.
2. Open Group Policy Management and create or edit the computer policy used for the pilot OU.
3. Go to **Computer Configuration → Policies → Software Settings → Software installation**.
4. Select **New → Package**, enter the MSI by UNC path and choose **Assigned**.
5. Link the GPO only to the intended test OU or filtered computer group.
6. Ensure the enterprise deployment uses the MSI default `CREATE_TASK=0`. The GPO owns scheduling separately.
7. Apply policy and restart a pilot computer when required by the organisation's software-installation workflow.

Do not select the MSI through a local drive path. Every client must resolve the same UNC source.

## 9. Group Policy Preferences Scheduled Task

Create a computer-side task under:

**Computer Configuration → Preferences → Control Panel Settings → Scheduled Tasks**.

Recommended settings:

| Setting | Value |
|---|---|
| Action | Update |
| Task name | `Maintenance Toolkit - GPO Managed` |
| Account | `NT AUTHORITY\SYSTEM` |
| Security option | Run whether a user is logged on or not |
| Privileges | Run with highest privileges |
| Program | `C:\Program Files\Kraugh\Maintenance Toolkit\MaintenanceToolkit.exe` |
| Arguments | `-RunAll -InventoryShare "\\SERVER\MT"` |
| Start in | `C:\Program Files\Kraugh\Maintenance Toolkit` |
| Trigger | Daily at the organisation-approved time |

Use the normal `SYSTEM` identity supported by Group Policy Preferences. Do not run MT as a Domain Administrator. Changing schedule or runtime arguments in the GPO does not require reinstalling the MSI.

## 10. SMB inventory destination

The generic architecture is:

```text
MT clients -> \\DMT-SERVER\MT -> DMT
```

When MT runs as `SYSTEM`, remote SMB access uses the domain computer identity, for example `CONTOSO\CLIENT01$`.

Configure both share and filesystem permissions so the selected computer accounts, or a controlled group such as `Domain Computers`, can create and update inventory files. Grant only the rights required by the organisation. Do not use a personal administrator account as the scheduled-task identity.

Test the share while executing under the same account and policy context that production will use.

## 11. Client verification

After policy application and any required restart, verify on a pilot client:

- Maintenance Toolkit is installed in Program Files;
- `config\version.json` reports the approved version;
- `Maintenance Toolkit - GPO Managed` exists with `SYSTEM` and highest privileges;
- the executable path and arguments are exact;
- the task completes with the expected result;
- a new local session log is created;
- when configured, a new inventory JSON reaches `\\SERVER\MT`;
- no MSI-managed task exists when deployment used `CREATE_TASK=0`.

Task Scheduler result `0` means success. MT exit code `20` means the run completed with warnings and must not be interpreted as an installation failure. MT never performs an automatic reboot.

For focused operational checks, see [Diagnostic commands](DIAGNOSTIC-COMMANDS.md).
