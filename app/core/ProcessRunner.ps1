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
        [bool]$ShowProgressOutput = $false
    )

    $Out = Join-Path $env:MT_SESSION_DIR (
        "{0}_{1}.out.log" -f $Module, [guid]::NewGuid().ToString("N")
    )
    $Err = "$Out.err"

    try {
        Add-Log "INFO" "Comando: $FilePath $($ArgumentList -join ' ')" $Module
        Write-Host "$Label può richiedere diversi minuti. Non chiudere la finestra." -ForegroundColor Yellow

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

        if (-not $Process.Start()) {
            throw "Impossibile avviare $Label."
        }

        while (-not $Process.WaitForExit(1000)) {
            $Now = Get-Date
            $Elapsed = $Now - $Started

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
                    "{0} ancora in esecuzione. Tempo trascorso: {1}" -f
                    $Label,
                    $Elapsed.ToString("hh\:mm\:ss")
                ) $Module

                $LastLoggedHeartbeat = $Now
            }

            if (-not $DinnerMessageShown -and $Elapsed.TotalMinutes -ge 30) {
                Clear-LiveStatus -Length $StatusLength
                Write-Host ""
                Write-Host (
                    "Suggerimento: questa operazione è in corso da 30 minuti. " +
                    "Se qualcuno ti sta aspettando per cena, forse è il momento di avvisarlo."
                ) -ForegroundColor DarkYellow
                Write-Host ""
                $StatusLength = 0
                $DinnerMessageShown = $true
            }

            if (-not $HydrationMessageShown -and $Elapsed.TotalHours -ge 1) {
                Clear-LiveStatus -Length $StatusLength
                Write-Host ""
                Write-Host (
                    "È trascorsa un'ora. Questo è un buon momento per bere un bicchiere d'acqua."
                ) -ForegroundColor DarkYellow
                Write-Host ""
                $StatusLength = 0
                $HydrationMessageShown = $true
            }
        }

        $Process.WaitForExit()
        Clear-LiveStatus -Length $StatusLength
        $ExitCode = [int]$Process.ExitCode

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

        if ($ExitCode -in $SuccessCodes) {
            Write-Ok "$Label completato in $Duration. Exit code $ExitCode." $Module
        }
        else {
            Write-ErrorLog "$Label fallito dopo $Duration. Exit code $ExitCode." $Module
        }

        return [pscustomobject]@{
            ExitCode = $ExitCode
            OutputPath = $Out
            ErrorPath = $Err
            Duration = $Duration
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
        [bool]$CopyOutputToMainLog = $true
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
            -Wait `
            -PassThru `
            -NoNewWindow `
            -RedirectStandardOutput $Out `
            -RedirectStandardError $Err

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

        if ($Process.ExitCode -in $SuccessCodes) {
            Write-Ok "$Label completato. Exit code $($Process.ExitCode)." $Module
        }
        else {
            Write-ErrorLog "$Label fallito. Exit code $($Process.ExitCode)." $Module
        }

        return $Process.ExitCode
    }
    catch {
        Write-ErrorLog "${Label}: $($_.Exception.Message)" $Module
        return 9001
    }
}
