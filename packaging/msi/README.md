# Maintenance Toolkit — MSI packaging

This directory contains the enterprise MSI packaging source.

It does **not** change the portable repository layout. The normal GitHub ZIP remains usable exactly as before.

## Build tool

The build script pins:

- WiX Toolset 5.0.2
- WixToolset.Util.wixext 5.0.2

WiX 5 is intentionally pinned for reproducibility and to avoid introducing the WiX v6/v7 Open Source Maintenance Fee into MT packaging.

## Build

From the repository root, the recommended build reads the canonical runtime
version from `config/version.json`:

```powershell
.\packaging\msi\Build-MSI.ps1
```

An explicit `-Version` is accepted only when it matches `config/version.json`.
The build also verifies the version declared by `app/MaintenanceToolkit.ps1`.
The current native launcher does not expose reliable embedded version metadata,
so the build reports the exact launcher path and SHA-256 instead of claiming an
unreliable EXE version check.

Output:

```text
packaging\msi\out\MaintenanceToolkit-<canonical-version>-x64.msi
```

## MSI properties

| Property | Default | Meaning |
|---|---:|---|
| `CREATE_TASK` | `0` | Create/update the MSI-managed Scheduled Task |
| `TASK_TIME` | `03:00` | Daily execution time in 24-hour `HH:mm` format |
| `INVENTORY_SHARE` | empty | Optional DMT inventory destination |

Standalone MSI example with MSI-owned scheduling:

```powershell
msiexec /i MaintenanceToolkit-4.0.0-x64.msi CREATE_TASK=1 TASK_TIME=03:00 INVENTORY_SHARE="\\SERVER\DMT\incoming"
```

Silent standalone example:

```powershell
msiexec /i MaintenanceToolkit-4.0.0-x64.msi /qn CREATE_TASK=1 TASK_TIME=03:00 INVENTORY_SHARE="\\SERVER\DMT\incoming"
```

Enterprise/GPO deployment must use `CREATE_TASK=0` (the default). Group Policy
owns and configures its separately named Scheduled Task:

```powershell
msiexec /i MaintenanceToolkit-4.0.0-x64.msi /qn CREATE_TASK=0
```

## Scheduled Task ownership

The MSI owns only:

```text
\Kraugh\Maintenance Toolkit - MSI Managed
```

A future GPO-managed task should use a different task name and `CREATE_TASK=0`, so MSI and Group Policy never compete for the same Scheduled Task.

The MSI-managed task runs:

```text
MaintenanceToolkit.exe -RunAll
```

or, when configured:

```text
MaintenanceToolkit.exe -RunAll -InventoryShare "\\SERVER\DMT\incoming"
```

under `SYSTEM`, with highest privileges, whether or not a user is logged on.

## Runtime and state boundary

The MSI installs the same MT runtime used by the portable distribution under Program Files, using its existing relative `config`, `logs`, and `reports` model. The runtime change that treats an unavailable Winget dependency as `SKIP` is a general runtime bugfix discovered during SYSTEM/MSI validation; it also applies to portable execution and is not MSI-only behaviour.

Separating immutable application files in Program Files from mutable state in ProgramData remains a follow-up architectural improvement and should be implemented only together with the corresponding runtime path abstraction and regression tests.
