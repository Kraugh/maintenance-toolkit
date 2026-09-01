[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("Install", "Uninstall")]
    [string]$Action,

    [Parameter(Mandatory)]
    [string]$InstallDir,

    [string]$TaskTime = "03:00",

    [string]$InventoryShare = "",

    [switch]$ReadInventoryShareFromRegistry
)

$ErrorActionPreference = "Stop"

$TaskPath = "\Kraugh\"
$TaskName = "Maintenance Toolkit - MSI Managed"

if ($Action -eq "Uninstall") {
    try {
        $ExistingTask = Get-ScheduledTask `
            -TaskPath $TaskPath `
            -TaskName $TaskName `
            -ErrorAction SilentlyContinue

        if ($ExistingTask) {
            Unregister-ScheduledTask `
                -TaskPath $TaskPath `
                -TaskName $TaskName `
                -Confirm:$false `
                -ErrorAction Stop
        }
    }
    catch {
        # Uninstall remains best-effort, but WixQuietExec records this warning
        # in the verbose MSI log instead of hiding the failed cleanup.
        Write-Warning (
            "Unable to remove MSI-owned Scheduled Task {0}{1}: {2}" -f
            $TaskPath,
            $TaskName,
            $_.Exception.Message
        )
    }

    exit 0
}

if ($TaskTime -notmatch '^(?:[01]\d|2[0-3]):[0-5]\d$') {
    throw "TASK_TIME must use HH:mm 24-hour format."
}

if ($ReadInventoryShareFromRegistry) {
    $RegistryKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
        "Software\Kraugh\Maintenance Toolkit"
    )

    try {
        $InventoryShare = if ($RegistryKey) {
            [string]$RegistryKey.GetValue("InventoryShare", "")
        }
        else {
            ""
        }
    }
    finally {
        if ($RegistryKey) {
            $RegistryKey.Dispose()
        }
    }
}

$NormalizedInstallDir = [System.IO.Path]::GetFullPath($InstallDir)
$Executable = Join-Path $NormalizedInstallDir "MaintenanceToolkit.exe"
if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
    throw "MaintenanceToolkit.exe was not found in the MSI installation directory."
}

$Arguments = "-RunAll"

if (-not [string]::IsNullOrWhiteSpace($InventoryShare)) {
    if ($InventoryShare.IndexOf('"') -ge 0) {
        throw "INVENTORY_SHARE must not contain double quotes."
    }

    if ($InventoryShare -match '[\x00-\x1F]') {
        throw "INVENTORY_SHARE must not contain control characters."
    }

    if (-not [System.IO.Path]::IsPathRooted($InventoryShare)) {
        throw "INVENTORY_SHARE must be an absolute local or UNC path."
    }

    # Windows command-line parsing requires every trailing backslash inside a
    # quoted argument to be doubled so that the closing quote remains a quote.
    $TrailingBackslashCount = 0
    for ($Index = $InventoryShare.Length - 1; $Index -ge 0; $Index--) {
        if ($InventoryShare[$Index] -ne '\') {
            break
        }

        $TrailingBackslashCount++
    }

    $QuotedShare = $InventoryShare
    if ($TrailingBackslashCount -gt 0) {
        $QuotedShare += ('\' * $TrailingBackslashCount)
    }

    $Arguments += ' -InventoryShare "' + $QuotedShare + '"'
}

$Today = Get-Date
$TimeParts = $TaskTime.Split(':')
$At = Get-Date -Year $Today.Year -Month $Today.Month -Day $Today.Day `
    -Hour ([int]$TimeParts[0]) -Minute ([int]$TimeParts[1]) -Second 0

$TaskAction = New-ScheduledTaskAction `
    -Execute $Executable `
    -Argument $Arguments `
    -WorkingDirectory $NormalizedInstallDir

$Trigger = New-ScheduledTaskTrigger -Daily -At $At

$Principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

$Settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Hours 4)

Register-ScheduledTask `
    -TaskPath $TaskPath `
    -TaskName $TaskName `
    -Action $TaskAction `
    -Trigger $Trigger `
    -Principal $Principal `
    -Settings $Settings `
    -Description "Maintenance Toolkit automatic maintenance task managed by the MSI package." `
    -Force | Out-Null
