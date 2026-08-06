function Get-MTStatusVisual {
    [CmdletBinding()]
    param(
        [ValidateSet('OK','INFO','WARN','SKIP','ERROR')][string]$Status,
        [Parameter(Mandatory)][object]$Theme
    )
    $entry = $Theme.Status.$Status
    if (-not $entry) { $entry = $Theme.Status.INFO }
    [pscustomobject]@{ Symbol=[string]$entry.Symbol; Color=[string]$entry.Color }
}

function Write-MTCoreStatus {
    [CmdletBinding()]
    param(
        [ValidateSet('OK','INFO','WARN','SKIP','ERROR')][string]$Status,
        [Parameter(Mandatory)][string]$Label,
        [string]$Value = '',
        [Parameter(Mandatory)][object]$Theme
    )
    $visual = Get-MTStatusVisual -Status $Status -Theme $Theme
    $line = if ([string]::IsNullOrWhiteSpace($Value)) { '{0} {1}' -f $visual.Symbol,$Label } else { '{0} {1,-26}: {2}' -f $visual.Symbol,$Label,$Value }
    if ($Theme.Console.ShowColors) { Write-Host $line -ForegroundColor $visual.Color } else { Write-Host $line }
    return $line
}


###############################################################################
# MT 3.7.2 compatibility surface
#
# These names are consumed by the current maintenance modules. They remain
# intentionally stable while the modules are migrated to localized MT4 calls.
###############################################################################

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
