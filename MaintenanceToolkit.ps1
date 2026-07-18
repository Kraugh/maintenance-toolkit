###############################################################################
# Maintenance Toolkit 3.7.0
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
    [string[]]$Only,
    [switch]$SelfTest,
    [switch]$CheckUpdates
)

$ErrorActionPreference = "Stop"
$Version = "3.7.0"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesDir = Join-Path $Root "modules"
$LogsDir = Join-Path $Root "logs"
$IniPath = Join-Path $Root "MaintenanceToolkit.ini"
$UpdateManifestUrl = "https://www.kraugh.it/api/maintenance-toolkit/version.json"

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

function Invoke-MTUpdateCheck {
    [CmdletBinding()]
    param(
        [switch]$Quiet
    )

    if (-not $Quiet) {
        Write-Host ""
        Write-Host "La papera sta cercando versioni più recenti..." -ForegroundColor Cyan
        Write-Host ""
    }

    try {
        $Manifest = Invoke-RestMethod -Uri $UpdateManifestUrl -Method Get -TimeoutSec 10 -ErrorAction Stop

        if (-not $Manifest.latest_version) {
            throw "Il manifest non contiene il campo latest_version."
        }

        $InstalledVersion = [version]$Version
        $LatestVersion = [version]([string]$Manifest.latest_version)
        $MinimumSupported = $null

        if ($Manifest.minimum_supported) {
            $MinimumSupported = [version]([string]$Manifest.minimum_supported)
        }

        if (-not $Quiet) {
            Write-Host ("Versione installata : {0}" -f $InstalledVersion)
            Write-Host ("Versione disponibile: {0}" -f $LatestVersion)
            Write-Host ""
        }

        if ($InstalledVersion -lt $LatestVersion) {
            if (-not $Quiet) {
                Write-Host "La papera ha trovato una versione più recente di Maintenance Toolkit." -ForegroundColor Yellow

                if ($MinimumSupported -and $InstalledVersion -lt $MinimumSupported) {
                    Write-Host "La versione installata non è più tra quelle supportate." -ForegroundColor Yellow
                }

                if ($Manifest.release_notes) {
                    Write-Host ""
                    Write-Host "Novità:"
                    Write-Host ([string]$Manifest.release_notes)
                }

                if ($Manifest.download_url) {
                    Write-Host ""
                    Write-Host "Download:"
                    Write-Host ([string]$Manifest.download_url) -ForegroundColor Cyan
                }
            }

            return [pscustomobject]@{
                Status = "UPDATE_AVAILABLE"
                InstalledVersion = $InstalledVersion
                LatestVersion = $LatestVersion
                Manifest = $Manifest
            }
        }

        if ($InstalledVersion -gt $LatestVersion) {
            if (-not $Quiet) {
                Write-Host "Questa versione è più recente di quella pubblicata. La papera sospetta un ambiente di test." -ForegroundColor Yellow
            }

            return [pscustomobject]@{
                Status = "DEVELOPMENT_VERSION"
                InstalledVersion = $InstalledVersion
                LatestVersion = $LatestVersion
                Manifest = $Manifest
            }
        }

        if (-not $Quiet) {
            Write-Host "La papera non ha trovato versioni più recenti." -ForegroundColor Green
        }

        return [pscustomobject]@{
            Status = "CURRENT"
            InstalledVersion = $InstalledVersion
            LatestVersion = $LatestVersion
            Manifest = $Manifest
        }
    }
    catch {
        if (-not $Quiet) {
            Write-Host "La papera non è riuscita a controllare gli aggiornamenti." -ForegroundColor Yellow
            Write-Host "Maintenance Toolkit può comunque essere utilizzato normalmente."
            Write-Host ""
            Write-Host ("Dettaglio: {0}" -f $_.Exception.Message) -ForegroundColor DarkGray
        }

        return [pscustomobject]@{
            Status = "ERROR"
            InstalledVersion = [version]$Version
            LatestVersion = $null
            Manifest = $null
            Error = $_.Exception.Message
        }
    }
}

function Invoke-MTSelfTest {
    [CmdletBinding()]
    param()

    $Results = [System.Collections.Generic.List[object]]::new()

    function Add-SelfTestResult {
        param(
            [string]$Test,
            [ValidateSet("OK", "WARN", "ERROR")][string]$Status,
            [string]$Detail
        )

        $Results.Add([pscustomobject]@{
            Test = $Test
            Status = $Status
            Detail = $Detail
        })
    }

    Write-Host "============================================================"
    Write-Host " AUTOTEST MAINTENANCE TOOLKIT $Version"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "La papera sta controllando il Toolkit..." -ForegroundColor Cyan
    Write-Host ""

    if ($PSVersionTable.PSVersion -ge [version]"5.1") {
        Add-SelfTestResult "Versione PowerShell" "OK" ($PSVersionTable.PSVersion.ToString())
    }
    else {
        Add-SelfTestResult "Versione PowerShell" "ERROR" "È richiesto Windows PowerShell 5.1 o successivo."
    }

    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)
    if ($Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Add-SelfTestResult "Privilegi amministrativi" "OK" "Sessione elevata."
    }
    else {
        Add-SelfTestResult "Privilegi amministrativi" "WARN" "Sessione non elevata; il launcher BAT richiede normalmente l'elevazione."
    }

    foreach ($RequiredPath in @(
        $IniPath,
        (Join-Path $Root "Avvia_Manutenzione.bat"),
        (Join-Path $Root "ABOUT.txt"),
        (Join-Path $ModulesDir "00_common.ps1")
    )) {
        if (Test-Path -LiteralPath $RequiredPath -PathType Leaf) {
            Add-SelfTestResult ("File: " + (Split-Path $RequiredPath -Leaf)) "OK" "Presente."
        }
        else {
            Add-SelfTestResult ("File: " + (Split-Path $RequiredPath -Leaf)) "ERROR" "File mancante."
        }
    }

    foreach ($Module in $Catalog) {
        $ModulePath = Join-Path $ModulesDir $Module.File
        if (Test-Path -LiteralPath $ModulePath -PathType Leaf) {
            Add-SelfTestResult ("Modulo: " + $Module.File) "OK" "Presente."
        }
        else {
            Add-SelfTestResult ("Modulo: " + $Module.File) "ERROR" "File mancante."
        }
    }

    $PowerShellFiles = @(
        Get-ChildItem -LiteralPath $Root -Filter "*.ps1" -File -ErrorAction SilentlyContinue
        Get-ChildItem -LiteralPath $ModulesDir -Filter "*.ps1" -File -ErrorAction SilentlyContinue
    )

    foreach ($File in $PowerShellFiles) {
        $Tokens = $null
        $ParseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile(
            $File.FullName,
            [ref]$Tokens,
            [ref]$ParseErrors
        )

        if ($ParseErrors.Count -eq 0) {
            Add-SelfTestResult ("Sintassi: " + $File.Name) "OK" "Nessun errore rilevato."
        }
        else {
            $Detail = ($ParseErrors | ForEach-Object { $_.Message }) -join " | "
            Add-SelfTestResult ("Sintassi: " + $File.Name) "ERROR" $Detail
        }
    }

    try {
        $TestConfig = Read-IniFile $IniPath
        if ($TestConfig.ContainsKey("General") -and $TestConfig.ContainsKey("Modules")) {
            Add-SelfTestResult "Configurazione INI" "OK" "Sezioni General e Modules presenti."
        }
        else {
            Add-SelfTestResult "Configurazione INI" "ERROR" "Mancano le sezioni General o Modules."
        }
    }
    catch {
        Add-SelfTestResult "Configurazione INI" "ERROR" $_.Exception.Message
    }

    $LocalManifestPath = Join-Path $Root "kraugh_it\version.json"
    if (Test-Path -LiteralPath $LocalManifestPath) {
        try {
            $LocalManifest = Get-Content -LiteralPath $LocalManifestPath -Raw | ConvertFrom-Json
            [void][version]([string]$LocalManifest.latest_version)
            Add-SelfTestResult "Manifest locale" "OK" "version.json valido."
        }
        catch {
            Add-SelfTestResult "Manifest locale" "ERROR" $_.Exception.Message
        }
    }
    else {
        Add-SelfTestResult "Manifest locale" "WARN" "kraugh_it\version.json non presente nel pacchetto."
    }

    $UpdateResult = Invoke-MTUpdateCheck -Quiet
    if ($UpdateResult.Status -eq "ERROR") {
        Add-SelfTestResult "Endpoint aggiornamenti" "WARN" "Non raggiungibile: $($UpdateResult.Error)"
    }
    else {
        Add-SelfTestResult "Endpoint aggiornamenti" "OK" ("Risponde; versione pubblicata {0}." -f $UpdateResult.LatestVersion)
    }

    foreach ($Result in $Results) {
        $Colour = switch ($Result.Status) {
            "OK" { "Green" }
            "WARN" { "Yellow" }
            "ERROR" { "Red" }
        }
        Write-Host ("[{0,-5}] {1} - {2}" -f $Result.Status, $Result.Test, $Result.Detail) -ForegroundColor $Colour
    }

    $Errors = @($Results | Where-Object Status -eq "ERROR").Count
    $Warnings = @($Results | Where-Object Status -eq "WARN").Count

    Write-Host ""
    Write-Host "============================================================"
    Write-Host ("Errori: {0}   Avvisi: {1}" -f $Errors, $Warnings)
    Write-Host "============================================================"

    if ($Errors -gt 0) {
        Write-Host "La papera è confusa. Controlliamo insieme i risultati dell'autotest." -ForegroundColor Red
    }
    elseif ($Warnings -gt 0) {
        Write-Host "La papera pensa che alcuni elementi meritino un'occhiata." -ForegroundColor Yellow
    }
    else {
        Write-Host "La papera non ha trovato nulla di insolito." -ForegroundColor Green
    }

    return [pscustomobject]@{
        Errors = $Errors
        Warnings = $Warnings
        Results = $Results
    }
}


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
    Write-Host "[T] Autotest del Toolkit"
    Write-Host "[U] Cerca aggiornamenti"
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

        if ($Choice -match '^[Tt]$') {
            Clear-Host
            $null = Invoke-MTSelfTest
            Write-Host ""
            Write-Host "Premere Invio per tornare al menu..."
            [void](Read-Host)
            continue
        }

        if ($Choice -match '^[Uu]$') {
            Clear-Host
            $null = Invoke-MTUpdateCheck
            Write-Host ""
            Write-Host "Premere Invio per tornare al menu..."
            [void](Read-Host)
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

# Autotest e controllo aggiornamenti da riga di comando.
if ($SelfTest) {
    $SelfTestOutcome = Invoke-MTSelfTest

    if ($SelfTestOutcome.Errors -gt 0) {
        exit 1
    }

    if ($SelfTestOutcome.Warnings -gt 0) {
        exit 20
    }

    exit 0
}

if ($CheckUpdates) {
    $UpdateOutcome = Invoke-MTUpdateCheck

    if ($UpdateOutcome.Status -eq "ERROR") {
        exit 20
    }

    if ($UpdateOutcome.Status -eq "UPDATE_AVAILABLE") {
        exit 10
    }

    exit 0
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
