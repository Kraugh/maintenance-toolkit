Set-StrictMode -Version Latest

function ConvertTo-MTInventorySafeFileComponent {
    param(
        [AllowNull()]
        [string]$Value,
        [string]$Fallback = "unknown"
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Fallback
    }

    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    $safe = $Value.Trim()

    foreach ($char in $invalidChars) {
        $safe = $safe.Replace([string]$char, "_")
    }

    $safe = $safe -replace '\s+', '_'
    $safe = $safe.Trim('.', '_')

    if ([string]::IsNullOrWhiteSpace($safe)) {
        return $Fallback
    }

    return $safe
}

function Get-MTInventorySnapshotFileName {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Snapshot
    )

    $hostname = ConvertTo-MTInventorySafeFileComponent -Value ([string]$Snapshot.device.data.hostname) -Fallback "unknown-host"
    $snapshotId = ConvertTo-MTInventorySafeFileComponent -Value ([string]$Snapshot.snapshotId) -Fallback ([guid]::NewGuid().ToString())

    $collectedAt = $null
    try {
        $collectedAt = [datetimeoffset]::Parse(
            [string]$Snapshot.collectedAt,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind
        )
    }
    catch {
        $collectedAt = [datetimeoffset]::Now
    }

    $timestamp = $collectedAt.ToString("yyyyMMdd-HHmmss")
    return "{0}_{1}_{2}.json" -f $hostname, $timestamp, $snapshotId
}

function ConvertTo-MTInventoryJson {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Snapshot
    )

    return ($Snapshot | ConvertTo-Json -Depth 16)
}

function Write-MTInventoryUtf8NoBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Write-MTInventoryAtomicFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory,

        [Parameter(Mandatory = $true)]
        [string]$FileName,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        New-Item -ItemType Directory -Path $Directory -Force -ErrorAction Stop | Out-Null
    }

    $finalPath = Join-Path $Directory $FileName
    $tempPath = $finalPath + ".tmp"

    try {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction Stop
        }

        Write-MTInventoryUtf8NoBom -Path $tempPath -Content $Content

        if (Test-Path -LiteralPath $finalPath) {
            throw "Inventory snapshot target already exists: $finalPath"
        }

        Move-Item -LiteralPath $tempPath -Destination $finalPath -ErrorAction Stop
        return $finalPath
    }
    catch {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

function Publish-MTInventorySnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Snapshot,

        [Parameter(Mandatory = $true)]
        [string]$LocalDirectory,

        [AllowNull()]
        [string]$InventoryShare
    )

    $fileName = Get-MTInventorySnapshotFileName -Snapshot $Snapshot
    $json = ConvertTo-MTInventoryJson -Snapshot $Snapshot

    $localWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $localPath = Write-MTInventoryAtomicFile -Directory $LocalDirectory -FileName $fileName -Content $json
    $localWatch.Stop()

    $remoteAttempted = -not [string]::IsNullOrWhiteSpace($InventoryShare)
    $remoteStatus = if ($remoteAttempted) { "pending" } else { "not_requested" }
    $remotePath = $null
    $remoteDurationMs = $null
    $warningCode = $null

    if ($remoteAttempted) {
        $remoteWatch = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $remotePath = Write-MTInventoryAtomicFile -Directory $InventoryShare -FileName $fileName -Content $json
            $remoteStatus = "ok"
        }
        catch {
            $remoteStatus = "warning"
            $warningCode = "inventory_share_publish_failed"
            $remotePath = $null
        }
        finally {
            $remoteWatch.Stop()
            $remoteDurationMs = [int64]$remoteWatch.ElapsedMilliseconds
        }
    }

    return [pscustomobject][ordered]@{
        fileName         = $fileName
        localPath        = $localPath
        localDurationMs  = [int64]$localWatch.ElapsedMilliseconds
        remoteAttempted  = $remoteAttempted
        remoteStatus     = $remoteStatus
        remotePath       = $remotePath
        remoteDurationMs = $remoteDurationMs
        warningCode      = $warningCode
    }
}

function Update-MTInventoryWindowsUpdateStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [bool]$Attempted,

        [Parameter(Mandatory = $true)]
        [ValidateSet("ok", "error", "not_run")]
        [string]$Status,

        [AllowNull()]
        [AllowEmptyString()]
        [ValidateScript({ [string]::IsNullOrWhiteSpace($_) -or $_ -in @("update_scan_failed", "update_download_failed", "update_install_failed") })]
        [string]$ErrorCode
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Inventory snapshot not found: $Path"
    }

    $snapshot = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    $snapshot.maintenance.data.windowsUpdate.attempted = $Attempted
    $snapshot.maintenance.data.windowsUpdate.status = $Status
    $snapshot.maintenance.data.windowsUpdate.errorCode = if ([string]::IsNullOrWhiteSpace($ErrorCode)) { $null } else { $ErrorCode }

    $json = ConvertTo-MTInventoryJson -Snapshot $snapshot
    $tempPath = $Path + ".tmp"

    try {
        Write-MTInventoryUtf8NoBom -Path $tempPath -Content $json
        Move-Item -LiteralPath $tempPath -Destination $Path -Force -ErrorAction Stop
    }
    catch {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

function Update-MTInventoryOemStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object]$OemStatus
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Inventory snapshot not found: $Path"
    }

    $snapshot = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop |
        ConvertFrom-Json -ErrorAction Stop

    if ($null -eq $snapshot.maintenance.data.PSObject.Properties["oem"]) {
        $snapshot.maintenance.data |
            Add-Member -NotePropertyName oem -NotePropertyValue $OemStatus
    }
    else {
        $snapshot.maintenance.data.oem = $OemStatus
    }

    $json = ConvertTo-MTInventoryJson -Snapshot $snapshot
    $tempPath = $Path + ".tmp"

    try {
        Write-MTInventoryUtf8NoBom -Path $tempPath -Content $json
        Move-Item -LiteralPath $tempPath -Destination $Path -Force -ErrorAction Stop
    }
    catch {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}
