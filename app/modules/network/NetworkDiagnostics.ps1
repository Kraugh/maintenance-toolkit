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
    $Health = $null

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
            $Step = Start-MTProfilerStep -Name "Health"
            $Health = Get-MTNetworkHealthContext -Topology $Topology -Settings $Settings
            $null = Stop-MTProfilerStep -Step $Step -Status "OK"
        }
        catch {
            $null = Stop-MTProfilerStep `
                -Step $Step `
                -Status "ERROR" `
                -Details $_.Exception.Message

            Write-MTNetworkStatus `
                -Level "ERROR" `
                -Label (Get-MTNetworkText $LanguageData "NETWORK_HEALTH_SUMMARY") `
                -Value $_.Exception.Message
        }
    }

    if ($null -ne $Topology -and $null -ne $Health) {
        try {
            $Step = Start-MTProfilerStep -Name "Rules"
            $RuleEvaluation = Invoke-MTNetworkRules `
                -Topology $Topology `
                -Health $Health `
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

    if ($null -ne $Health) {
        Write-Host ""
        Write-Host (
            Get-MTNetworkText $LanguageData "NETWORK_HEALTH_SUMMARY"
        ) -ForegroundColor Cyan
        Write-Host ("-" * 72)

        $GatewayProbe = $Health.GatewayProbe
        $GatewayLevel = if (-not $GatewayProbe.Attempted) {
            "INFO"
        }
        elseif ($GatewayProbe.Reachable) {
            "OK"
        }
        else {
            "WARN"
        }

        $GatewayValue = if (-not $GatewayProbe.Attempted) {
            Get-MTNetworkText $LanguageData "NETWORK_GATEWAY_ICMP_NOT_TESTED"
        }
        elseif ($GatewayProbe.Reachable) {
            Get-MTNetworkText `
                -LanguageData $LanguageData `
                -Key "NETWORK_GATEWAY_ICMP_OK" `
                -Arguments @($GatewayProbe.RoundtripTimeMs)
        }
        else {
            Get-MTNetworkText $LanguageData "NETWORK_GATEWAY_ICMP_NO_REPLY"
        }

        Write-MTNetworkStatus `
            -Level $GatewayLevel `
            -Label (Get-MTNetworkText $LanguageData "NETWORK_GATEWAY_ICMP") `
            -Value $GatewayValue

        Write-MTNetworkStatus `
            -Level $(if ([int]$Health.ActiveApipaCount -gt 0) { "WARN" } else { "OK" }) `
            -Label (Get-MTNetworkText $LanguageData "NETWORK_APIPA_COUNT") `
            -Value ([string]$Health.ActiveApipaCount)

        $DnsValue = if ([int]$Health.DNS.ServerCount -gt 0) {
            @($Health.DNS.Servers) -join ", "
        }
        else {
            Get-MTNetworkText $LanguageData "NETWORK_DNS_NONE"
        }

        Write-MTNetworkStatus `
            -Level $(if ([int]$Health.DNS.ServerCount -eq 0) { "WARN" } else { "OK" }) `
            -Label (Get-MTNetworkText $LanguageData "NETWORK_DNS_SERVERS") `
            -Value $DnsValue

        Write-MTNetworkStatus `
            -Level $(if ([int]$Health.DNS.DuplicateCount -gt 0) { "WARN" } else { "OK" }) `
            -Label (Get-MTNetworkText $LanguageData "NETWORK_DNS_DUPLICATE_COUNT") `
            -Value ([string]$Health.DNS.DuplicateCount)

        if ($null -ne $Health.DnsProbe) {
            $DnsProbeValue = if ($Health.DnsProbe.Resolved) {
                Get-MTNetworkText `
                    -LanguageData $LanguageData `
                    -Key "NETWORK_DNS_PROBE_OK" `
                    -Arguments @(
                        $Health.DnsProbe.HostName,
                        (@($Health.DnsProbe.Addresses) -join ", ")
                    )
            }
            else {
                Get-MTNetworkText `
                    -LanguageData $LanguageData `
                    -Key "NETWORK_DNS_PROBE_FAILED" `
                    -Arguments @($Health.DnsProbe.HostName)
            }

            Write-MTNetworkStatus `
                -Level $(if ($Health.DnsProbe.Resolved) { "OK" } else { "WARN" }) `
                -Label (Get-MTNetworkText $LanguageData "NETWORK_DNS_PROBE") `
                -Value $DnsProbeValue
        }

        $DhcpText = if (-not [bool]$Health.DHCP.Known) {
            Get-MTNetworkText $LanguageData "NETWORK_DHCP_UNKNOWN"
        }
        elseif ([bool]$Health.DHCP.Enabled) {
            Get-MTNetworkText $LanguageData "NETWORK_DHCP_ENABLED"
        }
        else {
            Get-MTNetworkText $LanguageData "NETWORK_DHCP_DISABLED"
        }

        Write-MTNetworkStatus `
            -Level $(if ([bool]$Health.DHCP.Known) { "INFO" } else { "WARN" }) `
            -Label (Get-MTNetworkText $LanguageData "NETWORK_DHCP_STATE") `
            -Value $DhcpText

        if (
            [bool]$Health.DHCP.Known -and
            [bool]$Health.DHCP.Enabled -and
            -not [string]::IsNullOrWhiteSpace([string]$Health.DHCP.Server)
        ) {
            Write-MTNetworkStatus `
                -Level "INFO" `
                -Label (Get-MTNetworkText $LanguageData "NETWORK_DHCP_SERVER") `
                -Value ([string]$Health.DHCP.Server)
        }

        if (
            $null -ne $Health.EffectiveInterface -and
            [bool]$Health.EffectiveInterface.Known
        ) {
            Write-MTNetworkStatus `
                -Level $(if (
                    -not [bool]$Health.EffectiveInterface.IsVPN -and
                    $null -ne $Health.EffectiveInterface.MTU -and
                    [int]$Health.EffectiveInterface.MTU -lt 1280
                ) { "WARN" } else { "INFO" }) `
                -Label (Get-MTNetworkText $LanguageData "NETWORK_EFFECTIVE_MTU") `
                -Value ([string]$Health.EffectiveInterface.MTU)

            Write-MTNetworkStatus `
                -Level "INFO" `
                -Label (Get-MTNetworkText $LanguageData "NETWORK_EFFECTIVE_METRIC") `
                -Value ([string]$Health.EffectiveInterface.InterfaceMetric)

            if (
                -not [string]::IsNullOrWhiteSpace(
                    [string]$Health.EffectiveInterface.LinkSpeed
                )
            ) {
                Write-MTNetworkStatus `
                    -Level $(if (
                        -not [bool]$Health.EffectiveInterface.IsVPN -and
                        -not [bool]$Health.EffectiveInterface.IsVirtual -and
                        [bool]$Health.EffectiveInterface.HardwareInterface -and
                        $null -ne $Health.EffectiveInterface.LinkSpeedMbps -and
                        [double]$Health.EffectiveInterface.LinkSpeedMbps -le 10
                    ) { "WARN" } else { "INFO" }) `
                    -Label (Get-MTNetworkText $LanguageData "NETWORK_EFFECTIVE_LINK_SPEED") `
                    -Value ([string]$Health.EffectiveInterface.LinkSpeed)
            }
        }

        if ($null -ne $Health.DefaultRouteCompetition) {
            Write-MTNetworkStatus `
                -Level $(if (
                    [int]$Health.DefaultRouteCompetition.BestRouteCount -gt 1
                ) { "WARN" } else { "OK" }) `
                -Label (Get-MTNetworkText $LanguageData "NETWORK_BEST_DEFAULT_ROUTE_COUNT") `
                -Value ([string]$Health.DefaultRouteCompetition.BestRouteCount)
        }
    }

    if (
        $null -ne $Health -and
        $null -ne $Health.VPN
    ) {
        Write-Host ""
        Write-Host (
            Get-MTNetworkText $LanguageData "NETWORK_VPN_HEALTH"
        ) -ForegroundColor Cyan
        Write-Host ("-" * 72)

        if ([int]$Health.VPN.ActiveVPNCount -eq 0) {
            Write-MTNetworkStatus `
                -Level "INFO" `
                -Label (Get-MTNetworkText $LanguageData "NETWORK_VPN_PROFILE") `
                -Value (Get-MTNetworkText $LanguageData "NETWORK_VPN_NONE")
        }
        else {
            foreach ($VPN in @($Health.VPN.Profiles)) {
                Write-MTNetworkStatus `
                    -Level "OK" `
                    -Label (Get-MTNetworkText $LanguageData "NETWORK_VPN_PROFILE") `
                    -Value ("{0} - {1}" -f $VPN.Name, $VPN.Description)

                Write-MTNetworkStatus `
                    -Level $(if ([bool]$VPN.TechnologyMatched) { "INFO" } else { "WARN" }) `
                    -Label (Get-MTNetworkText $LanguageData "NETWORK_VPN_TECHNOLOGY") `
                    -Value ([string]$VPN.Technology)

                if ([bool]$VPN.TechnologyMatched) {
                    Write-MTNetworkStatus `
                        -Level "INFO" `
                        -Label (Get-MTNetworkText $LanguageData "NETWORK_VPN_VENDOR") `
                        -Value ([string]$VPN.Vendor)
                }

                Write-MTNetworkStatus `
                    -Level "INFO" `
                    -Label (Get-MTNetworkText $LanguageData "NETWORK_VPN_MODE") `
                    -Value ([string]$VPN.Mode)

                $TunnelIPs = @($VPN.TunnelIPv4 | ForEach-Object IPAddress)
                Write-MTNetworkStatus `
                    -Level $(if ($TunnelIPs.Count -gt 0) { "OK" } else { "WARN" }) `
                    -Label (Get-MTNetworkText $LanguageData "NETWORK_VPN_TUNNEL_IP") `
                    -Value $(if ($TunnelIPs.Count -gt 0) {
                        $TunnelIPs -join ", "
                    } else {
                        Get-MTNetworkText $LanguageData "NETWORK_VPN_NO_VALUE"
                    })

                Write-MTNetworkStatus `
                    -Level $(if ([int]$VPN.DNSServerCount -gt 0) { "INFO" } else { "WARN" }) `
                    -Label (Get-MTNetworkText $LanguageData "NETWORK_VPN_DNS") `
                    -Value $(if ([int]$VPN.DNSServerCount -gt 0) {
                        @($VPN.DNSServers) -join ", "
                    } else {
                        Get-MTNetworkText $LanguageData "NETWORK_VPN_NO_VALUE"
                    })

                Write-MTNetworkStatus `
                    -Level "INFO" `
                    -Label (Get-MTNetworkText $LanguageData "NETWORK_VPN_ROUTES") `
                    -Value ([string]$VPN.RouteCount)

                Write-MTNetworkStatus `
                    -Level "INFO" `
                    -Label (Get-MTNetworkText $LanguageData "NETWORK_VPN_SPECIFIC_ROUTES") `
                    -Value ([string]$VPN.SpecificRouteCount)

                Write-MTNetworkStatus `
                    -Level "INFO" `
                    -Label (Get-MTNetworkText $LanguageData "NETWORK_VPN_DEFAULT_ROUTES") `
                    -Value ([string]$VPN.DefaultRouteCount)

                Write-MTNetworkStatus `
                    -Level $(if ([int]$VPN.DuplicateRouteDestinationCount -gt 0) {
                        "WARN"
                    } else {
                        "OK"
                    }) `
                    -Label (Get-MTNetworkText $LanguageData "NETWORK_VPN_DUPLICATE_ROUTES") `
                    -Value ([string]$VPN.DuplicateRouteDestinationCount)

                if ([int]$VPN.PublicDNSServerCount -gt 0) {
                    Write-MTNetworkStatus `
                        -Level "INFO" `
                        -Label (Get-MTNetworkText $LanguageData "NETWORK_VPN_PUBLIC_DNS") `
                        -Value (@($VPN.PublicDNSServers) -join ", ")
                }

                if ($null -ne $VPN.MTU) {
                    Write-MTNetworkStatus `
                        -Level "INFO" `
                        -Label (Get-MTNetworkText $LanguageData "NETWORK_VPN_MTU") `
                        -Value ([string]$VPN.MTU)
                }

                if ($null -ne $VPN.InterfaceMetric) {
                    Write-MTNetworkStatus `
                        -Level "INFO" `
                        -Label (Get-MTNetworkText $LanguageData "NETWORK_VPN_METRIC") `
                        -Value ([string]$VPN.InterfaceMetric)
                }
            }
        }
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

        $CriticalCount = @($TriggeredRules | Where-Object Severity -eq 'Critical').Count
        $WarningCount = @($TriggeredRules | Where-Object Severity -eq 'Warning').Count

        $OutcomeLevel = if ($CriticalCount -gt 0) {
            'ERROR'
        }
        elseif ($WarningCount -gt 0) {
            'WARN'
        }
        else {
            'OK'
        }

        Write-MTNetworkStatus `
            -Level $OutcomeLevel `
            -Label (Get-MTNetworkText $LanguageData 'NETWORK_DIAGNOSTIC_OUTCOME') `
            -Value (Get-MTNetworkText `
                -LanguageData $LanguageData `
                -Key 'NETWORK_DIAGNOSTIC_OUTCOME_VALUE' `
                -Arguments @($CriticalCount, $WarningCount, $TriggeredRules.Count))
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
        Health = $Health
        Profile = $FinalProfile
        SpeedTest = $SpeedTestResult
        Succeeded = ($null -ne $Topology)
    }
}
