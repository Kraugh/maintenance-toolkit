function New-MTModuleResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ModuleKey,
        [ValidateSet('OK','INFO','WARN','SKIP','ERROR')][string]$Status = 'OK',
        [string]$SummaryKey = '',
        [object[]]$SummaryArguments = @(),
        [datetime]$Started = (Get-Date),
        [datetime]$Finished = (Get-Date),
        [bool]$RequiresReboot = $false,
        [object[]]$Artifacts = @(),
        [object[]]$Diagnostics = @()
    )
    [pscustomobject]@{
        ModuleKey=$ModuleKey; Status=$Status; SummaryKey=$SummaryKey; SummaryArguments=$SummaryArguments
        Started=$Started; Finished=$Finished; Duration=($Finished-$Started); RequiresReboot=$RequiresReboot
        Artifacts=$Artifacts; Diagnostics=$Diagnostics
    }
}


###############################################################################
# MT 3.7.2 compatibility adapter
#
# Existing modules still write module_result.json. New MT4 modules should
# return New-MTModuleResult objects directly.
###############################################################################

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
