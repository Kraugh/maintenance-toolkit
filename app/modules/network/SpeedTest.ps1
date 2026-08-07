# MT4 optional Ookla SpeedTest service
# Behaviour baseline: NDP 0.0.19-RC
#
# The service never downloads an executable and never requests elevation.
# It searches:
#   1. <ProjectRoot>\external\speedtest.exe
#   2. speedtest.exe already available in PATH
#
# Missing SpeedTest is a WARN/SKIP condition, not an ERROR.

function Get-MTNetworkSpeedTestExecutable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot
    )

    $BundledPath = Join-Path $ProjectRoot 'external\speedtest.exe'

    if (Test-Path -LiteralPath $BundledPath -PathType Leaf) {
        return (Get-Item -LiteralPath $BundledPath).FullName
    }

    $Command = Get-Command speedtest.exe -ErrorAction SilentlyContinue

    if ($null -ne $Command) {
        return [string]$Command.Source
    }

    return $null
}

function ConvertFrom-MTNetworkSpeedTestJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$JsonText
    )

    $Trimmed = $JsonText.Trim()

    if ([string]::IsNullOrWhiteSpace($Trimmed)) {
        throw 'speedtest.exe returned no JSON data.'
    }

    # Preserve the defensive behaviour from NDP: some versions/tools can emit
    # incidental text before/after the JSON object.
    $JsonStart = $Trimmed.IndexOf('{')
    $JsonEnd = $Trimmed.LastIndexOf('}')

    if ($JsonStart -lt 0 -or $JsonEnd -le $JsonStart) {
        throw 'speedtest.exe output does not contain a recognizable JSON object.'
    }

    $JsonObjectText = $Trimmed.Substring(
        $JsonStart,
        ($JsonEnd - $JsonStart + 1)
    )

    $Raw = $JsonObjectText | ConvertFrom-Json

    $DownloadMbps = $null
    $UploadMbps = $null

    if ($null -ne $Raw.download -and $null -ne $Raw.download.bandwidth) {
        $DownloadMbps = [math]::Round(
            ([double]$Raw.download.bandwidth * 8 / 1000000),
            2
        )
    }

    if ($null -ne $Raw.upload -and $null -ne $Raw.upload.bandwidth) {
        $UploadMbps = [math]::Round(
            ([double]$Raw.upload.bandwidth * 8 / 1000000),
            2
        )
    }

    return [pscustomobject]@{
        Raw = $Raw
        PingMs = if ($null -ne $Raw.ping) { $Raw.ping.latency } else { $null }
        JitterMs = if ($null -ne $Raw.ping) { $Raw.ping.jitter } else { $null }
        PacketLossPercent = $Raw.packetLoss
        DownloadMbps = $DownloadMbps
        UploadMbps = $UploadMbps
        ServerName = if ($null -ne $Raw.server) { $Raw.server.name } else { $null }
        ServerHost = if ($null -ne $Raw.server) { $Raw.server.host } else { $null }
        ServerLocation = if ($null -ne $Raw.server) { $Raw.server.location } else { $null }
        ServerCountry = if ($null -ne $Raw.server) { $Raw.server.country } else { $null }
        ResultUrl = if ($null -ne $Raw.result) { $Raw.result.url } else { $null }
        ExternalIp = if ($null -ne $Raw.interface) { $Raw.interface.externalIp } else { $null }
    }
}

function Invoke-MTNetworkSpeedTest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][object]$LanguageData,
        [switch]$ShowProgress
    )

    $Executable = Get-MTNetworkSpeedTestExecutable -ProjectRoot $ProjectRoot

    if ([string]::IsNullOrWhiteSpace([string]$Executable)) {
        return [pscustomobject]@{
            Status = 'WARN'
            Available = $false
            Executed = $false
            Executable = $null
            Result = $null
            RawJson = $null
            ErrorMessage = (
                Get-MTText `
                    -LanguageData $LanguageData `
                    -Key 'SPEEDTEST_MISSING'
            )
            DurationMs = 0
        }
    }

    $Started = Get-Date

    try {
        $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessInfo.FileName = $Executable
        $ProcessInfo.Arguments = '--accept-license --accept-gdpr --progress=no --format=json'
        $ProcessInfo.UseShellExecute = $false
        $ProcessInfo.CreateNoWindow = $true
        $ProcessInfo.RedirectStandardOutput = $true
        $ProcessInfo.RedirectStandardError = $true

        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessInfo

        if (-not $Process.Start()) {
            throw 'Unable to start speedtest.exe.'
        }

        $StdOutTask = $Process.StandardOutput.ReadToEndAsync()
        $StdErrTask = $Process.StandardError.ReadToEndAsync()

        $LastLength = 0

        while (-not $Process.WaitForExit(1000)) {
            if ($ShowProgress) {
                $Elapsed = [math]::Floor(((Get-Date) - $Started).TotalSeconds)

                $Message = Get-MTText `
                    -LanguageData $LanguageData `
                    -Key 'SPEEDTEST_RUNNING' `
                    -Arguments @($Elapsed)

                $Padding = ''
                if ($LastLength -gt $Message.Length) {
                    $Padding = ' ' * ($LastLength - $Message.Length)
                }

                Write-Host ("`r" + $Message + $Padding) -NoNewline -ForegroundColor Cyan
                $LastLength = $Message.Length
            }
        }

        $Process.WaitForExit()

        if ($ShowProgress -and $LastLength -gt 0) {
            Write-Host ("`r" + (' ' * $LastLength) + "`r") -NoNewline
        }

        $StdOut = $StdOutTask.Result
        $StdErr = $StdErrTask.Result
        $DurationMs = [math]::Round(((Get-Date) - $Started).TotalMilliseconds, 2)

        if ($Process.ExitCode -ne 0) {
            $FailureText = $StdErr.Trim()

            if ([string]::IsNullOrWhiteSpace($FailureText)) {
                $FailureText = $StdOut.Trim()
            }

            throw (
                'speedtest.exe exit code {0}: {1}' -f
                $Process.ExitCode,
                $FailureText
            )
        }

        $Parsed = ConvertFrom-MTNetworkSpeedTestJson -JsonText $StdOut

        return [pscustomobject]@{
            Status = 'OK'
            Available = $true
            Executed = $true
            Executable = $Executable
            Result = $Parsed
            RawJson = $Parsed.Raw
            ErrorMessage = $null
            DurationMs = $DurationMs
        }
    }
    catch {
        if ($ShowProgress) {
            Write-Host ""
        }

        return [pscustomobject]@{
            Status = 'ERROR'
            Available = $true
            Executed = $true
            Executable = $Executable
            Result = $null
            RawJson = $null
            ErrorMessage = $_.Exception.Message
            DurationMs = [math]::Round(((Get-Date) - $Started).TotalMilliseconds, 2)
        }
    }
}

function Show-MTNetworkSpeedTestResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$SpeedTestResult,
        [Parameter(Mandatory)][object]$LanguageData
    )

    if (-not $SpeedTestResult.Available) {
        Write-MTNetworkStatus `
            -Level 'WARN' `
            -Label (Get-MTText $LanguageData 'SPEEDTEST') `
            -Value $SpeedTestResult.ErrorMessage
        return
    }

    if ($SpeedTestResult.Status -ne 'OK') {
        Write-MTNetworkStatus `
            -Level 'ERROR' `
            -Label (Get-MTText $LanguageData 'SPEEDTEST') `
            -Value $SpeedTestResult.ErrorMessage
        return
    }

    $Result = $SpeedTestResult.Result

    Write-Host ""
    Write-Host (Get-MTText $LanguageData 'SPEEDTEST_SECTION') -ForegroundColor Cyan
    Write-Host ('-' * 72)

    Write-MTNetworkStatus `
        -Level 'OK' `
        -Label (Get-MTText $LanguageData 'PING') `
        -Value ('{0} ms' -f $Result.PingMs)

    Write-MTNetworkStatus `
        -Level 'OK' `
        -Label (Get-MTText $LanguageData 'JITTER') `
        -Value ('{0} ms' -f $Result.JitterMs)

    Write-MTNetworkStatus `
        -Level 'OK' `
        -Label (Get-MTText $LanguageData 'DOWNLOAD') `
        -Value ('{0} Mbps' -f $Result.DownloadMbps)

    Write-MTNetworkStatus `
        -Level 'OK' `
        -Label (Get-MTText $LanguageData 'UPLOAD') `
        -Value ('{0} Mbps' -f $Result.UploadMbps)

    if ($null -ne $Result.PacketLossPercent) {
        Write-MTNetworkStatus `
            -Level 'INFO' `
            -Label (Get-MTText $LanguageData 'PACKET_LOSS') `
            -Value ('{0} %' -f $Result.PacketLossPercent)
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Result.ServerName)) {
        $ServerText = $Result.ServerName

        if (-not [string]::IsNullOrWhiteSpace([string]$Result.ServerLocation)) {
            $ServerText += ' - ' + $Result.ServerLocation
        }

        Write-MTNetworkStatus `
            -Level 'INFO' `
            -Label (Get-MTText $LanguageData 'SPEEDTEST_SERVER') `
            -Value $ServerText
    }
}
