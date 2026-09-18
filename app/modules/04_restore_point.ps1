. "$PSScriptRoot\00_common.ps1"

$Module = "RESTORE"
$Timestamp = Get-Date -Format "yyyy-MM-dd HH-mm-ss"
$Version = if ([string]::IsNullOrWhiteSpace($env:MT_VERSION)) { "unknown" } else { $env:MT_VERSION }
$Description = "Maintenance Toolkit $Version - Before maintenance - $Timestamp"
$MarkerPath = Join-Path $env:MT_SESSION_DIR "restore-point.json"

try {
    Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
    Checkpoint-Computer `
        -Description $Description `
        -RestorePointType MODIFY_SETTINGS `
        -ErrorAction Stop

    $RestorePoint = Get-ComputerRestorePoint -ErrorAction Stop |
        Where-Object Description -eq $Description |
        Sort-Object SequenceNumber -Descending |
        Select-Object -First 1

    if ($null -eq $RestorePoint) {
        throw (Get-MTRuntimeText "RESTORE_VERIFY_FAILED")
    }

    [pscustomobject]@{
        description = $Description
        sequenceNumber = [int]$RestorePoint.SequenceNumber
        createdAt = (Get-Date).ToString("o")
    } | ConvertTo-Json | Set-Content -LiteralPath $MarkerPath -Encoding UTF8

    $Detail = Get-MTRuntimeText "RESTORE_CREATED" @($Description)
    Write-Ok $Detail $Module
    Set-ModuleResult (Get-MTRuntimeText "MODULE_RESTORE_POINT") "OK" $Detail
    exit 0
}
catch {
    $Detail = Get-MTRuntimeText "RESTORE_FAILED" @($_.Exception.Message)
    Write-WarnLog $Detail $Module
    Set-ModuleResult (Get-MTRuntimeText "MODULE_RESTORE_POINT") "WARN" $Detail
    exit 20
}
