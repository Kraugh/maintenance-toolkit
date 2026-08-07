# MT4 Network Diagnostics foundation loader
# Baseline: NDP 0.0.19-RC
#
# Engine files are dot-sourced at loader scope so their functions survive
# after Import-MTNetworkDiagnosticsFoundation returns.

$MTNetworkRoot = $PSScriptRoot

foreach ($MTNetworkEngineFile in @(
    'RoutingAnalyzer.ps1',
    'TopologyEngine.ps1',
    'RulesEngine.ps1',
    'VPNDiagnostics.ps1',
    'NetworkHealth.ps1'
)) {
    $MTNetworkEnginePath = Join-Path $MTNetworkRoot $MTNetworkEngineFile

    if (-not (Test-Path -LiteralPath $MTNetworkEnginePath -PathType Leaf)) {
        throw "Network Diagnostics engine missing: $MTNetworkEngineFile"
    }

    . $MTNetworkEnginePath
}

function Import-MTNetworkDiagnosticsFoundation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectRoot
    )

    foreach ($CommandName in @(
        'Get-NDRoutingAnalysis',
        'Get-NDTopology',
        'Export-NDTopology',
        'Invoke-NDRules',
        'Get-MTNetworkVpnContext',
        'Get-MTNetworkHealthContext',
        'Invoke-MTNetworkRules'
    )) {
        if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
            throw "Network Diagnostics engine command missing: $CommandName"
        }
    }

    [pscustomobject]@{
        Baseline = 'NDP 0.0.19-RC'
        Loaded = $true
        Commands = @(
            'Get-NDRoutingAnalysis',
            'Get-NDTopology',
            'Export-NDTopology',
            'Invoke-NDRules',
            'Get-MTNetworkVpnContext',
            'Get-MTNetworkHealthContext',
            'Invoke-MTNetworkRules'
        )
    }
}
