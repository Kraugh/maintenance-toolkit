# MT4 native Network Diagnostics actions
# Engine baseline: NDP 0.0.19-RC
#
# This file contains callable MT actions only. It never elevates, starts another
# PowerShell process, or opens a nested standalone NDP application.

function Get-MTNetworkText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$LanguageData,
        [Parameter(Mandatory)][string]$Key,
        [object[]]$Arguments = @()
    )

    Get-MTText `
        -LanguageData $LanguageData `
        -Key $Key `
        -Arguments $Arguments
}

function Write-MTNetworkStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Level,
        [Parameter(Mandatory)][string]$Label,
        [string]$Value = ""
    )

    $Prefix = switch ($Level) {
        "OK"       { "[OK]  " }
        "WARN"     { "[WARN]" }
        "ERROR"    { "[ERR] " }
        default    { "[INFO]" }
    }

    $Colour = switch ($Level) {
        "OK"       { "Green" }
        "WARN"     { "Yellow" }
        "ERROR"    { "Red" }
        default    { "Cyan" }
    }

    if ([string]::IsNullOrWhiteSpace($Value)) {
        Write-Host ("{0} {1}" -f $Prefix, $Label) -ForegroundColor $Colour
    }
    else {
        Write-Host ("{0} {1}: {2}" -f $Prefix, $Label, $Value) -ForegroundColor $Colour
    }
}

function Get-MTNetworkRoutingModeText {
    param(
        [Parameter(Mandatory)][object]$LanguageData,
        [string]$RoutingMode
    )

    $Key = switch ($RoutingMode) {
        "FullTunnelCandidate"  { "NETWORK_ROUTING_FULL" }
        "SplitTunnelCandidate" { "NETWORK_ROUTING_SPLIT" }
        "VPNWithoutRoutes"     { "NETWORK_ROUTING_VPN_NO_ROUTES" }
        default                { "NETWORK_ROUTING_NO_VPN" }
    }

    return Get-MTNetworkText `
        -LanguageData $LanguageData `
        -Key $Key
}

function Test-MTNetworkAdapterIsVirtual {
    [CmdletBinding()]
    param(
        [object]$Adapter
    )

    if ($null -eq $Adapter) {
        return $false
    }

    if ($Adapter.PSObject.Properties.Name -contains 'IsVirtual') {
        if ([bool]$Adapter.IsVirtual) {
            return $true
        }
    }

    $Text = "{0} {1}" -f `
        ([string]$Adapter.Name), `
        ([string]$Adapter.Description)

    return ($Text -match '(?i)hyper-v|vethernet|virtual|vmware|virtualbox|wsl')
}

function Get-MTNetworkPhysicalBackendPresentation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Topology,
        [Parameter(Mandatory)][object]$LanguageData
    )

    $LogicalAdapter = $Topology.EffectivePath.LogicalAdapter
    $PhysicalAdapter = $Topology.EffectivePath.PhysicalBackend
    $Candidates = @($Topology.EffectivePath.PhysicalBackendCandidates)
    $Source = [string]$Topology.EffectivePath.PhysicalBackendSource

    # NDP baseline can return the same virtual adapter as both logical and
    # physical backend in a Hyper-V guest. MT must not present that as a real
    # physical NIC when the guest cannot actually see the host adapter.
    if (
        $null -ne $LogicalAdapter -and
        $null -ne $PhysicalAdapter -and
        [int]$LogicalAdapter.InterfaceIndex -eq [int]$PhysicalAdapter.InterfaceIndex -and
        (Test-MTNetworkAdapterIsVirtual -Adapter $LogicalAdapter)
    ) {
        return [pscustomobject]@{
            State = 'GuestVirtualOnly'
            Label = Get-MTNetworkText $LanguageData "NETWORK_PHYSICAL_INTERFACE"
            Value = Get-MTNetworkText $LanguageData "NETWORK_PHYSICAL_NOT_VISIBLE_GUEST"
            Level = 'WARN'
        }
    }

    if ($null -ne $PhysicalAdapter) {
        return [pscustomobject]@{
            State = 'Resolved'
            Label = Get-MTNetworkText $LanguageData "NETWORK_PHYSICAL_INTERFACE"
            Value = ("{0} - {1}" -f $PhysicalAdapter.Name, $PhysicalAdapter.Description)
            Level = 'OK'
        }
    }

    if ($Candidates.Count -gt 1) {
        return [pscustomobject]@{
            State = 'Ambiguous'
            Label = Get-MTNetworkText $LanguageData "NETWORK_PHYSICAL_CANDIDATES"
            Value = (($Candidates | ForEach-Object Name) -join ", ")
            Level = 'WARN'
        }
    }

    return [pscustomobject]@{
        State = 'Unknown'
        Label = Get-MTNetworkText $LanguageData "NETWORK_PHYSICAL_INTERFACE"
        Value = Get-MTNetworkText $LanguageData "NETWORK_BACKEND_NOT_DETECTED"
        Level = 'WARN'
    }
}

function Get-MTNetworkRuleLevel {
    param([string]$Severity)

    switch ($Severity) {
        "Critical" { return "ERROR" }
        "Warning"  { return "WARN" }
        "Success"  { return "OK" }
        default    { return "INFO" }
    }
}

function Invoke-MTNetworkQuickDiagnosis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][object]$LanguageData,
        [switch]$SpeedTest
    )

    if (-not (Get-Command Get-NDTopology -ErrorAction SilentlyContinue)) {
        . (Join-Path $ProjectRoot 'app/modules/network/NetworkFoundation.ps1')
        $null = Import-MTNetworkDiagnosticsFoundation -ProjectRoot $ProjectRoot
    }

    $SettingsPath = Join-Path $ProjectRoot 'config/network.json'
    $RulesPath = Join-Path $ProjectRoot 'rules/network.json'

    $Settings = Get-Content `
        -LiteralPath $SettingsPath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    $RulesConfiguration = Get-Content `
        -LiteralPath $RulesPath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    Clear-Host
    Write-Host "============================================================"
    Write-Host (
        " {0} - {1}" -f
        (Get-MTNetworkText $LanguageData "MODULE_NETWORK_DIAGNOSTICS"),
        (Get-MTNetworkText $LanguageData "NETWORK_QUICK_DIAGNOSIS")
    )
    Write-Host "============================================================"
    Write-Host ""

    $Profile = Start-MTProfiler -Name "MTNetworkQuickDiagnosis"
    $PrivilegeState = Get-MTPrivilegeState

    Write-MTNetworkStatus `
        -Level "INFO" `
        -Label (Get-MTNetworkText $LanguageData "NETWORK_COMPUTER") `
        -Value $env:COMPUTERNAME

    Write-MTNetworkStatus `
        -Level $(if ($PrivilegeState.IsAdministrator) { "OK" } else { "WARN" }) `
        -Label (Get-MTNetworkText $LanguageData "NETWORK_ADMIN") `
        -Value $(if ($PrivilegeState.IsAdministrator) {
            Get-MTNetworkText $LanguageData "NETWORK_ADMIN_ACTIVE"
        } else {
            Get-MTNetworkText $LanguageData "NETWORK_ADMIN_MISSING"
        })

    $Topology = $null
    $Routing = $null
    $RuleEvaluation = $null

    try {
        $Step = Start-MTProfilerStep -Name "Topology"
        $Topology = Get-NDTopology -Settings $Settings
        $null = Stop-MTProfilerStep -Step $Step -Status "OK"
    }
    catch {
        $null = Stop-MTProfilerStep `
            -Step $Step `
            -Status "ERROR" `
            -Details $_.Exception.Message

        Write-MTNetworkStatus `
            -Level "ERROR" `
            -Label (Get-MTNetworkText $LanguageData "NETWORK_TOPOLOGY_ENGINE") `
            -Value $_.Exception.Message
    }

    try {
        $Step = Start-MTProfilerStep -Name "Routing"
        $Routing = Get-NDRoutingAnalysis -Settings $Settings
        $null = Stop-MTProfilerStep -Step $Step -Status "OK"
    }
    catch {
        $null = Stop-MTProfilerStep `
            -Step $Step `
            -Status "ERROR" `
            -Details $_.Exception.Message

        Write-MTNetworkStatus `
            -Level "ERROR" `
            -Label (Get-MTNetworkText $LanguageData "NETWORK_ROUTING_ENGINE") `
            -Value $_.Exception.Message
    }

    if ($null -ne $Topology) {
        try {
            $Step = Start-MTProfilerStep -Name "Rules"
            $RuleEvaluation = Invoke-NDRules `
                -Topology $Topology `
                -RulesConfiguration $RulesConfiguration
            $null = Stop-MTProfilerStep -Step $Step -Status "OK"
        }
        catch {
            $null = Stop-MTProfilerStep `
                -Step $Step `
                -Status "ERROR" `
                -Details $_.Exception.Message

            Write-MTNetworkStatus `
                -Level "ERROR" `
                -Label (Get-MTNetworkText $LanguageData "NETWORK_RULES_ENGINE") `
                -Value $_.Exception.Message
        }
    }

    if ($null -ne $Topology) {
        Write-Host ""
        Write-Host (
            Get-MTNetworkText $LanguageData "NETWORK_TOPOLOGY_SUMMARY"
        ) -ForegroundColor Cyan
        Write-Host ("-" * 72)

        $LogicalAdapter = $Topology.EffectivePath.LogicalAdapter
        $PhysicalAdapter = $Topology.EffectivePath.PhysicalBackend
        $Candidates = @($Topology.EffectivePath.PhysicalBackendCandidates)
        $HyperVSwitch = $Topology.EffectivePath.HyperVSwitch
        $DefaultRoute = $Topology.EffectivePath.DefaultRoute

        if ($null -ne $LogicalAdapter) {
            Write-MTNetworkStatus `
                -Level "INFO" `
                -Label (Get-MTNetworkText $LanguageData "NETWORK_LOGICAL_INTERFACE") `
                -Value ("{0} - {1}" -f $LogicalAdapter.Name, $LogicalAdapter.Description)
        }

        if (
            $null -ne $HyperVSwitch -and
            -not [string]::IsNullOrWhiteSpace([string]$HyperVSwitch.SwitchName)
        ) {
            Write-MTNetworkStatus `
                -Level "INFO" `
                -Label "Hyper-V vSwitch" `
                -Value ("{0} ({1})" -f $HyperVSwitch.SwitchName, $HyperVSwitch.SwitchType)
        }

        $BackendPresentation = Get-MTNetworkPhysicalBackendPresentation `
            -Topology $Topology `
            -LanguageData $LanguageData

        Write-MTNetworkStatus `
            -Level $BackendPresentation.Level `
            -Label $BackendPresentation.Label `
            -Value $BackendPresentation.Value

        if ($null -ne $DefaultRoute) {
            Write-MTNetworkStatus `
                -Level "OK" `
                -Label (Get-MTNetworkText $LanguageData "NETWORK_DEFAULT_GATEWAY") `
                -Value ([string]$DefaultRoute.NextHop)

            Write-MTNetworkStatus `
                -Level "INFO" `
                -Label (Get-MTNetworkText $LanguageData "NETWORK_TOTAL_METRIC") `
                -Value ([string]$DefaultRoute.TotalMetric)
        }

        Write-MTNetworkStatus `
            -Level "INFO" `
            -Label (Get-MTNetworkText $LanguageData "NETWORK_ROUTING_MODE") `
            -Value (
                Get-MTNetworkRoutingModeText `
                    -LanguageData $LanguageData `
                    -RoutingMode ([string]$Topology.Summary.RoutingModeCandidate)
            )

        Write-MTNetworkStatus `
            -Level "INFO" `
            -Label (Get-MTNetworkText $LanguageData "NETWORK_ACTIVE_VPN_COUNT") `
            -Value ([string]$Topology.Summary.ActiveVPNCount)

        Write-MTNetworkStatus `
            -Level "INFO" `
            -Label (Get-MTNetworkText $LanguageData "NETWORK_DEFAULT_ROUTE_COUNT") `
            -Value ([string]$Topology.Summary.DefaultRouteCount)

        Write-MTNetworkStatus `
            -Level "INFO" `
            -Label (Get-MTNetworkText $LanguageData "NETWORK_TOTAL_ROUTE_COUNT") `
            -Value ([string]$Topology.Summary.RouteCount)
    }

    if ($null -ne $RuleEvaluation) {
        Write-Host ""
        Write-Host (
            Get-MTNetworkText $LanguageData "NETWORK_AUTOMATIC_ANALYSIS"
        ) -ForegroundColor Cyan
        Write-Host ("-" * 72)

        $TriggeredRules = @($RuleEvaluation.Triggered)

        if ($TriggeredRules.Count -eq 0) {
            Write-MTNetworkStatus `
                -Level "OK" `
                -Label (Get-MTNetworkText $LanguageData "NETWORK_RULES_NONE")
        }
        else {
            foreach ($Rule in $TriggeredRules) {
                $Title = Get-MTNetworkText `
                    -LanguageData $LanguageData `
                    -Key ([string]$Rule.TitleKey)

                $Message = Get-MTNetworkText `
                    -LanguageData $LanguageData `
                    -Key ([string]$Rule.MessageKey)

                Write-MTNetworkStatus `
                    -Level (Get-MTNetworkRuleLevel $Rule.Severity) `
                    -Label ("{0} {1}" -f $Rule.Id, $Title) `
                    -Value $Message
            }
        }

        Write-MTNetworkStatus `
            -Level "INFO" `
            -Label (Get-MTNetworkText $LanguageData "NETWORK_RULES_COUNT") `
            -Value ([string]$TriggeredRules.Count)
    }

    $SpeedTestResult = $null

    if ($SpeedTest) {
        $SpeedStep = Start-MTProfilerStep -Name 'SpeedTest'

        $SpeedTestResult = Invoke-MTNetworkSpeedTest `
            -ProjectRoot $ProjectRoot `
            -LanguageData $LanguageData `
            -ShowProgress

        $SpeedStepStatus = if ($SpeedTestResult.Status -eq 'OK') {
            'OK'
        }
        elseif ($SpeedTestResult.Status -eq 'WARN') {
            'WARN'
        }
        else {
            'ERROR'
        }

        $null = Stop-MTProfilerStep `
            -Step $SpeedStep `
            -Status $SpeedStepStatus `
            -Details $SpeedTestResult.ErrorMessage

        Show-MTNetworkSpeedTestResult `
            -SpeedTestResult $SpeedTestResult `
            -LanguageData $LanguageData
    }

    $FinalProfile = Stop-MTProfiler

    Write-Host ""
    $DurationValue = if ([double]$FinalProfile.DurationMs -ge 1000) {
        "{0:N2} s" -f ([double]$FinalProfile.DurationMs / 1000)
    }
    else {
        "{0:N0} ms" -f [double]$FinalProfile.DurationMs
    }

    Write-MTNetworkStatus `
        -Level "INFO" `
        -Label (Get-MTNetworkText $LanguageData "NETWORK_DURATION") `
        -Value $DurationValue

    return [pscustomobject]@{
        Topology = $Topology
        Routing = $Routing
        Rules = $RuleEvaluation
        Profile = $FinalProfile
        SpeedTest = $SpeedTestResult
        Succeeded = ($null -ne $Topology)
    }
}
