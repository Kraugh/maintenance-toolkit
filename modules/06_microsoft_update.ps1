###############################################################################
# Maintenance Toolkit 3.7.2-rc.6 - Modulo Microsoft Update
###############################################################################

. "$PSScriptRoot\00_common.ps1"

$Config = Read-IniFile $env:MT_INI
$Module = "MSUPDATE"
$ErrorActionPreference = "Stop"

function Get-WuaResultText {
    param([int]$Code)

    switch ($Code) {
        0 { "Non avviato" }
        1 { "In corso" }
        2 { "Completato" }
        3 { "Completato con errori" }
        4 { "Fallito" }
        5 { "Interrotto" }
        default { "Codice sconosciuto $Code" }
    }
}


function Start-MicrosoftUpdateHeartbeat {
    param(
        [string]$Phase,
        [int]$IntervalSeconds = 1
    )

    $Identifier = "{0}_{1}" -f `
        ($Phase -replace '[^A-Za-z0-9_-]', '_'),
        [guid]::NewGuid().ToString("N")

    $SignalPath = Join-Path $env:MT_SESSION_DIR (
        "msupdate_{0}.running" -f $Identifier
    )
    $ScriptPath = Join-Path $env:MT_SESSION_DIR (
        "msupdate_{0}_status.ps1" -f $Identifier
    )

    Set-Content -LiteralPath $SignalPath -Value "running" -Encoding ASCII

    $StatusScript = @'
param(
    [Parameter(Mandatory = $true)]
    [string]$SignalPath,

    [Parameter(Mandatory = $true)]
    [string]$Phase,

    [int]$IntervalSeconds = 1
)

$Started = Get-Date
$Frames = @("|", "/", "-", "\")
$Index = 0
$LastLength = 0
$DinnerShown = $false
$WaterShown = $false

try {
    while (Test-Path -LiteralPath $SignalPath) {
        $Elapsed = (Get-Date) - $Started
        $Frame = $Frames[$Index % $Frames.Count]
        $Text = "Microsoft Update - {0}  {1}  {2}" -f `
            $Phase,
            $Frame,
            $Elapsed.ToString("hh\:mm\:ss")

        $Width = [Math]::Max($LastLength, $Text.Length)
        [Console]::Write(
            [char]13 + $Text.PadRight($Width)
        )

        $LastLength = $Width
        $Index++

        if (-not $DinnerShown -and $Elapsed.TotalMinutes -ge 30) {
            [Console]::Write(
                [char]13 + (" " * $LastLength) + [char]13
            )
            [Console]::WriteLine()
            [Console]::ForegroundColor = [ConsoleColor]::DarkYellow
            [Console]::WriteLine(
                "Suggerimento: questa operazione è in corso da 30 minuti. " +
                "Se qualcuno ti sta aspettando per cena, forse è il momento di avvisarlo."
            )
            [Console]::ResetColor()
            [Console]::WriteLine()

            $LastLength = 0
            $DinnerShown = $true
        }

        if (-not $WaterShown -and $Elapsed.TotalHours -ge 1) {
            [Console]::Write(
                [char]13 + (" " * $LastLength) + [char]13
            )
            [Console]::WriteLine()
            [Console]::ForegroundColor = [ConsoleColor]::DarkYellow
            [Console]::WriteLine(
                "È trascorsa un'ora. " +
                "Questo è un buon momento per bere un bicchiere d'acqua."
            )
            [Console]::ResetColor()
            [Console]::WriteLine()

            $LastLength = 0
            $WaterShown = $true
        }

        Start-Sleep -Seconds $IntervalSeconds
    }
}
finally {
    if ($LastLength -gt 0) {
        [Console]::Write(
            [char]13 + (" " * $LastLength) + [char]13
        )
    }
}
'@

    Set-Content `
        -LiteralPath $ScriptPath `
        -Value $StatusScript `
        -Encoding UTF8

    $Process = Start-Process `
        -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", ('"{0}"' -f $ScriptPath),
            "-SignalPath", ('"{0}"' -f $SignalPath),
            "-Phase", ('"{0}"' -f $Phase),
            "-IntervalSeconds", $IntervalSeconds
        ) `
        -PassThru `
        -NoNewWindow

    return [pscustomobject]@{
        SignalPath = $SignalPath
        ScriptPath = $ScriptPath
        Process = $Process
        Started = Get-Date
        Phase = $Phase
    }
}

function Stop-MicrosoftUpdateHeartbeat {
    param($Heartbeat)

    if ($null -eq $Heartbeat) {
        return
    }

    Remove-Item `
        -LiteralPath $Heartbeat.SignalPath `
        -Force `
        -ErrorAction SilentlyContinue

    if ($Heartbeat.Process) {
        $Heartbeat.Process.WaitForExit(5000) | Out-Null

        if (-not $Heartbeat.Process.HasExited) {
            Stop-Process `
                -Id $Heartbeat.Process.Id `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }

    Remove-Item `
        -LiteralPath $Heartbeat.ScriptPath `
        -Force `
        -ErrorAction SilentlyContinue

    Write-Host ""

    $Elapsed = (Get-Date) - $Heartbeat.Started
    Add-Log "INFO" (
        "Microsoft Update - {0} terminato dopo {1}" -f
        $Heartbeat.Phase,
        $Elapsed.ToString("hh\:mm\:ss")
    ) $Module
}

function Get-WuaHResultExplanation {
    param([string]$HResultText)

    switch ($HResultText.ToUpperInvariant()) {
        "0X80240016" {
            "Installazione non consentita: è già in corso un'altra installazione oppure il computer deve essere riavviato."
        }
        default {
            $null
        }
    }
}

try {
    $MicrosoftUpdateServiceId = "7971f918-a847-4430-9279-4a52d1efe18d"

    Write-Main "Microsoft Update: apertura Windows Update Agent."

    $ServiceManager = New-Object -ComObject Microsoft.Update.ServiceManager
    $ServiceManager.ClientApplicationID = "Maintenance Toolkit 3.7.2-rc.6"

    $ServicePresent = @(
        $ServiceManager.Services |
        Where-Object ServiceID -eq $MicrosoftUpdateServiceId
    ).Count -gt 0

    if (-not $ServicePresent) {
        Write-Main "Microsoft Update: registrazione del servizio Microsoft Update."
        $null = $ServiceManager.AddService2(
            $MicrosoftUpdateServiceId,
            7,
            ""
        )
    }
    else {
        Write-Main "Microsoft Update: servizio già registrato."
    }

    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    $UpdateSession.ClientApplicationID = "Maintenance Toolkit 3.7.2-rc.6"

    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
    $UpdateSearcher.ServerSelection = 3
    $UpdateSearcher.ServiceID = $MicrosoftUpdateServiceId

    $SearchTypes = @()

    if (Get-IniBool $Config "MicrosoftUpdate" "IncludeSoftware" $true) {
        $SearchTypes += "Type='Software'"
    }

    if (Get-IniBool $Config "MicrosoftUpdate" "IncludeDrivers" $false) {
        $SearchTypes += "Type='Driver'"
    }

    if ($SearchTypes.Count -eq 0) {
        Write-Skip "Microsoft Update: software e driver disabilitati." $Module
        Set-ModuleResult "Microsoft Update" "SKIP" "Software e driver disabilitati"
        exit 10
    }

    $TypeClause = if ($SearchTypes.Count -eq 1) {
        $SearchTypes[0]
    }
    else {
        "(" + ($SearchTypes -join " or ") + ")"
    }

    $Criteria = "IsInstalled=0 and IsHidden=0 and $TypeClause"

    Write-Main "Microsoft Update: ricerca aggiornamenti in corso."
    Add-Log "INFO" "Criterio di ricerca: $Criteria" $Module

    $SearchStarted = Get-Date
    $SearchHeartbeat = Start-MicrosoftUpdateHeartbeat -Phase "ricerca"

    try {
        $SearchResult = $UpdateSearcher.Search($Criteria)
    }
    finally {
        Stop-MicrosoftUpdateHeartbeat $SearchHeartbeat
    }

    $SearchDuration = (Get-Date) - $SearchStarted

    Write-Main (
        "Microsoft Update: ricerca terminata in {0}. Aggiornamenti trovati: {1}." -f
        $SearchDuration.ToString("hh\:mm\:ss"),
        $SearchResult.Updates.Count
    )

    if ($SearchResult.Updates.Count -eq 0) {
        Write-Ok "Nessun aggiornamento Microsoft disponibile." $Module
        Set-ModuleResult "Microsoft Update" "OK" "Sistema aggiornato"
        exit 0
    }

    $UpdatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
    $EulaFailures = 0

    foreach ($Update in $SearchResult.Updates) {
        Add-Log "INFO" "DISPONIBILE: $($Update.Title)" $Module

        if (-not $Update.EulaAccepted) {
            try {
                $Update.AcceptEula()
            }
            catch {
                $EulaFailures++
                Write-ErrorLog (
                    "EULA non accettabile: {0} - {1}" -f
                    $Update.Title,
                    $_.Exception.Message
                ) $Module
                continue
            }
        }

        [void]$UpdatesToDownload.Add($Update)
    }

    if ($UpdatesToDownload.Count -eq 0) {
        throw "Nessun aggiornamento selezionabile dopo il controllo delle licenze."
    }

    Write-Main (
        "Microsoft Update: download di {0} aggiornamenti." -f
        $UpdatesToDownload.Count
    )

    $DownloadStarted = Get-Date
    $UpdateDownloader = $UpdateSession.CreateUpdateDownloader()
    $UpdateDownloader.Updates = $UpdatesToDownload

    Write-Main "Microsoft Update: il download può richiedere molto tempo. Il Toolkit mostrerà periodicamente il proprio stato."
    $DownloadHeartbeat = Start-MicrosoftUpdateHeartbeat -Phase "download"

    try {
        $DownloadResult = $UpdateDownloader.Download()
    }
    finally {
        Stop-MicrosoftUpdateHeartbeat $DownloadHeartbeat
    }

    $DownloadDuration = (Get-Date) - $DownloadStarted

    Write-Main (
        "Microsoft Update: download terminato in {0}. Risultato: {1}." -f
        $DownloadDuration.ToString("hh\:mm\:ss"),
        (Get-WuaResultText $DownloadResult.ResultCode)
    )

    $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
    $DownloadFailures = 0

    for ($DownloadIndex = 0; $DownloadIndex -lt $UpdatesToDownload.Count; $DownloadIndex++) {
        $Update = $UpdatesToDownload.Item($DownloadIndex)
        $ItemResult = $DownloadResult.GetUpdateResult($DownloadIndex)
        $HResultText = "0x{0:X8}" -f ($ItemResult.HResult -band 0xffffffff)

        if ($Update.IsDownloaded) {
            [void]$UpdatesToInstall.Add($Update)
            Write-Ok "SCARICATO: $($Update.Title)" $Module
        }
        else {
            $DownloadFailures++
            Write-ErrorLog (
                "DOWNLOAD FALLITO: {0} - {1} - {2}" -f
                $Update.Title,
                (Get-WuaResultText $ItemResult.ResultCode),
                $HResultText
            ) $Module
        }
    }

    if ($UpdatesToInstall.Count -eq 0) {
        throw "Nessun aggiornamento Microsoft scaricato correttamente."
    }

    Write-Main (
        "Microsoft Update: installazione di {0} aggiornamenti." -f
        $UpdatesToInstall.Count
    )

    $InstallStarted = Get-Date
    $UpdateInstaller = $UpdateSession.CreateUpdateInstaller()
    $UpdateInstaller.Updates = $UpdatesToInstall

    # Install() non esegue autonomamente il riavvio.
    Write-Main "Microsoft Update: l'installazione può richiedere molto tempo. Il Toolkit mostrerà periodicamente il proprio stato."
    $InstallHeartbeat = Start-MicrosoftUpdateHeartbeat -Phase "installazione"

    try {
        $InstallResult = $UpdateInstaller.Install()
    }
    finally {
        Stop-MicrosoftUpdateHeartbeat $InstallHeartbeat
    }

    $InstallDuration = (Get-Date) - $InstallStarted

    Write-Main (
        "Microsoft Update: installazione terminata in {0}. Risultato: {1}." -f
        $InstallDuration.ToString("hh\:mm\:ss"),
        (Get-WuaResultText $InstallResult.ResultCode)
    )

    $InstalledCount = 0
    $InstallFailures = 0

    for ($InstallIndex = 0; $InstallIndex -lt $UpdatesToInstall.Count; $InstallIndex++) {
        $Update = $UpdatesToInstall.Item($InstallIndex)
        $ItemResult = $InstallResult.GetUpdateResult($InstallIndex)
        $HResultText = "0x{0:X8}" -f ($ItemResult.HResult -band 0xffffffff)

        if ($ItemResult.ResultCode -eq 2) {
            $InstalledCount++
            Write-Ok "INSTALLATO: $($Update.Title) - $HResultText" $Module
        }
        else {
            $InstallFailures++
            $Explanation = Get-WuaHResultExplanation $HResultText

            Write-ErrorLog (
                "INSTALLAZIONE FALLITA: {0} - {1} - {2}" -f
                $Update.Title,
                (Get-WuaResultText $ItemResult.ResultCode),
                $HResultText
            ) $Module

            if ($Explanation) {
                Write-WarnLog $Explanation $Module
            }
        }
    }

    $RebootRequired = [bool]$InstallResult.RebootRequired

    if ($RebootRequired) {
        Write-WarnLog `
            "Riavvio necessario. Il toolkit non eseguirà alcun riavvio automatico." `
            $Module
    }
    else {
        Write-Ok "Nessun riavvio richiesto." $Module
    }

    if ($EulaFailures -gt 0 -or $DownloadFailures -gt 0 -or $InstallFailures -gt 0) {
        $Detail = (
            "Installati {0}; EULA fallite {1}; download falliti {2}; installazioni fallite {3}" -f
            $InstalledCount,
            $EulaFailures,
            $DownloadFailures,
            $InstallFailures
        )

        Set-ModuleResult `
            "Microsoft Update" `
            "ERROR" `
            $Detail `
            $RebootRequired

        exit 1
    }

    $Detail = "Installati $InstalledCount aggiornamenti Microsoft"

    if ($RebootRequired) {
        Set-ModuleResult `
            "Microsoft Update" `
            "WARN" `
            "$Detail; riavvio richiesto" `
            $true

        exit 20
    }

    Set-ModuleResult `
        "Microsoft Update" `
        "OK" `
        $Detail `
        $false

    exit 0
}
catch {
    Write-ErrorLog $_.Exception.Message $Module
    Write-ErrorLog $_.InvocationInfo.PositionMessage $Module

    Set-ModuleResult `
        "Microsoft Update" `
        "ERROR" `
        $_.Exception.Message `
        $false

    exit 1
}
