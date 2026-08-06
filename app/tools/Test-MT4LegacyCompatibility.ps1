param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = 'Stop'

try {
    . (Join-Path $ProjectRoot 'modules/00_common.ps1')

    foreach ($CommandName in @(
        'Add-Log',
        'Write-Main',
        'Write-Ok',
        'Write-WarnLog',
        'Write-Skip',
        'Write-ErrorLog',
        'Read-IniFile',
        'Get-IniValue',
        'Get-IniBool',
        'Set-ModuleResult',
        'Invoke-LoggedProcess',
        'Invoke-LoggedProcessWithHeartbeat'
    )) {
        if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
            throw "Compatibility command missing: $CommandName"
        }
    }

    # MT 3.7.2 can return one selected module as a scalar object because
    # PowerShell enumerates arrays returned by Select-Modules.
    #
    # The legacy code does NOT require scalar .Count to equal 1.
    # Its real contract is simply that this expression must not throw:
    #
    #     if ($Selected.Count -eq 0) { ... }
    #
    # In Windows PowerShell 5.1 without StrictMode, a missing scalar Count
    # property evaluates to $null, therefore the condition is false and the
    # selected module proceeds normally. With leaked StrictMode the same
    # property access raises PropertyNotFoundStrict.
    $Selected = [pscustomobject]@{
        Id = 1
        Name = 'Connectivity'
    }

    $WouldSkip = $false

    if ($Selected.Count -eq 0) {
        $WouldSkip = $true
    }

    if ($WouldSkip) {
        throw "Legacy single-module selection was incorrectly treated as empty."
    }

    Write-Host "MT4 Legacy Compatibility: OK"
    exit 0
}
catch {
    Write-Host (
        "MT4 Legacy Compatibility: ERROR - {0}" -f $_.Exception.Message
    ) -ForegroundColor Red
    exit 1
}
