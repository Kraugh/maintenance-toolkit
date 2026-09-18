# Enterprise diagnostic commands

This reference complements the linear MSI/GPO deployment guide. It contains focused checks for an already deployed Maintenance Toolkit installation.

All commands display their result and copy it to the clipboard. Run them in Windows PowerShell on the client being inspected.

## Installed MT version

The canonical version is stored in `config\version.json`:

```powershell
$r = if (Test-Path 'C:\Program Files\Kraugh\Maintenance Toolkit\config\version.json') { "MT " + (Get-Content 'C:\Program Files\Kraugh\Maintenance Toolkit\config\version.json' -Raw | ConvertFrom-Json).Version } else { 'Maintenance Toolkit is not installed in the expected path.' }; $r | Set-Clipboard; $r
```

`MaintenanceToolkit.exe -Version` is not supported and launcher file metadata is not the canonical runtime version.

## GPO-managed task state

```powershell
$r = Get-ScheduledTask -TaskName 'Maintenance Toolkit - GPO Managed' -ErrorAction SilentlyContinue | ForEach-Object { $i = Get-ScheduledTaskInfo -InputObject $_; [pscustomobject]@{ComputerName=$env:COMPUTERNAME;TaskPath=$_.TaskPath;TaskName=$_.TaskName;State=$_.State;UserId=$_.Principal.UserId;RunLevel=$_.Principal.RunLevel;LastRunTime=$i.LastRunTime;LastTaskResult=$i.LastTaskResult;NextRunTime=$i.NextRunTime} } | Format-List | Out-String -Width 500; if ([string]::IsNullOrWhiteSpace($r)) { $r = 'Maintenance Toolkit - GPO Managed was not found.' }; $r | Set-Clipboard; $r
```

Common Task Scheduler results:

| Decimal | Hex | Meaning |
|---:|---:|---|
| `0` | `0x0` | Completed successfully. |
| `267009` | `0x41301` | Task is currently running. |
| `267014` | `0x41306` | Task was terminated. |

An MT process exit code of `20` means completed with warnings. It is not equivalent to an MT error.

## MSI-managed task state

```powershell
$r = Get-ScheduledTask -TaskName 'Maintenance Toolkit - MSI Managed' -ErrorAction SilentlyContinue | ForEach-Object { $i = Get-ScheduledTaskInfo -InputObject $_; [pscustomobject]@{ComputerName=$env:COMPUTERNAME;TaskPath=$_.TaskPath;TaskName=$_.TaskName;State=$_.State;UserId=$_.Principal.UserId;RunLevel=$_.Principal.RunLevel;LastRunTime=$i.LastRunTime;LastTaskResult=$i.LastTaskResult;NextRunTime=$i.NextRunTime} } | Format-List | Out-String -Width 500; if ([string]::IsNullOrWhiteSpace($r)) { $r = 'Maintenance Toolkit - MSI Managed was not found.' }; $r | Set-Clipboard; $r
```

In a GPO-managed deployment installed with `CREATE_TASK=0`, the MSI-managed task should not exist.

## Apply computer policy

```powershell
$r = gpupdate.exe /force 2>&1 | Out-String -Width 500; $r | Set-Clipboard; $r
```

If computer-assigned software requires a restart, follow the organisation's normal change procedure. Maintenance Toolkit itself never requests an automatic reboot.

## Locate the latest local session

```powershell
$root = 'C:\Program Files\Kraugh\Maintenance Toolkit\logs'; $r = if (Test-Path $root) { Get-ChildItem $root -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{8}-\d{6}_' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1 FullName,LastWriteTime | Format-List | Out-String -Width 500 } else { 'MT log root was not found.' }; if ([string]::IsNullOrWhiteSpace($r)) { $r = 'No MT session directory was found.' }; $r | Set-Clipboard; $r
```

The final summary in a session directory is normally `riepilogo.txt`. Detailed logs and inventory output remain in the same session tree; Network Diagnostics reports use the runtime `reports` area.

## Inspect the latest session summary

```powershell
$root = 'C:\Program Files\Kraugh\Maintenance Toolkit\logs'; $session = Get-ChildItem $root -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{8}-\d{6}_' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1; $r = if ($session -and (Test-Path (Join-Path $session.FullName 'riepilogo.txt'))) { Get-Content (Join-Path $session.FullName 'riepilogo.txt') -Raw | Out-String -Width 500 } else { 'No latest riepilogo.txt was found.' }; $r | Set-Clipboard; $r
```

## Winget timeout evidence

Use this check only when the summary reports a Winget warning or timeout:

```powershell
$root = 'C:\Program Files\Kraugh\Maintenance Toolkit\logs'; $session = Get-ChildItem $root -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{8}-\d{6}_' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1; $r = if ($session) { Get-ChildItem $session.FullName -File -Recurse -ErrorAction SilentlyContinue | Select-String -Pattern 'timeout|timed out|Winget' -ErrorAction SilentlyContinue | Select-Object Path,LineNumber,Line | Format-Table -Wrap | Out-String -Width 500 } else { 'No MT session directory was found.' }; if ([string]::IsNullOrWhiteSpace($r)) { $r = 'No Winget timeout evidence was found in the latest session.' }; $r | Set-Clipboard; $r
```

A Winget timeout is reported as `WARN`; MT terminates the timed-out process tree and continues with the remaining maintenance modules.
