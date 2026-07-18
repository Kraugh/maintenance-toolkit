###############################################################################
# Maintenance Toolkit 3.0.6.2
#
# Autore:
#   Luca Miselli
#   https://www.kraugh.it
#
# Sviluppato con l'indispensabile aiuto di una Rubber Duck molto paziente.
###############################################################################

$script:MainLog = $null
$script:ErrorLog = $null
$script:SessionLog = $null

function Initialize-LogPaths {
    if ([string]::IsNullOrWhiteSpace($env:MT_LOGS)) {
        throw "Variabile MT_LOGS non inizializzata."
    }

    if ([string]::IsNullOrWhiteSpace($env:MT_SESSION_DIR)) {
        throw "Variabile MT_SESSION_DIR non inizializzata."
    }

    New-Item -ItemType Directory -Path $env:MT_LOGS -Force | Out-Null
    New-Item -ItemType Directory -Path $env:MT_SESSION_DIR -Force | Out-Null

    $script:MainLog = Join-Path $env:MT_LOGS "aggiornamenti_script.log"
    $script:ErrorLog = Join-Path $env:MT_LOGS "errori_script.log"
    $script:SessionLog = Join-Path $env:MT_SESSION_DIR "sessione.log"
}

function Write-TextLineRobust {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Line,
        [int]$Retries = 5,
        [int]$DelayMilliseconds = 250
    )

    $Encoding = New-Object System.Text.UTF8Encoding($true)

    for ($Attempt = 1; $Attempt -le $Retries; $Attempt++) {
        try {
            $Directory = Split-Path -Parent $Path
            if ($Directory) { New-Item -ItemType Directory -Path $Directory -Force | Out-Null }

            $Stream = [System.IO.File]::Open(
                $Path,
                [System.IO.FileMode]::Append,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::ReadWrite
            )
            try {
                $Writer = New-Object System.IO.StreamWriter($Stream, $Encoding)
                try {
                    $Writer.WriteLine($Line)
                    $Writer.Flush()
                }
                finally { $Writer.Dispose() }
            }
            finally { $Stream.Dispose() }
            return $true
        }
        catch {
            if ($Attempt -lt $Retries) { Start-Sleep -Milliseconds $DelayMilliseconds }
        }
    }
    return $false
}

function Add-Log {
    param(
        [string]$Level,
        [string]$Message,
        [string]$Module = "CORE"
    )

    if (-not $script:MainLog -or -not $script:ErrorLog -or -not $script:SessionLog) {
        Initialize-LogPaths
    }

    $Line = "[{0}] [{1}] [{2}] {3}" -f `
        (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Module, $Message

    $SessionWritten = Write-TextLineRobust -Path $script:SessionLog -Line $Line -Retries 8 -DelayMilliseconds 250
    if (-not $SessionWritten) {
        Write-Host "AVVISO: impossibile scrivere nel log di sessione." -ForegroundColor Yellow
    }

    $MainWritten = Write-TextLineRobust -Path $script:MainLog -Line $Line -Retries 5 -DelayMilliseconds 300
    if (-not $MainWritten -and $SessionWritten) {
        $WarningLine = "[{0}] [WARN] [LOGGER] Log cumulativo temporaneamente non disponibile: {1}" -f `
            (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $script:MainLog
        [void](Write-TextLineRobust -Path $script:SessionLog -Line $WarningLine -Retries 3 -DelayMilliseconds 200)
    }

    if ($Level -eq "ERROR") {
        $ErrorWritten = Write-TextLineRobust -Path $script:ErrorLog -Line $Line -Retries 5 -DelayMilliseconds 300
        if (-not $ErrorWritten -and $SessionWritten) {
            $WarningLine = "[{0}] [WARN] [LOGGER] Log errori temporaneamente non disponibile: {1}" -f `
                (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $script:ErrorLog
            [void](Write-TextLineRobust -Path $script:SessionLog -Line $WarningLine -Retries 3 -DelayMilliseconds 200)
        }
    }
}

function Write-Main {
    param([string]$Message)
    Add-Log "INFO" $Message
    Write-Host $Message
}

function Write-Ok {
    param([string]$Message, [string]$Module = "CORE")
    Add-Log "OK" $Message $Module
    Write-Host $Message -ForegroundColor Green
}

function Write-WarnLog {
    param([string]$Message, [string]$Module = "CORE")
    Add-Log "WARN" $Message $Module
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Skip {
    param([string]$Message, [string]$Module = "CORE")
    Add-Log "SKIP" $Message $Module
    Write-Host $Message -ForegroundColor DarkYellow
}

function Write-ErrorLog {
    param([string]$Message, [string]$Module = "CORE")
    Add-Log "ERROR" $Message $Module
    Write-Host "ERRORE: $Message" -ForegroundColor Red
}

function Read-IniFile {
    param([string]$Path)

    $Data = @{}
    $Section = "General"
    $Data[$Section] = @{}

    foreach ($Raw in Get-Content -LiteralPath $Path) {
        $Line = $Raw.Trim()

        if (-not $Line -or $Line.StartsWith(";") -or $Line.StartsWith("#")) {
            continue
        }

        if ($Line -match '^\[(.+)\]$') {
            $Section = $matches[1]

            if (-not $Data.ContainsKey($Section)) {
                $Data[$Section] = @{}
            }

            continue
        }

        if ($Line -match '^([^=]+)=(.*)$') {
            $Data[$Section][$matches[1].Trim()] = $matches[2].Trim()
        }
    }

    return $Data
}

function Get-IniValue {
    param($Config, [string]$Section, [string]$Key, $Default = $null)

    if ($Config.ContainsKey($Section) -and $Config[$Section].ContainsKey($Key)) {
        return $Config[$Section][$Key]
    }

    return $Default
}

function Get-IniBool {
    param($Config, [string]$Section, [string]$Key, [bool]$Default = $false)

    $Value = Get-IniValue $Config $Section $Key $null

    if ($null -eq $Value) {
        return $Default
    }

    return $Value -match '^(1|true|yes|si|on)$'
}

function Set-ModuleResult {
    param(
        [string]$Module,
        [ValidateSet("OK", "WARN", "ERROR", "SKIP")]
        [string]$Status,
        [string]$Detail,
        [bool]$RebootRequired = $false
    )

    [pscustomobject]@{
        Module = $Module
        Status = $Status
        Detail = $Detail
        RebootRequired = $RebootRequired
    } |
        ConvertTo-Json |
        Set-Content -LiteralPath $env:MT_RESULT -Encoding UTF8
}

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

function Invoke-LoggedProcessWithHeartbeat {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$Label,
        [string]$Module,
        [int[]]$SuccessCodes = @(0),
        [int]$HeartbeatSeconds = 15,
        [ValidateSet("Default", "UTF8", "Unicode", "OEM")][string]$OutputEncoding = "Default"
    )

    $Out = Join-Path $env:MT_SESSION_DIR ("{0}_{1}.out.log" -f $Module, [guid]::NewGuid().ToString("N"))
    $Err = "$Out.err"

    try {
        Add-Log "INFO" "Comando: $FilePath $($ArgumentList -join ' ')" $Module
        Write-Host "$Label può richiedere diversi minuti. Non chiudere la finestra." -ForegroundColor Yellow
        $Started = Get-Date
        $Process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -PassThru -NoNewWindow `
            -RedirectStandardOutput $Out -RedirectStandardError $Err

        while (-not $Process.HasExited) {
            Start-Sleep -Seconds $HeartbeatSeconds
            $Process.Refresh()
            if (-not $Process.HasExited) {
                $Elapsed = (Get-Date) - $Started
                $Message = "{0} in esecuzione... tempo trascorso {1}" -f $Label, $Elapsed.ToString("hh\:mm\:ss")
                Write-Host $Message -ForegroundColor Cyan
                Add-Log "INFO" $Message $Module
            }
        }
        $Process.WaitForExit()

        foreach ($File in @($Out, $Err)) {
            Read-ProcessOutput -Path $File -Encoding $OutputEncoding | ForEach-Object {
                if (-not [string]::IsNullOrWhiteSpace($_)) { Add-Log "OUTPUT" $_ $Module }
            }
        }

        $Duration = ((Get-Date) - $Started).ToString("hh\:mm\:ss")
        if ($Process.ExitCode -in $SuccessCodes) {
            Write-Ok "$Label completato in $Duration. Exit code $($Process.ExitCode)." $Module
        } else {
            Write-ErrorLog "$Label fallito dopo $Duration. Exit code $($Process.ExitCode)." $Module
        }

        return [pscustomobject]@{ ExitCode=$Process.ExitCode; OutputPath=$Out; ErrorPath=$Err; Duration=$Duration }
    }
    catch {
        Write-ErrorLog "${Label}: $($_.Exception.Message)" $Module
        return [pscustomobject]@{ ExitCode=9001; OutputPath=$Out; ErrorPath=$Err; Duration="00:00:00" }
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
