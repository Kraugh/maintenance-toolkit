###############################################################################
# Maintenance Toolkit 3.7.2 - Modulo salute dischi
###############################################################################

. "$PSScriptRoot\00_common.ps1"

$Module = "DISK"

try {
    $OutputPath = Join-Path $env:MT_SESSION_DIR "salute_dischi.txt"
    $Disks = @(Get-PhysicalDisk)

    $Disks |
        Select-Object FriendlyName, MediaType, BusType, HealthStatus, OperationalStatus, Size |
        Format-Table -AutoSize |
        Out-String |
        Set-Content -LiteralPath $OutputPath -Encoding UTF8

    $Internal = @($Disks | Where-Object BusType -notin @("USB", "SD", "MMC"))
    $Removable = @($Disks | Where-Object BusType -in @("USB", "SD", "MMC"))
    $Bad = @($Disks | Where-Object HealthStatus -ne "Healthy")

    if ($Bad.Count -gt 0) {
        Write-WarnLog "$($Bad.Count) dischi non risultano Healthy." $Module

        Set-ModuleResult `
            "Salute dischi" `
            "WARN" `
            "$($Bad.Count) anomalie; interni $($Internal.Count); rimovibili $($Removable.Count)"

        exit 20
    }

    Write-Ok `
        "Dischi interni Healthy: $($Internal.Count); dispositivi rimovibili Healthy: $($Removable.Count)." `
        $Module

    Set-ModuleResult `
        "Salute dischi" `
        "OK" `
        "Interni $($Internal.Count) Healthy; rimovibili $($Removable.Count) Healthy"

    exit 0
}
catch {
    Write-ErrorLog $_.Exception.Message $Module
    Set-ModuleResult "Salute dischi" "ERROR" $_.Exception.Message
    exit 1
}
