###############################################################################
# Maintenance Toolkit 3.0.6.2 - Modulo Microsoft Update
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

try {
    $MicrosoftUpdateServiceId = "7971f918-a847-4430-9279-4a52d1efe18d"

    Write-Main "Microsoft Update: apertura Windows Update Agent."

    $ServiceManager = New-Object -ComObject Microsoft.Update.ServiceManager
    $ServiceManager.ClientApplicationID = "Maintenance Toolkit 3.0.6.2"

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
    $UpdateSession.ClientApplicationID = "Maintenance Toolkit 3.0.6.2"

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
    $SearchResult = $UpdateSearcher.Search($Criteria)
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
    $DownloadResult = $UpdateDownloader.Download()
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
    $InstallResult = $UpdateInstaller.Install()
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
            Write-ErrorLog (
                "INSTALLAZIONE FALLITA: {0} - {1} - {2}" -f
                $Update.Title,
                (Get-WuaResultText $ItemResult.ResultCode),
                $HResultText
            ) $Module
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
