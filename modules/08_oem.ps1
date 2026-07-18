###############################################################################
# Maintenance Toolkit 3.0.6.2 - Modulo aggiornamenti OEM
###############################################################################

. "$PSScriptRoot\00_common.ps1"

$Module = "OEM"
$Manufacturer = (Get-CimInstance Win32_ComputerSystem).Manufacturer.Trim()

Write-Main "OEM rilevato: $Manufacturer"

if ($Manufacturer -match "Dell") {
    $Candidates = @(
        "$env:ProgramFiles\Dell\CommandUpdate\dcu-cli.exe",
        "${env:ProgramFiles(x86)}\Dell\CommandUpdate\dcu-cli.exe"
    )

    $Tool = $Candidates |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1

    if (-not $Tool) {
        Write-Skip "Dell Command Update non installato." $Module
        Set-ModuleResult "Aggiornamenti OEM" "SKIP" "Dell Command Update non installato"
        exit 10
    }

    $Result = Invoke-LoggedProcess `
        -FilePath $Tool `
        -ArgumentList @(
            "/applyUpdates",
            "-silent",
            "-reboot=disable",
            "-autoSuspendBitLocker=enable"
        ) `
        -Label "Dell Command Update" `
        -Module $Module `
        -SuccessCodes @(0, 1, 500)

    if ($Result -in @(0, 1, 500)) {
        $NeedsReboot = $Result -eq 1
        $Status = if ($NeedsReboot) { "WARN" } else { "OK" }
        $Detail = if ($NeedsReboot) {
            "Dell Command Update completato; riavvio richiesto"
        }
        else {
            "Dell Command Update completato"
        }

        Set-ModuleResult "Aggiornamenti OEM" $Status $Detail $NeedsReboot

        if ($NeedsReboot) { exit 20 }
        exit 0
    }

    Set-ModuleResult "Aggiornamenti OEM" "ERROR" "Dell Command Update exit code $Result"
    exit 1
}

if ($Manufacturer -match "HP|Hewlett") {
    $Candidates = @(
        "$env:ProgramFiles\HP\HPIA\HPImageAssistant.exe",
        "${env:ProgramFiles(x86)}\HP\HPIA\HPImageAssistant.exe",
        "$env:ProgramFiles\HP\HP Image Assistant\HPImageAssistant.exe"
    )

    $Tool = $Candidates |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1

    if (-not $Tool) {
        Write-Skip "HP Image Assistant non installato." $Module
        Set-ModuleResult "Aggiornamenti OEM" "SKIP" "HP Image Assistant non installato"
        exit 10
    }

    $ReportFolder = Join-Path $env:MT_SESSION_DIR "HP"
    New-Item -ItemType Directory -Path $ReportFolder -Force | Out-Null

    $Result = Invoke-LoggedProcess `
        -FilePath $Tool `
        -ArgumentList @(
            "/Operation:Analyze",
            "/Action:Install",
            "/Category:All",
            "/Selection:All",
            "/Silent",
            "/Noninteractive",
            "/ReportFolder:`"$ReportFolder`""
        ) `
        -Label "HP Image Assistant" `
        -Module $Module

    if ($Result -eq 0) {
        Set-ModuleResult "Aggiornamenti OEM" "OK" "HP Image Assistant completato"
        exit 0
    }

    Set-ModuleResult "Aggiornamenti OEM" "ERROR" "HP Image Assistant exit code $Result"
    exit 1
}

if ($Manufacturer -match "Lenovo") {
    Write-Skip `
        "Lenovo rilevato: Thin Installer non eseguito senza repository configurato." `
        $Module

    Set-ModuleResult `
        "Aggiornamenti OEM" `
        "SKIP" `
        "Repository Thin Installer non configurato"

    exit 10
}

Write-Skip "Produttore non gestito dal modulo OEM: $Manufacturer" $Module
Set-ModuleResult "Aggiornamenti OEM" "SKIP" "Produttore non gestito: $Manufacturer"
exit 10
