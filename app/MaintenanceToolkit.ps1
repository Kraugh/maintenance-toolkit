###############################################################################
# Maintenance Toolkit 4.0.0-dev.10
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
    [switch]$CheckUpdates,
    [ValidateSet("auto", "en-US", "it-IT")]
    [string]$Language = "auto"
)

$ErrorActionPreference = "Stop"
$Version = "4.0.0-dev.23a"
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $AppDir
$ModulesDir = Join-Path $AppDir "modules"
$LogsDir = Join-Path $Root "logs"
$IniPath = Join-Path $Root "config\MaintenanceToolkit.ini"
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

# MT4 bilingual application shell.
. (Join-Path $AppDir "core\Bootstrap.ps1")
$MT4Settings = Import-MTSettings -ProjectRoot $Root

if ($Language -ne "auto") {
    $MT4Settings.Language = $Language
}

$MT4Context = Initialize-MT4Foundation `
    -ProjectRoot $Root `
    -Settings $MT4Settings
$LanguageData = $MT4Context.Language
$LanguageResolution = $MT4Context.LanguageResolution
$CurrentLanguage = [string]$LanguageResolution.Language
$env:MT_LANGUAGE = $CurrentLanguage

# Native Network Diagnostics domain. Engine functions are loaded into the
# current MT process; no standalone NDP launcher or second elevation exists.
. (Join-Path $AppDir "modules\network\NetworkFoundation.ps1")
$null = Import-MTNetworkDiagnosticsFoundation -ProjectRoot $Root
. (Join-Path $AppDir "modules\network\SpeedTest.ps1")
. (Join-Path $AppDir "modules\network\NetworkDiagnostics.ps1")
. (Join-Path $AppDir "modules\network\NetworkReports.ps1")

function T {
    param(
        [Parameter(Mandatory)][string]$Key,
        [object[]]$Arguments = @(),
        [string]$Fallback = $null
    )

    Get-MTText -LanguageData $LanguageData -Key $Key -Arguments $Arguments -Fallback $Fallback
}

if ($LanguageResolution.FallbackUsed) {
    Write-Host (T "LANGUAGE_FALLBACK_NOTICE") -ForegroundColor Yellow
}

$Catalog = @(
    [pscustomobject]@{ Id=1;  Key="Connectivity";     NameKey="MODULE_CONNECTIVITY";       File="01_connectivity.ps1" },
    [pscustomobject]@{ Id=2;  Key="Inventory";        NameKey="MODULE_INVENTORY";          File="02_inventory.ps1" },
    [pscustomobject]@{ Id=3;  Key="NetworkReport";    NameKey="MODULE_NETWORK_REPORT";     File="03_network.ps1" },
    [pscustomobject]@{ Id=4;  Key="RestorePoint";     NameKey="MODULE_RESTORE_POINT";      File="04_restore_point.ps1" },
    [pscustomobject]@{ Id=5;  Key="Winget";           NameKey="MODULE_WINGET";             File="05_winget.ps1" },
    [pscustomobject]@{ Id=6;  Key="MicrosoftUpdate";  NameKey="MODULE_MICROSOFT_UPDATE";   File="06_microsoft_update.ps1" },
    [pscustomobject]@{ Id=7;  Key="Defender";         NameKey="MODULE_DEFENDER";           File="07_defender.ps1" },
    [pscustomobject]@{ Id=8;  Key="OEM";              NameKey="MODULE_OEM";                File="08_oem.ps1" },
    [pscustomobject]@{ Id=9;  Key="DISM";             NameKey="MODULE_DISM";               File="09_dism.ps1" },
    [pscustomobject]@{ Id=10; Key="SFC";              NameKey="MODULE_SFC";                File="10_sfc.ps1" },
    [pscustomobject]@{ Id=11; Key="DiskHealth";       NameKey="MODULE_DISK_HEALTH";        File="11_disk_health.ps1" },
    [pscustomobject]@{ Id=12; Key="TempCleanup";      NameKey="MODULE_TEMP_CLEANUP";       File="13_temp_cleanup.ps1" },
    [pscustomobject]@{ Id=13; Key="ComponentCleanup"; NameKey="MODULE_COMPONENT_CLEANUP";  File="14_component_cleanup.ps1" }
)

foreach ($Module in $Catalog) {
    $Module | Add-Member -NotePropertyName Name -NotePropertyValue (T $Module.NameKey) -Force
}

function Invoke-MTUpdateCheck {
    [CmdletBinding()]
    param(
        [switch]$Quiet
    )

    if (-not $Quiet) {
        Write-Host ""
        Write-Host (T "UPDATE_CHECKING") -ForegroundColor Cyan
        Write-Host ""
    }

    try {
        $Manifest = Invoke-RestMethod -Uri $UpdateManifestUrl -Method Get -TimeoutSec 10 -ErrorAction Stop

        if (-not $Manifest.latest_version) {
            throw (T "UPDATE_MANIFEST_MISSING")
        }

        $InstalledVersion = [version](([string]$Version -split "-")[0])
        $LatestVersion = [version](([string]$Manifest.latest_version -split "-")[0])
        $MinimumSupported = $null

        if ($Manifest.minimum_supported) {
            $MinimumSupported = [version]([string]$Manifest.minimum_supported)
        }

        if (-not $Quiet) {
            Write-Host ("{0}: {1}" -f (T "UPDATE_INSTALLED"), $InstalledVersion)
            Write-Host ("{0}: {1}" -f (T "UPDATE_AVAILABLE_VERSION"), $LatestVersion)
            Write-Host ""
        }

        if ($InstalledVersion -lt $LatestVersion) {
            if (-not $Quiet) {
                Write-Host (T "UPDATE_FOUND") -ForegroundColor Yellow

                if ($MinimumSupported -and $InstalledVersion -lt $MinimumSupported) {
                    Write-Host (T "UPDATE_UNSUPPORTED") -ForegroundColor Yellow
                }

                if ($Manifest.release_notes) {
                    Write-Host ""
                    Write-Host (T "UPDATE_WHATS_NEW")
                    Write-Host ([string]$Manifest.release_notes)
                }

                if ($Manifest.download_url) {
                    Write-Host ""
                    Write-Host (T "UPDATE_DOWNLOAD")
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
                Write-Host (T "UPDATE_DEVELOPMENT") -ForegroundColor Yellow
            }

            return [pscustomobject]@{
                Status = "DEVELOPMENT_VERSION"
                InstalledVersion = $InstalledVersion
                LatestVersion = $LatestVersion
                Manifest = $Manifest
            }
        }

        if (-not $Quiet) {
            Write-Host (T "UPDATE_CURRENT") -ForegroundColor Green
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
            Write-Host (T "UPDATE_FAILED") -ForegroundColor Yellow
            Write-Host (T "UPDATE_CAN_CONTINUE")
            Write-Host ""
            Write-Host ("{0}: {1}" -f (T "UPDATE_DETAIL"), $_.Exception.Message) -ForegroundColor DarkGray
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
    Write-Host (" {0} {1}" -f (T "SELFTEST_TITLE"), $Version)
    Write-Host "============================================================"
    Write-Host ""
    Write-Host (T "SELFTEST_CHECKING") -ForegroundColor Cyan
    Write-Host ""

    if ($PSVersionTable.PSVersion -ge [version]"5.1") {
        Add-SelfTestResult (T "SELFTEST_PS_VERSION") "OK" ($PSVersionTable.PSVersion.ToString())
    }
    else {
        Add-SelfTestResult (T "SELFTEST_PS_VERSION") "ERROR" (T "SELFTEST_PS_REQUIRED")
    }

    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)
    if ($Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Add-SelfTestResult (T "SELFTEST_ADMIN") "OK" (T "SELFTEST_ADMIN_OK")
    }
    else {
        Add-SelfTestResult (T "SELFTEST_ADMIN") "WARN" (T "SELFTEST_ADMIN_WARN")
    }

    foreach ($RequiredPath in @(
        $IniPath,
        (Join-Path $Root "Avvia_Manutenzione.bat"),
        (Join-Path $Root "docs\ABOUT.txt"),
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
        Get-ChildItem -LiteralPath $AppDir -Filter "*.ps1" -File -Recurse -ErrorAction SilentlyContinue
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
    Write-Host (T "SELFTEST_RESULT_ERRORS_WARNINGS" @($Errors, $Warnings))
    Write-Host "============================================================"

    if ($Errors -gt 0) {
        Write-Host (T "SELFTEST_DUCK_ERROR") -ForegroundColor Red
    }
    elseif ($Warnings -gt 0) {
        Write-Host (T "SELFTEST_DUCK_WARN") -ForegroundColor Yellow
    }
    else {
        Write-Host (T "SELFTEST_DUCK_OK") -ForegroundColor Green
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
    Write-Host (" {0}: {1} ({2})" -f (T "MENU_LANGUAGE"), (T "LANGUAGE_NAME"), $CurrentLanguage)
    Write-Host "============================================================"
    Write-Host ""

    foreach ($Module in $Catalog) {
        $Enabled = Get-IniBool $Config "Modules" $Module.Key $false
        $Flag = if ($Enabled) { T "MODE_AUTOMATIC" } else { T "MODE_MANUAL" }

        Write-Host ("[{0,2}] [{1,-9}] {2}" -f $Module.Id, $Flag, $Module.Name)
    }

    Write-Host ""
    if ([bool]$MT4Settings.NetworkDiagnostics.Enabled) {
        Write-Host ("[N] {0}" -f (T "MENU_NETWORK_DIAGNOSTICS"))
    }
    Write-Host ("[A] {0}" -f (T "MENU_RUN_AUTOMATIC"))
    Write-Host ("[C] {0}" -f (T "MENU_OPEN_CONFIG"))
    Write-Host ("[L] {0}" -f (T "MENU_OPEN_LOGS"))
    Write-Host ("[T] {0}" -f (T "MENU_SELFTEST"))
    Write-Host ("[U] {0}" -f (T "MENU_CHECK_UPDATES"))
    Write-Host ("[I] {0}" -f (T "MENU_INFO"))
    Write-Host ("[Q] {0}" -f (T "MENU_EXIT"))
    Write-Host ""
}

function Show-NetworkDiagnosticsMenu {
    Clear-Host
    Write-Host "============================================================"
    Write-Host (" {0}" -f (T "NETWORK_MENU_TITLE"))
    Write-Host (" {0}: {1} ({2})" -f (T "MENU_LANGUAGE"), (T "LANGUAGE_NAME"), $CurrentLanguage)
    Write-Host "============================================================"
    Write-Host ""
    Write-Host ("[1] {0}" -f (T "NETWORK_QUICK_DIAGNOSIS"))
    Write-Host ("[2] {0}" -f (T "NETWORK_TECHNICAL_REPORT"))
    Write-Host ("[3] {0}" -f (T "NETWORK_QUICK_DIAGNOSIS_SPEEDTEST"))
    Write-Host ("[4] {0}" -f (T "NETWORK_TECHNICAL_REPORT_SPEEDTEST"))
    Write-Host ""
    Write-Host ("[0] {0}" -f (T "NETWORK_MENU_RETURN"))
    Write-Host ""
}

function Invoke-MTNetworkDiagnosticsMenu {
    while ($true) {
        Show-NetworkDiagnosticsMenu
        $NetworkChoice = Read-Host (T "MENU_SELECTION")

        switch ($NetworkChoice) {
            "1" {
                $null = Invoke-MTNetworkQuickDiagnosis `
                    -ProjectRoot $Root `
                    -LanguageData $LanguageData

                Write-Host ""
                Write-Host (T "MENU_PRESS_ENTER")
                [void](Read-Host)
            }

            "2" {
                Clear-Host
                Write-Host (T "NETWORK_REPORT_GENERATING") -ForegroundColor Cyan
                Write-Host ""

                try {
                    $ReportResult = Invoke-MTNetworkTechnicalReport `
                        -ProjectRoot $Root `
                        -LanguageData $LanguageData `
                        -Version $Version

                    if ($ReportResult.Succeeded) {
                        Write-Host (
                            "[OK] {0}: {1}" -f
                            (T "NETWORK_REPORT_SAVED"),
                            $ReportResult.ReportPath
                        ) -ForegroundColor Green

                        if ($ReportResult.TopologyPath) {
                            Write-Host (
                                "[OK] {0}: {1}" -f
                                (T "NETWORK_TOPOLOGY_SAVED"),
                                $ReportResult.TopologyPath
                            ) -ForegroundColor Green
                        }

                        if ($ReportResult.RulesPath) {
                            Write-Host (
                                "[OK] {0}: {1}" -f
                                (T "NETWORK_RULES_SAVED"),
                                $ReportResult.RulesPath
                            ) -ForegroundColor Green
                        }
                    }
                    else {
                        Write-Host (
                            "[WARN] {0}: {1}" -f
                            (T "NETWORK_REPORT_SAVED"),
                            $ReportResult.ReportPath
                        ) -ForegroundColor Yellow
                    }
                }
                catch {
                    Write-Host (
                        "[ERROR] {0}: {1}" -f `
                        (T "NETWORK_REPORT_FAILED"),
                        $_.Exception.Message
                    ) -ForegroundColor Red

                    if (
                        $null -ne $_.InvocationInfo -and
                        -not [string]::IsNullOrWhiteSpace(
                            [string]$_.InvocationInfo.PositionMessage
                        )
                    ) {
                        Write-Host $_.InvocationInfo.PositionMessage -ForegroundColor DarkGray
                    }
                }

                Write-Host ""
                Write-Host (T "MENU_PRESS_ENTER")
                [void](Read-Host)
            }

            "3" {
                $null = Invoke-MTNetworkQuickDiagnosis `
                    -ProjectRoot $Root `
                    -LanguageData $LanguageData `
                    -SpeedTest

                Write-Host ""
                Write-Host (T "MENU_PRESS_ENTER")
                [void](Read-Host)
            }

            "4" {
                Clear-Host
                Write-Host (T "NETWORK_REPORT_GENERATING") -ForegroundColor Cyan
                Write-Host ""

                try {
                    $ReportResult = Invoke-MTNetworkTechnicalReport `
                        -ProjectRoot $Root `
                        -LanguageData $LanguageData `
                        -Version $Version `
                        -SpeedTest `
                        -OptionCode 'N4' `
                        -ReportType 'Technical-SpeedTest'

                    if ($ReportResult.Succeeded) {
                        Write-Host (
                            "[OK] {0}: {1}" -f
                            (T "NETWORK_REPORT_SAVED"),
                            $ReportResult.ReportPath
                        ) -ForegroundColor Green

                        if ($ReportResult.TopologyPath) {
                            Write-Host (
                                "[OK] {0}: {1}" -f
                                (T "NETWORK_TOPOLOGY_SAVED"),
                                $ReportResult.TopologyPath
                            ) -ForegroundColor Green
                        }

                        if ($ReportResult.RulesPath) {
                            Write-Host (
                                "[OK] {0}: {1}" -f
                                (T "NETWORK_RULES_SAVED"),
                                $ReportResult.RulesPath
                            ) -ForegroundColor Green
                        }

                        if ($ReportResult.SpeedTestPath) {
                            Write-Host (
                                "[OK] {0}: {1}" -f
                                (T "NETWORK_SPEEDTEST_SAVED"),
                                $ReportResult.SpeedTestPath
                            ) -ForegroundColor Green
                        }
                        elseif (
                            $null -ne $ReportResult.SpeedTest -and
                            $ReportResult.SpeedTest.Status -eq 'WARN'
                        ) {
                            Write-Host (
                                "[WARN] {0}" -f
                                $ReportResult.SpeedTest.ErrorMessage
                            ) -ForegroundColor Yellow
                        }
                    }
                }
                catch {
                    Write-Host (
                        "[ERROR] {0}: {1}" -f `
                        (T "NETWORK_REPORT_FAILED"),
                        $_.Exception.Message
                    ) -ForegroundColor Red

                    if (
                        $null -ne $_.InvocationInfo -and
                        -not [string]::IsNullOrWhiteSpace(
                            [string]$_.InvocationInfo.PositionMessage
                        )
                    ) {
                        Write-Host $_.InvocationInfo.PositionMessage -ForegroundColor DarkGray
                    }
                }

                Write-Host ""
                Write-Host (T "MENU_PRESS_ENTER")
                [void](Read-Host)
            }

            "0" {
                return
            }
        }
    }
}

function Select-Modules {
    while ($true) {
        Show-Menu
        $Choice = Read-Host (T "MENU_SELECTION")

        if ($Choice -match '^[Qq]$') {
            return $null
        }

        if ($Choice -match '^[Nn]$') {
            if ([bool]$MT4Settings.NetworkDiagnostics.Enabled) {
                Invoke-MTNetworkDiagnosticsMenu
            }
            continue
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
            Write-Host (T "MENU_PRESS_ENTER")
            [void](Read-Host)
            continue
        }

        if ($Choice -match '^[Uu]$') {
            Clear-Host
            $null = Invoke-MTUpdateCheck
            Write-Host ""
            Write-Host (T "MENU_PRESS_ENTER")
            [void](Read-Host)
            continue
        }

if ($Choice -match '^[Ii]$') {
    Clear-Host
    Write-Host "============================================================"
    Write-Host " Maintenance Toolkit $Version"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host ("{0}:" -f (T "INFO_AUTHOR"))
    Write-Host "    Luca Miselli"
    Write-Host "    https://www.kraugh.it"
    Write-Host ""
    Write-Host (T "INFO_DEVELOPED_WITH")
    Write-Host (T "INFO_DUCK")
    Write-Host ""
    Write-Host (T "INFO_THANKS")
    Write-Host ""
    Write-Host (T "MENU_PRESS_ENTER")
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
    Write-Main ("MAINTENANCE TOOLKIT {0} - {1} {2}" -f $Version, (T "SESSION_LABEL"), $SessionId)
    Write-Main ("{0}: {1}" -f (T "SESSION_COMPUTER"), $env:COMPUTERNAME)
    Write-Main ("{0}: {1}" -f (T "SESSION_USER"), $env:USERNAME)
    Write-Main ("{0}:" -f (T "SESSION_SELECTED_MODULES"))

    foreach ($SelectedModule in $Selected) {
        Write-Main " - $($SelectedModule.Name)"
    }

    Write-Main "============================================================"

    foreach ($Module in $Selected) {
        Remove-Item $env:MT_RESULT -Force -ErrorAction SilentlyContinue
        $ModuleStart = Get-Date

        Write-Main ("{0}: {1}" -f (T "SESSION_START_MODULE"), $Module.Name)

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
            Module = $Module.Name
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
        ("{0}:" -f (T "INFO_AUTHOR")),
        "    Luca Miselli",
        "    https://www.kraugh.it",
        "",
        (T "INFO_DEVELOPED_WITH"),
        (T "INFO_DUCK"),
        "",
        (T "INFO_THANKS"),
        "",
        "============================================================"
    )

    $Lines = @(
        "MAINTENANCE TOOLKIT $Version",
        ("{0}: {1}" -f (T "SESSION_LABEL"), $SessionId),
        ("{0}: {1}" -f (T "SESSION_COMPUTER"), $env:COMPUTERNAME),
        ("{0}: {1}" -f (T "SESSION_START"), $Start.ToString('yyyy-MM-dd HH:mm:ss')),
        ("{0}: {1}" -f (T "SESSION_END"), $End.ToString('yyyy-MM-dd HH:mm:ss')),
        ("{0}: {1}" -f (T "SESSION_DURATION"), ($End-$Start).ToString('hh\:mm\:ss')),
        "",
        ("{0,-30} {1,-9} {2,-10} {3}" -f (T "TABLE_MODULE"), (T "TABLE_STATUS"), (T "TABLE_DURATION"), (T "TABLE_DETAIL")),
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
        ("{0}: {1}" -f (T "SESSION_ERRORS"), $Errors),
        ("{0}: {1}" -f (T "SESSION_WARNINGS"), $Warnings),
        ("{0}: {1}" -f (T "SESSION_REBOOT_REQUIRED"), $(if($Reboot){T "YES"}else{T "NO"})),
        ("{0}: {1}" -f (T "SESSION_AUTO_REBOOT"), (T "NEVER")),
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
<html lang="$CurrentLanguage">
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
<b>$(T "SESSION_COMPUTER"):</b> $env:COMPUTERNAME<br>
<b>$(T "SESSION_LABEL"):</b> $SessionId<br>
<b>$(T "SESSION_DURATION"):</b> $(($End-$Start).ToString('hh\:mm\:ss'))<br>
<b>$(T "SESSION_REBOOT_REQUIRED"):</b> $(if($Reboot){T "YES"}else{T "NO"})<br>
<b>$(T "SESSION_AUTO_REBOOT"):</b> $(T "NEVER")
</p>
<table>
<thead>
<tr><th>$(T "TABLE_MODULE")</th><th>$(T "TABLE_STATUS")</th><th>$(T "TABLE_DURATION")</th><th>$(T "TABLE_DETAIL")</th></tr>
</thead>
<tbody>
$($Rows -join "`n")
</tbody>
</table>
<footer>
<strong>Maintenance Toolkit $Version</strong><br>
$(T "INFO_AUTHOR"): Luca Miselli —
<a href="https://www.kraugh.it">www.kraugh.it</a><br>
$(T "INFO_DEVELOPED_WITH") $(T "INFO_DUCK")<br>
$(T "INFO_THANKS")
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
    Write-Host (T "SESSION_QUICK_SUMMARY")
    Write-Host "============================================================"
    Write-Host ""
    Write-Host ("{0}:" -f (T "SESSION_EXECUTED"))

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
    Write-Host ("{0}:" -f (T "SESSION_NOT_EXECUTED"))
    if ($NotExecuted.Count -eq 0) { Write-Host ("  {0}" -f (T "SESSION_NONE")) }
    else { foreach ($Missing in $NotExecuted) { Write-Host "  [ ] $($Missing.Name)" } }

    Write-Host ""
    Write-Host ("{0}: {1}" -f (T "SESSION_ERRORS"), $Errors)
    Write-Host ("{0}: {1}" -f (T "SESSION_WARNINGS"), $Warnings)
    Write-Host ("{0}: {1}" -f (T "SESSION_REBOOT_REQUIRED"), $(if($Reboot){T "YES"}else{T "NO"}))
    Write-Host ("{0}: {1}" -f (T "SESSION_DURATION"), ($End-$Start).ToString('hh\:mm\:ss'))
    Write-Host "============================================================"

    Write-Main ("{0}: {1}" -f (T "SESSION_TXT_SUMMARY"), $Txt)
    Write-Main ("{0}: {1}" -f (T "SESSION_HTML_SUMMARY"), $Html)

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
    Write-Host ("[M] {0}" -f (T "MENU_RETURN"))
    Write-Host ("[Q] {0}" -f (T "MENU_EXIT"))
    Write-Host "============================================================"
    Write-Host ""

    while ($true) {
        $NextAction = Read-Host (T "MENU_SELECTION")

        if ($NextAction -match '^[Mm]$') {
            break
        }

        if ($NextAction -match '^[Qq]$') {
            exit 0
        }
    }
}
