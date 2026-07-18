###############################################################################
# Maintenance Toolkit 3.7.1 - Modulo inventario
###############################################################################

. "$PSScriptRoot\00_common.ps1"

$Module = "INVENTORY"

try {
    $OutputPath = Join-Path $env:MT_SESSION_DIR "inventario_sistema.txt"

    $ComputerSystem = Get-CimInstance Win32_ComputerSystem
    $OperatingSystem = Get-CimInstance Win32_OperatingSystem
    $Bios = Get-CimInstance Win32_BIOS
    $Processor = Get-CimInstance Win32_Processor
    $RamGb = [math]::Round($ComputerSystem.TotalPhysicalMemory / 1GB, 2)

    $Lines = @(
        "Computer: $env:COMPUTERNAME",
        "Produttore: $($ComputerSystem.Manufacturer)",
        "Modello: $($ComputerSystem.Model)",
        "Seriale: $($Bios.SerialNumber)",
        "BIOS: $($Bios.SMBIOSBIOSVersion)",
        "Windows: $($OperatingSystem.Caption) $($OperatingSystem.Version)",
        "CPU: $($Processor.Name)",
        "RAM GB: $RamGb",
        "",
        "DISCHI:"
    )

    $Lines += Get-PhysicalDisk | ForEach-Object {
        "{0} | {1} GB | {2} | {3} | {4}" -f `
            $_.FriendlyName,
            [math]::Round($_.Size / 1GB, 1),
            $_.MediaType,
            $_.BusType,
            $_.HealthStatus
    }

    $Lines += ""
    $Lines += "APPLICAZIONI WINGET:"

    $Winget = Get-Command winget.exe -ErrorAction SilentlyContinue

    if ($Winget) {
        $WingetListPath = Join-Path $env:MT_SESSION_DIR "winget_applicazioni.txt"

        $WingetOutput = & $Winget.Source list `
            --accept-source-agreements `
            --disable-interactivity 2>&1

        $WingetOutput |
            Set-Content -LiteralPath $WingetListPath -Encoding UTF8

        $Lines += $WingetOutput
    }
    else {
        $Lines += "Winget non disponibile."
    }

    $Lines | Set-Content -LiteralPath $OutputPath -Encoding UTF8

    Write-Ok "Inventario salvato: $OutputPath" $Module
    Set-ModuleResult "Inventario hardware/software" "OK" "Creato inventario_sistema.txt"
    exit 0
}
catch {
    Write-ErrorLog $_.Exception.Message $Module
    Set-ModuleResult "Inventario hardware/software" "ERROR" $_.Exception.Message
    exit 1
}
