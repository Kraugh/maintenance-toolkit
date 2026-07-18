###############################################################################
# Maintenance Toolkit 3.0.6.2
#
# Autore:
#   Luca Miselli
#   https://www.kraugh.it
#
# Sviluppato con l'indispensabile aiuto di una Rubber Duck molto paziente.
###############################################################################

[CmdletBinding()]
param(
    [switch]$RunAll,
    [string[]]$Only
)

$ErrorActionPreference = "Stop"
$Version = "3.0.6.2"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesDir = Join-Path $Root "modules"
$LogsDir = Join-Path $Root "logs"
$IniPath = Join-Path $Root "MaintenanceToolkit.ini"

# I log sono separati per computer, così il toolkit può essere eseguito
# anche da una chiavetta USB o da una share senza mescolare le sessioni.
$ComputerLogName = ($env:COMPUTERNAME -replace '[^A-Za-z0-9._-]', '_')
$ComputerLogsDir = Join-Path $LogsDir $ComputerLogName

New-Item -ItemType Directory -Path $ComputerLogsDir -Force | Out-Null

$env:MT_ROOT = $Root
$env:MT_MODULES = $ModulesDir
$env:MT_LOGS = $ComputerLogsDir
$env:MT_COMPUTER_LOG_NAME = $ComputerLogName
$env:MT_INI = $IniPath

. (Join-Path $ModulesDir "00_common.ps1")
$Config = Read-IniFile $IniPath

$Catalog = @(
    [pscustomobject]@{ Id=1;  Key="Connectivity";     Name="Controllo connettivita";        File="01_connectivity.ps1" },
    [pscustomobject]@{ Id=2;  Key="Inventory";        Name="Inventario hardware/software"; File="02_inventory.ps1" },
    [pscustomobject]@{ Id=3;  Key="NetworkReport";    Name="Report rete";                  File="03_network.ps1" },
    [pscustomobject]@{ Id=4;  Key="RestorePoint";     Name="Crea punto di ripristino";          File="04_restore_point.ps1" },
    [pscustomobject]@{ Id=5;  Key="Winget";           Name="Aggiornamenti Winget";         File="05_winget.ps1" },
    [pscustomobject]@{ Id=6;  Key="MicrosoftUpdate";  Name="Microsoft Update";             File="06_microsoft_update.ps1" },
    [pscustomobject]@{ Id=7;  Key="Defender";         Name="Microsoft Defender";           File="07_defender.ps1" },
    [pscustomobject]@{ Id=8;  Key="OEM";              Name="Aggiornamenti OEM";            File="08_oem.ps1" },
    [pscustomobject]@{ Id=9;  Key="DISM";             Name="DISM RestoreHealth";           File="09_dism.ps1" },
    [pscustomobject]@{ Id=10; Key="SFC";              Name="SFC Scannow";                  File="10_sfc.ps1" },
    [pscustomobject]@{ Id=11; Key="DiskHealth";       Name="Salute dischi";                File="11_disk_health.ps1" },
    [pscustomobject]@{ Id=12; Key="TempCleanup";      Name="Pulizia TEMP";                 File="13_temp_cleanup.ps1" },
    [pscustomobject]@{ Id=13; Key="ComponentCleanup"; Name="Pulizia componenti Windows";   File="14_component_cleanup.ps1" }
)


function Show-Menu {
    Clear-Host
    Write-Host "============================================================"
    Write-Host " Maintenance Toolkit $Version"
    Write-Host "============================================================"
    Write-Host ""

    foreach ($Module in $Catalog) {
        $Enabled = Get-IniBool $Config "Modules" $Module.Key $false
        $Flag = if ($Enabled) { "ON " } else { "OFF" }

        Write-Host (
            "[{0,2}] [{1}] {2}" -f
            $Module.Id,
            $Flag,
            $Module.Name
        )
    }

    Write-Host ""
    Write-Host "[A] Esegui tutti i moduli abilitati"
    Write-Host "[C] Apri configurazione INI"
    Write-Host "[L] Apri cartella log"
    Write-Host "[I] Informazioni e licenza"
    Write-Host "[Q] Esci"
    Write-Host ""
}

function Select-Modules {
    while ($true) {
        Show-Menu
        $Choice = Read-Host "Selezione"

        if ($Choice -match '^[Qq]$') {
            return $null
        }

        if ($Choice -match '^[Cc]$') {
            Start-Process notepad.exe $IniPath
            continue
        }

        if ($Choice -match '^[Ll]$') {
            Start-Process explorer.exe $ComputerLogsDir
            continue
        }


if ($Choice -match '^[Ii]$') {
    Clear-Host
    Get-Content -LiteralPath (Join-Path $Root "ABOUT.txt") |
        ForEach-Object { Write-Host $_ }

    Write-Host ""
    Write-Host "Premere Invio per tornare al menu..."
    [void](Read-Host)
    continue
}

        if ($Choice -match '^[Aa]$') {
            return @(
                $Catalog |
                Where-Object {
                    Get-IniBool $Config "Modules" $_.Key $false
                }
            )
        }

        $Ids = $Choice -split '[,; ]+' |
            Where-Object { $_ -match '^\d+$' } |
            ForEach-Object { [int]$_ }

        if ($Ids.Count -gt 0) {
            $Selected = @($Catalog | Where-Object Id -in $Ids)

            if ($Selected.Count -gt 0) {
                return $Selected
            }
        }
    }
}

function Invoke-ToolkitSession {
    param(
        [Parameter(Mandatory)]
        [array]$Selected
    )

    $SessionTimestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $SessionId = "${SessionTimestamp}_${ComputerLogName}"
    $SessionDir = Join-Path $ComputerLogsDir $SessionId
    New-Item -ItemType Directory -Path $SessionDir -Force | Out-Null

    $env:MT_SESSION = $SessionId
    $env:MT_SESSION_DIR = $SessionDir
    $env:MT_RESULT = Join-Path $SessionDir "module_result.json"

    # Inizializza i percorsi dei log solo dopo aver creato la sessione.
    Initialize-LogPaths

    $Results = [System.Collections.Generic.List[object]]::new()
    $Start = Get-Date

    Write-Main "============================================================"
    Write-Main "MAINTENANCE TOOLKIT $Version - SESSIONE $SessionId"
    Write-Main "Computer: $env:COMPUTERNAME"
    Write-Main "Utente: $env:USERNAME"
    Write-Main "Moduli selezionati:"

    foreach ($SelectedModule in $Selected) {
        Write-Main " - $($SelectedModule.Name)"
    }

    Write-Main "============================================================"

    foreach ($Module in $Selected) {
        Remove-Item $env:MT_RESULT -Force -ErrorAction SilentlyContinue
        $ModuleStart = Get-Date

        Write-Main "AVVIO: $($Module.Name)"

        try {
            & (Join-Path $ModulesDir $Module.File)

            $Code = $LASTEXITCODE
            if ($null -eq $Code) {
                $Code = 0
            }

            if (Test-Path $env:MT_RESULT) {
                $Result = Get-Content $env:MT_RESULT -Raw | ConvertFrom-Json
            }
            else {
                $Status = switch ($Code) {
                    0       { "OK" }
                    10      { "SKIP" }
                    20      { "WARN" }
                    default { "ERROR" }
                }

                $Result = [pscustomobject]@{
                    Module = $Module.Name
                    Status = $Status
                    Detail = "Exit code $Code"
                    RebootRequired = $false
                }
            }
        }
        catch {
            Write-ErrorLog "$($Module.Name): $($_.Exception.Message)"
            Write-ErrorLog $_.InvocationInfo.PositionMessage

            $Result = [pscustomobject]@{
                Module = $Module.Name
                Status = "ERROR"
                Detail = $_.Exception.Message
                RebootRequired = $false
            }
        }

        $Results.Add([pscustomobject]@{
            Module = $Result.Module
            Status = $Result.Status
            Duration = ((Get-Date) - $ModuleStart).ToString("hh\:mm\:ss")
            Detail = $Result.Detail
            RebootRequired = [bool]$Result.RebootRequired
        })

        if (
            $Result.Status -eq "ERROR" -and
            -not (Get-IniBool $Config "General" "ContinueOnError" $true)
        ) {
            break
        }
    }

    $End = Get-Date
    $Reboot = @($Results | Where-Object RebootRequired).Count -gt 0
    $Errors = @($Results | Where-Object Status -eq "ERROR").Count
    $Warnings = @($Results | Where-Object Status -eq "WARN").Count

    $Txt = Join-Path $SessionDir "riepilogo.txt"
    $Csv = Join-Path $SessionDir "riepilogo.csv"
    $Html = Join-Path $SessionDir "riepilogo.html"

    $Signature = @(
        "============================================================",
        "                 Maintenance Toolkit $Version",
        "============================================================",
        "",
        "Autore:",
        "    Luca Miselli",
        "    https://www.kraugh.it",
        "",
        "Sviluppato con l'indispensabile aiuto",
        "di una Rubber Duck molto paziente.",
        "",
        "Grazie per aver utilizzato Maintenance Toolkit.",
        "",
        "============================================================"
    )

    $Lines = @(
        "MAINTENANCE TOOLKIT $Version",
        "Sessione: $SessionId",
        "Computer: $env:COMPUTERNAME",
        "Inizio: $($Start.ToString('yyyy-MM-dd HH:mm:ss'))",
        "Fine: $($End.ToString('yyyy-MM-dd HH:mm:ss'))",
        "Durata: $(($End-$Start).ToString('hh\:mm\:ss'))",
        "",
        ("{0,-30} {1,-7} {2,-10} {3}" -f "MODULO", "STATO", "DURATA", "DETTAGLIO"),
        ("-" * 110)
    )

    foreach ($Result in $Results) {
        $Lines += (
            "{0,-30} {1,-7} {2,-10} {3}" -f
            $Result.Module,
            $Result.Status,
            $Result.Duration,
            $Result.Detail
        )
    }

    $Lines += @(
        "",
        "Errori: $Errors",
        "Avvisi: $Warnings",
        "Riavvio necessario: $(if($Reboot){'SI'}else{'NO'})",
        "Riavvio automatico: MAI",
        ""
    )

    $Lines += $Signature

    $Lines | Set-Content -LiteralPath $Txt -Encoding UTF8
    $Results | Export-Csv -LiteralPath $Csv -NoTypeInformation -Encoding UTF8

    if (Get-IniBool $Config "General" "GenerateHtmlReport" $true) {
        Add-Type -AssemblyName System.Web

        $Rows = foreach ($Result in $Results) {
            $Class = $Result.Status.ToLower()
            $ModuleText = [System.Web.HttpUtility]::HtmlEncode([string]$Result.Module)
            $StatusText = [System.Web.HttpUtility]::HtmlEncode([string]$Result.Status)
            $DurationText = [System.Web.HttpUtility]::HtmlEncode([string]$Result.Duration)
            $DetailText = [System.Web.HttpUtility]::HtmlEncode([string]$Result.Detail)

            "<tr class='$Class'><td>$ModuleText</td><td>$StatusText</td><td>$DurationText</td><td>$DetailText</td></tr>"
        }

        @"
<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<title>Maintenance Toolkit $Version - $SessionId</title>
<style>
body{font-family:Segoe UI,Arial;margin:32px;background:#f5f5f5;color:#222}
main{background:white;padding:24px;border-radius:10px;max-width:1200px;margin:auto}
table{border-collapse:collapse;width:100%}
th,td{padding:9px;border:1px solid #ccc;text-align:left;vertical-align:top}
.ok{background:#e7f6e7}
.warn{background:#fff4cc}
.error{background:#ffdede}
.skip{background:#eee}
footer{margin-top:28px;padding-top:18px;border-top:1px solid #bbb;text-align:center;line-height:1.5}
</style>
</head>
<body>
<main>
<h1>Maintenance Toolkit $Version</h1>
<p>
<b>Computer:</b> $env:COMPUTERNAME<br>
<b>Sessione:</b> $SessionId<br>
<b>Durata:</b> $(($End-$Start).ToString('hh\:mm\:ss'))<br>
<b>Riavvio necessario:</b> $(if($Reboot){'SI'}else{'NO'})<br>
<b>Riavvio automatico:</b> MAI
</p>
<table>
<thead>
<tr><th>Modulo</th><th>Stato</th><th>Durata</th><th>Dettaglio</th></tr>
</thead>
<tbody>
$($Rows -join "`n")
</tbody>
</table>
<footer>
<strong>Maintenance Toolkit $Version</strong><br>
Autore: Luca Miselli —
<a href="https://www.kraugh.it">www.kraugh.it</a><br>
Sviluppato con l'indispensabile aiuto di una Rubber Duck molto paziente.<br>
Grazie per aver utilizzato Maintenance Toolkit.
</footer>
</main>
</body>
</html>
"@ | Set-Content -LiteralPath $Html -Encoding UTF8
    }

    Write-Host ""
    $Lines | ForEach-Object { Write-Host $_ }

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "RIEPILOGO RAPIDO SESSIONE"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "Eseguiti:"

    foreach ($Result in $Results) {
        $Marker = switch ($Result.Status) {
            "OK"    { "[OK]  " }
            "WARN"  { "[WARN]" }
            "ERROR" { "[ERR] " }
            "SKIP"  { "[SKIP]" }
            default { "[?]   " }
        }
        Write-Host ("  {0} {1}" -f $Marker, $Result.Module)
    }

    $ExecutedNames = @($Results | ForEach-Object Module)
    $NotExecuted = @($Catalog | Where-Object { $_.Name -notin $ExecutedNames })

    Write-Host ""
    Write-Host "Non eseguiti:"
    if ($NotExecuted.Count -eq 0) { Write-Host "  Nessuno" }
    else { foreach ($Missing in $NotExecuted) { Write-Host "  [ ] $($Missing.Name)" } }

    Write-Host ""
    Write-Host "Errori: $Errors"
    Write-Host "Avvisi: $Warnings"
    Write-Host "Riavvio richiesto: $(if($Reboot){'SI'}else{'NO'})"
    Write-Host "Durata sessione: $(($End-$Start).ToString('hh\:mm\:ss'))"
    Write-Host "============================================================"

    Write-Main "Riepilogo TXT: $Txt"
    Write-Main "Riepilogo HTML: $Html"

    $Retention = [int](Get-IniValue $Config "General" "LogRetentionDays" 90)

    Get-ChildItem $ComputerLogsDir -Directory -ErrorAction SilentlyContinue |
        Where-Object LastWriteTime -lt (Get-Date).AddDays(-$Retention) |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    return [pscustomobject]@{
        Errors = $Errors
        Warnings = $Warnings
    }
}

# Modalità non interattiva tramite parametri.
if ($RunAll -or ($Only -and $Only.Count -gt 0)) {
    $Selected = if ($RunAll) {
        @(
            $Catalog |
            Where-Object {
                Get-IniBool $Config "Modules" $_.Key $false
            }
        )
    }
    else {
        @($Catalog | Where-Object Key -in $Only)
    }

    if ($Selected.Count -eq 0) {
        exit 0
    }

    $Outcome = Invoke-ToolkitSession -Selected $Selected

    if ($Outcome.Errors -gt 0) {
        exit 1
    }

    if ($Outcome.Warnings -gt 0) {
        exit 20
    }

    exit 0
}

# Modalità interattiva: dopo ogni esecuzione torna al menu oppure esce.
while ($true) {
    $Selected = Select-Modules

    if ($null -eq $Selected) {
        exit 0
    }

    if ($Selected.Count -eq 0) {
        continue
    }

    $null = Invoke-ToolkitSession -Selected $Selected

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "[M] Torna al menu principale"
    Write-Host "[Q] Esci"
    Write-Host "============================================================"
    Write-Host ""

    while ($true) {
        $NextAction = Read-Host "Selezione"

        if ($NextAction -match '^[Mm]$') {
            break
        }

        if ($NextAction -match '^[Qq]$') {
            exit 0
        }
    }
}
