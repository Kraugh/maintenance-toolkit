[CmdletBinding()]
param(
    [string]$InventoryShare
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$collectorPath = Join-Path $repoRoot "app\modules\inventory\InventoryCollector.ps1"
$writerPath = Join-Path $repoRoot "app\modules\inventory\InventorySnapshotWriter.ps1"
$reportsPath = Join-Path $repoRoot "reports"

. $collectorPath
. $writerPath

$totalWatch = [System.Diagnostics.Stopwatch]::StartNew()

$snapshot = Get-MTInventorySnapshot -CollectorVersion "5.0.0-dev"

$result = Publish-MTInventorySnapshot `
    -Snapshot $snapshot `
    -LocalDirectory $reportsPath `
    -InventoryShare $InventoryShare

$totalWatch.Stop()

Write-Host ""
Write-Host "Inventory snapshot writer test completed."
Write-Host ("Schema version   : {0}" -f $snapshot.schemaVersion)
Write-Host ("Snapshot ID      : {0}" -f $snapshot.snapshotId)
Write-Host ("Collection status: {0}" -f $snapshot.collection.status)
Write-Host ("File name        : {0}" -f $result.fileName)
Write-Host ("Local path       : {0}" -f $result.localPath)
Write-Host ("Local write      : {0} ms" -f $result.localDurationMs)
Write-Host ("Remote requested : {0}" -f $result.remoteAttempted)
Write-Host ("Remote status    : {0}" -f $result.remoteStatus)

if ($null -ne $result.remoteDurationMs) {
    Write-Host ("Remote write     : {0} ms" -f $result.remoteDurationMs)
}

if ($null -ne $result.remotePath) {
    Write-Host ("Remote path      : {0}" -f $result.remotePath)
}

if ($null -ne $result.warningCode) {
    Write-Warning ("Remote publish warning: {0}" -f $result.warningCode)
}

Write-Host ("Total test       : {0} ms" -f $totalWatch.ElapsedMilliseconds)

try {
    Set-Clipboard -Value $result.localPath
    Write-Host ""
    Write-Host "Local output file path copied to clipboard."
}
catch {
    # Clipboard support is not required for the test.
}
