# Transitional MT4 logging service.
# Behaviour is preserved from Maintenance Toolkit 3.7.2 while callers are
# migrated away from modules/00_common.ps1.

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
