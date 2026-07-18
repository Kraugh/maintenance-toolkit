###############################################################################
# Maintenance Toolkit 3.0.6.2 - Modulo Winget
###############################################################################

. "$PSScriptRoot\00_common.ps1"

$Config = Read-IniFile $env:MT_INI
$Module = "WINGET"
$ErrorActionPreference = "Stop"

function Get-WingetCommand {
    return Get-Command winget.exe -ErrorAction SilentlyContinue
}

function Invoke-WingetUpgradePass {
    param(
        [int]$Pass,
        [string]$WingetPath,
        [string[]]$Arguments
    )

    $RawLog = Join-Path $env:MT_SESSION_DIR ("winget_passaggio_{0}.txt" -f $Pass)

    Write-Main "Winget: avvio passaggio $Pass."

    $Output = & $WingetPath @Arguments 2>&1
    $ExitCode = $LASTEXITCODE

    $Output | Set-Content -LiteralPath $RawLog -Encoding UTF8

    foreach ($Line in $Output) {
        $Text = [string]$Line

        # Evita di riversare nel log principale le righe puramente grafiche
        # delle barre di avanzamento.
        if ([string]::IsNullOrWhiteSpace($Text)) {
            continue
        }

        if ($Text -match '^[\s\-\|/\\█▓▒░\.]+$') {
            continue
        }

        Add-Log "OUTPUT" $Text $Module
    }

    return $ExitCode
}

try {
    $Winget = Get-WingetCommand

    if (-not $Winget) {
        throw "winget.exe non trovato nel PATH."
    }

    $BeforePath = Join-Path $env:MT_SESSION_DIR "winget_prima.txt"
    $AfterPath = Join-Path $env:MT_SESSION_DIR "winget_dopo.txt"

    Write-Main "Winget: acquisizione aggiornamenti disponibili."

    & $Winget.Source upgrade `
        --accept-source-agreements `
        --disable-interactivity 2>&1 |
        Set-Content -LiteralPath $BeforePath -Encoding UTF8

    Write-Main "Winget: aggiornamento sorgenti."

    $SourceResult = Invoke-LoggedProcess `
        -FilePath $Winget.Source `
        -ArgumentList @("source", "update", "--disable-interactivity") `
        -Label "Winget source update" `
        -Module $Module `
        -OutputEncoding "UTF8" `
        -CopyOutputToMainLog $false

    if ($SourceResult -ne 0) {
        Write-WarnLog "Winget source update ha restituito $SourceResult; proseguo comunque." $Module
    }

    $Arguments = @(
        "upgrade",
        "--all",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--disable-interactivity"
    )

    if (Get-IniBool $Config "Winget" "Silent" $true) {
        $Arguments += "--silent"
    }

    if (Get-IniBool $Config "Winget" "IncludeUnknown" $true) {
        $Arguments += "--include-unknown"
    }

    $FirstResult = Invoke-WingetUpgradePass `
        -Pass 1 `
        -WingetPath $Winget.Source `
        -Arguments $Arguments

    $FinalResult = $FirstResult
    $SecondPassUsed = $false

    if ($FirstResult -ne 0) {
        $WaitSeconds = [int](Get-IniValue `
            $Config `
            "Winget" `
            "RetryAfterSelfUpdateSeconds" `
            12
        )

        Write-WarnLog `
            "Il primo passaggio Winget ha restituito $FirstResult. Attendo $WaitSeconds secondi e riprovo, nel caso Winget abbia aggiornato sé stesso." `
            $Module

        Start-Sleep -Seconds $WaitSeconds

        $Winget = Get-WingetCommand

        if (-not $Winget) {
            throw "winget.exe non disponibile dopo il primo passaggio."
        }

        $SecondPassUsed = $true
        $FinalResult = Invoke-WingetUpgradePass `
            -Pass 2 `
            -WingetPath $Winget.Source `
            -Arguments $Arguments
    }

    & $Winget.Source upgrade `
        --accept-source-agreements `
        --disable-interactivity 2>&1 |
        Set-Content -LiteralPath $AfterPath -Encoding UTF8

    if ($FinalResult -eq 0) {
        $Detail = if ($SecondPassUsed) {
            "Completato al secondo passaggio dopo aggiornamento di Winget/App Installer"
        }
        else {
            "Completato al primo passaggio"
        }

        Write-Ok "Winget completato correttamente." $Module
        Set-ModuleResult "Aggiornamenti Winget" "OK" $Detail
        exit 0
    }

    $Detail = "Winget non completato. Primo codice: $FirstResult; codice finale: $FinalResult"
    Write-ErrorLog $Detail $Module
    Set-ModuleResult "Aggiornamenti Winget" "ERROR" $Detail
    exit 1
}
catch {
    Write-ErrorLog $_.Exception.Message $Module
    Write-ErrorLog $_.InvocationInfo.PositionMessage $Module
    Set-ModuleResult "Aggiornamenti Winget" "ERROR" $_.Exception.Message
    exit 1
}
