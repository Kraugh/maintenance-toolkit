###############################################################################
# Maintenance Toolkit 4.0 - Winget module
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
        -ShowProgressOutput $true

    $CombinedOutput = @()

    foreach ($File in @($Run.OutputPath, $Run.ErrorPath)) {
        $CombinedOutput += Read-ProcessOutput -Path $File -Encoding "UTF8"
    }

    $CombinedOutput | Set-Content -LiteralPath $RawLog -Encoding UTF8

    return [int]$Run.ExitCode
}

try {
    $Winget = Get-WingetCommand

    if (-not $Winget) {
        throw (Get-MTRuntimeText "WINGET_NOT_FOUND")
    }

    $BeforePath = Join-Path $env:MT_SESSION_DIR "winget_prima.txt"
    $AfterPath = Join-Path $env:MT_SESSION_DIR "winget_dopo.txt"

    Write-Main (Get-MTRuntimeText "WINGET_GET_AVAILABLE")

    & $Winget.Source upgrade `
        --accept-source-agreements `
        --disable-interactivity 2>&1 |
        Set-Content -LiteralPath $BeforePath -Encoding UTF8

    Write-Main (Get-MTRuntimeText "WINGET_UPDATE_SOURCES")

    $SourceResult = Invoke-LoggedProcess `
        -FilePath $Winget.Source `
        -ArgumentList @("source", "update", "--disable-interactivity") `
        -Label (Get-MTRuntimeText "WINGET_SOURCE_LABEL") `
        -Module $Module `
        -OutputEncoding "UTF8" `
        -CopyOutputToMainLog $false

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

        Write-WarnLog (
            Get-MTRuntimeText "WINGET_FIRST_PASS_RETRY" @(
                $FirstResult,
                $WaitSeconds
            )
        ) $Module

        Start-Sleep -Seconds $WaitSeconds

        $Winget = Get-WingetCommand

        if (-not $Winget) {
            throw (Get-MTRuntimeText "WINGET_NOT_AVAILABLE_AFTER_FIRST")
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
            Get-MTRuntimeText "WINGET_DETAIL_SECOND_PASS"
        }
        else {
            Get-MTRuntimeText "WINGET_DETAIL_FIRST_PASS"
        }

        Write-Ok (Get-MTRuntimeText "WINGET_COMPLETED") $Module
        Set-ModuleResult (Get-MTRuntimeText "MODULE_WINGET") "OK" $Detail
        exit 0
    }

    $FinalHex = "0x{0:X8}" -f ($FinalResult -band 0xffffffff)

    if ($FinalHex -eq "0x8A15002C") {
        $Detail = Get-MTRuntimeText "WINGET_PARTIAL_DETAIL" @(
            $FirstResult,
            $FinalResult,
            $FinalHex
        )

        Write-WarnLog (Get-MTRuntimeText "WINGET_PARTIAL_WARN") $Module
        Set-ModuleResult (Get-MTRuntimeText "MODULE_WINGET") "WARN" $Detail
        exit 20
    }

    $Detail = Get-MTRuntimeText "WINGET_FAILED_DETAIL" @(
        $FirstResult,
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
