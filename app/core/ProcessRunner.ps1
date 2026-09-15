# Transitional MT4 process service.
# This is the tested MT 3.7.2 native-process implementation, extracted without
# functional changes. Localization and generic operation rendering will be
# introduced only after regression validation.

function Read-ProcessOutput {
    param(
        [string]$Path,
        [ValidateSet("Default", "UTF8", "Unicode", "OEM")]
        [string]$Encoding = "Default"
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    try {
        switch ($Encoding) {
            "UTF8"    { return @(Get-Content -LiteralPath $Path -Encoding UTF8) }
            "Unicode" { return @(Get-Content -LiteralPath $Path -Encoding Unicode) }
            "OEM"     { return @([System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::Default)) }
            default   { return @(Get-Content -LiteralPath $Path) }
        }
    }
    catch {
        return @("Impossibile leggere l'output '$Path': $($_.Exception.Message)")
    }
}
function ConvertTo-WindowsCommandLineArgument {
    param([AllowEmptyString()][string]$Argument)

    if ($Argument -notmatch '[\s"]') {
        return $Argument
    }

    $Result = '"'
    $Backslashes = 0

    foreach ($Character in $Argument.ToCharArray()) {
        if ($Character -eq '\') {
            $Backslashes++
            continue
        }

        if ($Character -eq '"') {
            $Result += ('\' * (($Backslashes * 2) + 1))
            $Result += '"'
            $Backslashes = 0
            continue
        }

        if ($Backslashes -gt 0) {
            $Result += ('\' * $Backslashes)
            $Backslashes = 0
        }

        $Result += $Character
    }

    if ($Backslashes -gt 0) {
        $Result += ('\' * ($Backslashes * 2))
    }

    return $Result + '"'
}
function Join-WindowsCommandLine {
    param([string[]]$Arguments)

    return (
        $Arguments |
            ForEach-Object { ConvertTo-WindowsCommandLineArgument ([string]$_) }
    ) -join ' '
}
function Read-SharedTextFile {
    param(
        [string]$Path,
        [ValidateSet("Default", "UTF8", "Unicode", "OEM")]
        [string]$Encoding = "Default"
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }

    try {
        $SelectedEncoding = switch ($Encoding) {
            "UTF8"    { New-Object System.Text.UTF8Encoding($false) }
            "Unicode" { [System.Text.Encoding]::Unicode }
            "OEM"     { [System.Text.Encoding]::Default }
            default   { [System.Text.Encoding]::Default }
        }

        $Stream = [System.IO.File]::Open(
            $Path,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )

        try {
            $Reader = New-Object System.IO.StreamReader(
                $Stream,
                $SelectedEncoding,
                $true
            )

            try {
                return $Reader.ReadToEnd()
            }
            finally {
                $Reader.Dispose()
            }
        }
        finally {
            $Stream.Dispose()
        }
    }
    catch {
        return ""
    }
}
function Get-LongOperationStatus {
    param(
        [string]$Label,
        [string]$OutputPath,
        [ValidateSet("Default", "UTF8", "Unicode", "OEM")]
        [string]$OutputEncoding,
        [timespan]$Elapsed,
        [int]$SpinnerIndex
    )

    $ElapsedText = $Elapsed.ToString("hh\:mm\:ss")
    $Output = Read-SharedTextFile -Path $OutputPath -Encoding $OutputEncoding

    if ($Label -eq "SFC Scannow" -and $Output) {
        $Matches = [regex]::Matches($Output, '(\d{1,3})%')

        if ($Matches.Count -gt 0) {
            $Percent = [Math]::Min(
                100,
                [int]$Matches[$Matches.Count - 1].Groups[1].Value
            )
            $Width = 20
            $Completed = [Math]::Floor(($Percent / 100) * $Width)
            $Bar = ("#" * $Completed).PadRight($Width, "-")

            return "SFC Scannow [$Bar] {0,3}%  $ElapsedText" -f $Percent
        }
    }

    if ($Label -like "Winget*" -and $Output) {
        $Matches = [regex]::Matches($Output, '\((\d+)\s*/\s*(\d+)\)')

        if ($Matches.Count -gt 0) {
            $Current = [int]$Matches[$Matches.Count - 1].Groups[1].Value
            $Total = [int]$Matches[$Matches.Count - 1].Groups[2].Value

            if ($Total -gt 0) {
                $Width = 20
                $Percent = [Math]::Min(100, [Math]::Floor(($Current / $Total) * 100))
                $Completed = [Math]::Floor(($Percent / 100) * $Width)
                $Bar = ("#" * $Completed).PadRight($Width, "-")

                return "$Label [$Bar] $Current/$Total  $ElapsedText"
            }
        }
    }

    $Frames = @("|", "/", "-", "\")
    $Frame = $Frames[$SpinnerIndex % $Frames.Count]
    return "$Label  $Frame  $ElapsedText"
}
function Write-LiveStatus {
    param(
        [string]$Text,
        [int]$PreviousLength = 0
    )

    $Width = [Math]::Max($PreviousLength, $Text.Length)
    [Console]::Write("`r" + $Text.PadRight($Width))
    return $Width
}
function Clear-LiveStatus {
    param([int]$Length)

    if ($Length -gt 0) {
        [Console]::Write("`r" + (" " * $Length) + "`r")
    }
}
function Stop-MTProcessTree {
    param([int]$ProcessId)

    # Take repeated snapshots because installers can spawn children while the
    # tree is being stopped. Children are terminated before their parents.
    for ($Pass = 0; $Pass -lt 3; $Pass++) {
        $Processes = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
        $ChildrenByParent = @{}

        foreach ($Item in $Processes) {
            $ParentId = [int]$Item.ParentProcessId
            if (-not $ChildrenByParent.ContainsKey($ParentId)) {
                $ChildrenByParent[$ParentId] = New-Object System.Collections.ArrayList
            }
            [void]$ChildrenByParent[$ParentId].Add([int]$Item.ProcessId)
        }

        $Ordered = New-Object System.Collections.Generic.List[int]
        $Visit = $null
        $Visit = {
            param([int]$Id)
            if ($ChildrenByParent.ContainsKey($Id)) {
                foreach ($ChildId in @($ChildrenByParent[$Id])) {
                    & $Visit $ChildId
                }
            }
            if ($Id -ne $ProcessId) {
                $Ordered.Add($Id)
            }
        }
        & $Visit $ProcessId

        foreach ($Id in $Ordered) {
            Stop-Process -Id $Id -Force -ErrorAction SilentlyContinue
        }
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue

        Start-Sleep -Milliseconds 250
        if (-not (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) {
            break
        }
    }
}
function Invoke-LoggedProcessWithHeartbeat {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$Label,
        [string]$Module,
        [int[]]$SuccessCodes = @(0),
        [int]$HeartbeatSeconds = 60,
        [ValidateSet("Default", "UTF8", "Unicode", "OEM")]
        [string]$OutputEncoding = "Default",
        [bool]$ShowProgressOutput = $false,
        [int]$TimeoutSeconds = 0
    )

    $Out = Join-Path $env:MT_SESSION_DIR (
        "{0}_{1}.out.log" -f $Module, [guid]::NewGuid().ToString("N")
    )
    $Err = "$Out.err"

    try {
        Add-Log "INFO" "Comando: $FilePath $($ArgumentList -join ' ')" $Module
        Write-Host (
            Get-MTRuntimeText "PROCESS_LONG_START" @($Label)
        ) -ForegroundColor Yellow

        # cmd.exe performs redirection directly to files. This keeps stdout and
        # stderr available for live progress polling without PowerShell event
        # callbacks, while the Process object still returns a reliable exit code.
        $NativeArguments = Join-WindowsCommandLine $ArgumentList
        $NativeCommand = '"{0}" {1} 1>"{2}" 2>"{3}"' -f `
            $FilePath,
            $NativeArguments,
            $Out,
            $Err

        $StartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $StartInfo.FileName = $env:ComSpec
        $StartInfo.Arguments = '/d /s /c "' + $NativeCommand + '"'
        $StartInfo.UseShellExecute = $false
        $StartInfo.CreateNoWindow = $true

        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $StartInfo

        $Started = Get-Date
        $LastLoggedHeartbeat = $Started
        $SpinnerIndex = 0
        $StatusLength = 0
        $DinnerMessageShown = $false
        $HydrationMessageShown = $false
        $TimedOut = $false

        if (-not $Process.Start()) {
            throw "Impossibile avviare $Label."
        }

        while (-not $Process.WaitForExit(1000)) {
            $Now = Get-Date
            $Elapsed = $Now - $Started

            if ($TimeoutSeconds -gt 0 -and $Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                $TimedOut = $true
                Clear-LiveStatus -Length $StatusLength
                Add-Log "WARN" (
                    Get-MTRuntimeText "PROCESS_TIMEOUT" @(
                        $Label,
                        $Elapsed.ToString("hh\:mm\:ss")
                    )
                ) $Module
                Stop-MTProcessTree -ProcessId $Process.Id
                break
            }

            $Status = Get-LongOperationStatus `
                -Label $Label `
                -OutputPath $Out `
                -OutputEncoding $OutputEncoding `
                -Elapsed $Elapsed `
                -SpinnerIndex $SpinnerIndex

            $StatusLength = Write-LiveStatus `
                -Text $Status `
                -PreviousLength $StatusLength

            $SpinnerIndex++

            if (
                $HeartbeatSeconds -gt 0 -and
                ($Now - $LastLoggedHeartbeat).TotalSeconds -ge $HeartbeatSeconds
            ) {
                Add-Log "INFO" (
                    Get-MTRuntimeText "PROCESS_LONG_RUNNING" @(
                        $Label,
                        $Elapsed.ToString("hh\:mm\:ss")
                    )
                ) $Module

                $LastLoggedHeartbeat = $Now
            }

            if (-not $DinnerMessageShown -and $Elapsed.TotalMinutes -ge 30) {
                Clear-LiveStatus -Length $StatusLength
                Write-Host ""
                Write-Host (
                    Get-MTRuntimeText "PROCESS_DINNER_HINT"
                ) -ForegroundColor DarkYellow
                Write-Host ""
                $StatusLength = 0
                $DinnerMessageShown = $true
            }

            if (-not $HydrationMessageShown -and $Elapsed.TotalHours -ge 1) {
                Clear-LiveStatus -Length $StatusLength
                Write-Host ""
                Write-Host (
                    Get-MTRuntimeText "PROCESS_HYDRATION_HINT"
                ) -ForegroundColor DarkYellow
                Write-Host ""
                $StatusLength = 0
                $HydrationMessageShown = $true
            }
        }

        $Process.WaitForExit()
        Clear-LiveStatus -Length $StatusLength
        $ExitCode = if ($TimedOut) { 9002 } else { [int]$Process.ExitCode }

        $StdOut = Read-SharedTextFile -Path $Out -Encoding $OutputEncoding
        $StdErr = Read-SharedTextFile -Path $Err -Encoding $OutputEncoding

        foreach ($Line in ([string]$StdOut -split "\r?\n")) {
            if (-not [string]::IsNullOrWhiteSpace($Line)) {
                Add-Log "OUTPUT" $Line $Module
            }
        }

        foreach ($Line in ([string]$StdErr -split "\r?\n")) {
            if (-not [string]::IsNullOrWhiteSpace($Line)) {
                Add-Log "OUTPUT" $Line $Module
            }
        }

        $Duration = ((Get-Date) - $Started).ToString("hh\:mm\:ss")

        if ($TimedOut) {
            Write-WarnLog (
                Get-MTRuntimeText "PROCESS_TIMEOUT_RESULT" @($Label, $TimeoutSeconds)
            ) $Module
        }
        elseif ($ExitCode -in $SuccessCodes) {
            Write-Ok (
                Get-MTRuntimeText "PROCESS_COMPLETED_DURATION" @(
                    $Label,
                    $Duration,
                    $ExitCode
                )
            ) $Module
        }
        else {
            Write-ErrorLog (
                Get-MTRuntimeText "PROCESS_FAILED_DURATION" @(
                    $Label,
                    $Duration,
                    $ExitCode
                )
            ) $Module
        }

        return [pscustomobject]@{
            ExitCode = $ExitCode
            OutputPath = $Out
            ErrorPath = $Err
            Duration = $Duration
            TimedOut = $TimedOut
        }
    }
    catch {
        Clear-LiveStatus -Length $StatusLength
        Write-ErrorLog "${Label}: $($_.Exception.Message)" $Module
        Write-ErrorLog $_.InvocationInfo.PositionMessage $Module

        return [pscustomobject]@{
            ExitCode = 9001
            OutputPath = $Out
            ErrorPath = $Err
            Duration = "00:00:00"
            TimedOut = $false
        }
    }
}
function Invoke-LoggedProcess {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$Label,
        [string]$Module = "PROCESS",
        [int[]]$SuccessCodes = @(0),
        [ValidateSet("Default", "UTF8", "Unicode", "OEM")]
        [string]$OutputEncoding = "Default",
        [bool]$CopyOutputToMainLog = $true,
        [int]$TimeoutSeconds = 0
    )

    $Out = Join-Path $env:MT_SESSION_DIR (
        "{0}_{1}.out.log" -f $Module, [guid]::NewGuid().ToString("N")
    )
    $Err = "$Out.err"

    try {
        Add-Log "INFO" "Comando: $FilePath $($ArgumentList -join ' ')" $Module

        $Process = Start-Process `
            -FilePath $FilePath `
            -ArgumentList $ArgumentList `
            -PassThru `
            -NoNewWindow `
            -RedirectStandardOutput $Out `
            -RedirectStandardError $Err

        $Started = Get-Date
        $TimedOut = $false

        while (-not $Process.WaitForExit(1000)) {
            if (
                $TimeoutSeconds -gt 0 -and
                ((Get-Date) - $Started).TotalSeconds -ge $TimeoutSeconds
            ) {
                $TimedOut = $true
                Add-Log "WARN" (
                    Get-MTRuntimeText "PROCESS_TIMEOUT" @(
                        $Label,
                        ((Get-Date) - $Started).ToString("hh\:mm\:ss")
                    )
                ) $Module
                Stop-MTProcessTree -ProcessId $Process.Id
                break
            }
        }

        $Process.WaitForExit()
        $ExitCode = if ($TimedOut) { 9002 } else { [int]$Process.ExitCode }

        if ($CopyOutputToMainLog) {
            foreach ($File in @($Out, $Err)) {
                Read-ProcessOutput -Path $File -Encoding $OutputEncoding |
                    ForEach-Object {
                        if (-not [string]::IsNullOrWhiteSpace($_)) {
                            Add-Log "OUTPUT" $_ $Module
                        }
                    }
            }
        }

        if ($TimedOut) {
            Write-WarnLog (
                Get-MTRuntimeText "PROCESS_TIMEOUT_RESULT" @($Label, $TimeoutSeconds)
            ) $Module
        }
        elseif ($ExitCode -in $SuccessCodes) {
            Write-Ok (
                Get-MTRuntimeText "PROCESS_COMPLETED" @($Label, $ExitCode)
            ) $Module
        }
        else {
            Write-ErrorLog (
                Get-MTRuntimeText "PROCESS_FAILED" @($Label, $ExitCode)
            ) $Module
        }

        return $ExitCode
    }
    catch {
        Write-ErrorLog "${Label}: $($_.Exception.Message)" $Module
        return 9001
    }
}
