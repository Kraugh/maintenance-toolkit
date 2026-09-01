# Enterprise deployment — MSI and Group Policy

## Architecture

Maintenance Toolkit remains available as a portable application.

The MSI adds a managed enterprise deployment channel without changing the layout used by the GitHub ZIP.

```text
Portable
    ZIP -> technician/manual use

Enterprise
    MSI -> local installation
     |
     +-> optional MSI-managed Scheduled Task
     |
     +-> or GPO-managed Scheduled Task
```

## MSI deployment

The MSI is per-machine and is intended for unattended deployment.

Example:

```powershell
msiexec /i MaintenanceToolkit-4.0.0-x64.msi /qn
```

Optional automatic daily maintenance:

```powershell
msiexec /i MaintenanceToolkit-4.0.0-x64.msi /qn CREATE_TASK=1 TASK_TIME=03:00
```

Optional DMT publication:

```powershell
msiexec /i MaintenanceToolkit-4.0.0-x64.msi /qn CREATE_TASK=1 TASK_TIME=03:00 INVENTORY_SHARE="\\SERVER\DMT\incoming"
```

## Task ownership

Only one authority should manage a Scheduled Task.

### Standalone MSI

Use:

```text
CREATE_TASK=1
```

The MSI creates:

```text
\Kraugh\Maintenance Toolkit - MSI Managed
```

### Active Directory / GPO

Use:

```text
CREATE_TASK=0
```

and create the enterprise task with Group Policy Preferences.

GPO can then centrally change:

- execution time;
- recurrence;
- enabled state;
- MT arguments;
- `-InventoryShare` destination.

Changing the GPO does not require reinstalling MT.

## Execution account

For centralized maintenance the task should normally run as:

```text
NT AUTHORITY\SYSTEM
```

with highest privileges and without requiring an interactive user session.

When `-InventoryShare` points to a UNC path, the destination ACL must grant the computer account (or an appropriate domain group containing computer accounts) the required write permissions.

## DMT relationship

DMT consumes Inventory Schema snapshots.

Normal daily execution remains controlled by MSI/GPO scheduling. A future DMT on-demand execution mechanism is intentionally outside this MSI feature.
