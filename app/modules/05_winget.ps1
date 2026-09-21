###############################################################################
# Maintenance Toolkit 4.0.3-dev.4 - Winget module
###############################################################################

. "$PSScriptRoot\00_common.ps1"

$Config = Read-IniFile $env:MT_INI
$Module = "WINGET"
$ErrorActionPreference = "Stop"

function Get-WingetCommand {
    return Get-Command winget.exe -ErrorAction SilentlyContinue
}

function Get-WingetTimeoutSeconds {
    param(
        [string]$Key,
        [int]$DefaultMinutes
    )

    $Minutes = [int](Get-IniValue $Config "Winget" $Key $DefaultMinutes)
    if ($Minutes -lt 1) {
        $Minutes = $DefaultMinutes
    }

    return ($Minutes * 60)
}

function Save-WingetSnapshot {
    param(
        [string]$WingetPath,
        [string]$DestinationPath,
        [int]$TimeoutSeconds
    )

    $Run = Invoke-LoggedProcessWithHeartbeat `
        -FilePath $WingetPath `
        -ArgumentList @(
            "upgrade",
            "--accept-source-agreements",
            "--disable-interactivity"
        ) `
        -Label (Get-MTRuntimeText "WINGET_SNAPSHOT_LABEL") `
        -Module $Module `
        -SuccessCodes @(0) `
        -HeartbeatSeconds 0 `
        -OutputEncoding "UTF8" `
        -ShowProgressOutput $false `
        -TimeoutSeconds $TimeoutSeconds

    $CombinedOutput = @()
    foreach ($File in @($Run.OutputPath, $Run.ErrorPath)) {
        $CombinedOutput += Read-ProcessOutput -Path $File -Encoding "UTF8"
    }
    $CombinedOutput | Set-Content -LiteralPath $DestinationPath -Encoding UTF8

    return $Run
}

function Invoke-WingetUpgradePass {
    param(
        [int]$Pass,
        [string]$WingetPath,
        [string[]]$Arguments,
        [int]$TimeoutSeconds
    )

    $RawLog = Join-Path $env:MT_SESSION_DIR (
        Get-MTRuntimeText "WINGET_PASS_FILE" @($Pass)
    )

    Write-Main (Get-MTRuntimeText "WINGET_PASS_START" @($Pass))
    Write-Main ""
    Write-Main (Get-MTRuntimeText "WINGET_INSTALLING")
    Write-Main (Get-MTRuntimeText "WINGET_MAY_TAKE_TIME")
    Write-Main (Get-MTRuntimeText "WINGET_WINDOWS_NOTICE")
    Write-Main (Get-MTRuntimeText "WINGET_RESUME_NOTICE")
    Write-Main ""

    $Run = Invoke-LoggedProcessWithHeartbeat `
        -FilePath $WingetPath `
        -ArgumentList $Arguments `
        -Label (Get-MTRuntimeText "WINGET_PASS_LABEL" @($Pass)) `
        -Module $Module `
        -SuccessCodes @(0) `
        -HeartbeatSeconds 60 `
        -OutputEncoding "UTF8" `
        -ShowProgressOutput $true `
        -TimeoutSeconds $TimeoutSeconds

    $CombinedOutput = @()
    foreach ($File in @($Run.OutputPath, $Run.ErrorPath)) {
        $CombinedOutput += Read-ProcessOutput -Path $File -Encoding "UTF8"
    }
    $CombinedOutput | Set-Content -LiteralPath $RawLog -Encoding UTF8

    return $Run
}

try {
    $Winget = Get-WingetCommand

    if (-not $Winget) {
        $UnavailableMessage = Get-MTRuntimeText "WINGET_NOT_FOUND"
        Write-Skip $UnavailableMessage $Module
        Set-ModuleResult `
            (Get-MTRuntimeText "MODULE_WINGET") `
            "SKIP" `
            $UnavailableMessage
        exit 10
    }

    $SnapshotTimeoutSeconds = Get-WingetTimeoutSeconds `
        -Key "SnapshotTimeoutMinutes" `
        -DefaultMinutes 5
    $SourceTimeoutSeconds = Get-WingetTimeoutSeconds `
        -Key "SourceTimeoutMinutes" `
        -DefaultMinutes 5
    $PassTimeoutSeconds = Get-WingetTimeoutSeconds `
        -Key "PassTimeoutMinutes" `
        -DefaultMinutes 60

    $BeforePath = Join-Path $env:MT_SESSION_DIR "winget_prima.txt"
    $AfterPath = Join-Path $env:MT_SESSION_DIR "winget_dopo.txt"

    Write-Main (Get-MTRuntimeText "WINGET_GET_AVAILABLE")

    $BeforeRun = Save-WingetSnapshot `
        -WingetPath $Winget.Source `
        -DestinationPath $BeforePath `
        -TimeoutSeconds $SnapshotTimeoutSeconds

    if ($BeforeRun.TimedOut) {
        Write-WarnLog (Get-MTRuntimeText "WINGET_SNAPSHOT_TIMEOUT") $Module
    }

    Write-Main (Get-MTRuntimeText "WINGET_UPDATE_SOURCES")

    $SourceResult = Invoke-LoggedProcess `
        -FilePath $Winget.Source `
        -ArgumentList @("source", "update", "--disable-interactivity") `
        -Label (Get-MTRuntimeText "WINGET_SOURCE_LABEL") `
        -Module $Module `
        -OutputEncoding "UTF8" `
        -CopyOutputToMainLog $false `
        -TimeoutSeconds $SourceTimeoutSeconds

    if ($SourceResult -ne 0) {
        Write-WarnLog (
            Get-MTRuntimeText "WINGET_SOURCE_WARN" @($SourceResult)
        ) $Module
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

    # One bounded pass only. A generic retry after any non-zero exit code can
    # simply reproduce the same hung third-party installer unattended.
    $PassRun = Invoke-WingetUpgradePass `
        -Pass 1 `
        -WingetPath $Winget.Source `
        -Arguments $Arguments `
        -TimeoutSeconds $PassTimeoutSeconds

    $FinalResult = [int]$PassRun.ExitCode

    $AfterRun = Save-WingetSnapshot `
        -WingetPath $Winget.Source `
        -DestinationPath $AfterPath `
        -TimeoutSeconds $SnapshotTimeoutSeconds

    if ($AfterRun.TimedOut) {
        Write-WarnLog (Get-MTRuntimeText "WINGET_SNAPSHOT_TIMEOUT") $Module
    }

    if ($PassRun.TimedOut) {
        $Detail = Get-MTRuntimeText "WINGET_TIMEOUT_DETAIL" @(
            [int]($PassTimeoutSeconds / 60)
        )
        Write-WarnLog (Get-MTRuntimeText "WINGET_TIMEOUT_WARN") $Module
        Set-ModuleResult (Get-MTRuntimeText "MODULE_WINGET") "WARN" $Detail
        exit 20
    }

    if ($FinalResult -eq 0) {
        $Detail = Get-MTRuntimeText "WINGET_DETAIL_FIRST_PASS"
        Write-Ok (Get-MTRuntimeText "WINGET_COMPLETED") $Module
        Set-ModuleResult (Get-MTRuntimeText "MODULE_WINGET") "OK" $Detail
        exit 0
    }

    $FinalHex = "0x{0:X8}" -f ($FinalResult -band 0xffffffff)

    if ($FinalHex -eq "0x8A15002C") {
        $Detail = Get-MTRuntimeText "WINGET_PARTIAL_DETAIL" @(
            $FinalResult,
            $FinalHex
        )

        Write-WarnLog (Get-MTRuntimeText "WINGET_PARTIAL_WARN") $Module
        Set-ModuleResult (Get-MTRuntimeText "MODULE_WINGET") "WARN" $Detail
        exit 20
    }

    $Detail = Get-MTRuntimeText "WINGET_FAILED_DETAIL" @(
        $FinalResult,
        $FinalHex
    )

    Write-ErrorLog $Detail $Module
    Set-ModuleResult (Get-MTRuntimeText "MODULE_WINGET") "ERROR" $Detail
    exit 1
}
catch {
    Write-ErrorLog $_.Exception.Message $Module
    Write-ErrorLog $_.InvocationInfo.PositionMessage $Module
    Set-ModuleResult `
        (Get-MTRuntimeText "MODULE_WINGET") `
        "ERROR" `
        $_.Exception.Message
    exit 1
}
