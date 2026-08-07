# MT4 Network Health collector and rule-extension layer
# Baseline NDP engines remain unchanged; MT-specific health rules live here.

function Test-MTNetworkGatewayIcmp {
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Gateway,
        [int]$TimeoutMs = 1000
    )

    if (
        [string]::IsNullOrWhiteSpace($Gateway) -or
        $Gateway -eq '0.0.0.0'
    ) {
        return [pscustomobject]@{
            Attempted = $false
            Gateway = $Gateway
            Reachable = $null
            RoundtripTimeMs = $null
            Status = 'NotTested'
            Detail = $null
        }
    }

    $Ping = New-Object System.Net.NetworkInformation.Ping

    try {
        $Reply = $Ping.Send($Gateway, $TimeoutMs)
        $Reachable = (
            $null -ne $Reply -and
            $Reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success
        )

        return [pscustomobject]@{
            Attempted = $true
            Gateway = $Gateway
            Reachable = $Reachable
            RoundtripTimeMs = if ($Reachable) {
                [long]$Reply.RoundtripTime
            }
            else {
                $null
            }
            Status = if ($null -ne $Reply) {
                [string]$Reply.Status
            }
            else {
                'NoReply'
            }
            Detail = $null
        }
    }
    catch {
        return [pscustomobject]@{
            Attempted = $true
            Gateway = $Gateway
            Reachable = $false
            RoundtripTimeMs = $null
            Status = 'Error'
            Detail = $_.Exception.Message
        }
    }
    finally {
        $Ping.Dispose()
    }
}

function Get-MTNetworkEffectiveInterfaceIndex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Topology
    )

    if (
        $null -ne $Topology.EffectivePath.DefaultRoute -and
        $null -ne $Topology.EffectivePath.DefaultRoute.InterfaceIndex
    ) {
        return [int]$Topology.EffectivePath.DefaultRoute.InterfaceIndex
    }

    if (
        $null -ne $Topology.EffectivePath.LogicalAdapter -and
        $null -ne $Topology.EffectivePath.LogicalAdapter.InterfaceIndex
    ) {
        return [int]$Topology.EffectivePath.LogicalAdapter.InterfaceIndex
    }

    return $null
}

function Get-MTNetworkDnsHealthState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Topology,
        [AllowNull()][Nullable[int]]$InterfaceIndex
    )

    $Servers = @()

    if ($null -ne $InterfaceIndex) {
        $Servers = @(
            $Topology.DNS |
            Where-Object {
                [int]$_.InterfaceIndex -eq [int]$InterfaceIndex
            } |
            ForEach-Object {
                @($_.Servers)
            } |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace([string]$_)
            } |
            ForEach-Object {
                [string]$_
            }
        )
    }

    $Duplicates = @(
        $Servers |
        Group-Object |
        Where-Object Count -gt 1 |
        ForEach-Object {
            [pscustomobject]@{
                Server = [string]$_.Name
                Count = [int]$_.Count
            }
        }
    )

    return [pscustomobject]@{
        InterfaceIndex = $InterfaceIndex
        Servers = $Servers
        ServerCount = $Servers.Count
        DuplicateCount = $Duplicates.Count
        Duplicates = $Duplicates
    }
}

function Get-MTNetworkDhcpHealthState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Topology,
        [AllowNull()][Nullable[int]]$InterfaceIndex
    )

    $UsableIPv4 = @()
    if ($null -ne $InterfaceIndex) {
        $UsableIPv4 = @(
            $Topology.IPv4Addresses |
            Where-Object {
                [int]$_.InterfaceIndex -eq [int]$InterfaceIndex -and
                [string]$_.IPAddress -notlike '169.254.*' -and
                [string]$_.IPAddress -notlike '127.*'
            }
        )
    }

    $State = [ordered]@{
        InterfaceIndex = $InterfaceIndex
        Known = $false
        Enabled = $null
        Server = $null
        UsableIPv4Count = $UsableIPv4.Count
        UsableIPv4Addresses = @($UsableIPv4)
        Source = 'Unavailable'
        Detail = $null
    }

    if ($null -eq $InterfaceIndex) {
        return [pscustomobject]$State
    }

    try {
        $Configuration = Get-CimInstance `
            -ClassName Win32_NetworkAdapterConfiguration `
            -Filter ("InterfaceIndex={0}" -f [int]$InterfaceIndex) `
            -ErrorAction Stop |
            Select-Object -First 1

        if ($null -ne $Configuration) {
            $State.Known = $true
            $State.Enabled = [bool]$Configuration.DHCPEnabled
            $State.Server = [string]$Configuration.DHCPServer
            $State.Source = 'Win32_NetworkAdapterConfiguration'
        }
        else {
            $State.Detail = 'No matching Win32_NetworkAdapterConfiguration instance.'
        }
    }
    catch {
        $State.Detail = $_.Exception.Message
    }

    return [pscustomobject]$State
}

function ConvertTo-MTNetworkLinkSpeedMbps {
    [CmdletBinding()]
    param(
        [AllowNull()][string]$LinkSpeed
    )

    if ([string]::IsNullOrWhiteSpace($LinkSpeed)) {
        return $null
    }

    $Text = $LinkSpeed.Trim()

    if ($Text -match '^\s*([0-9]+(?:[\.,][0-9]+)?)\s*(Gbps|Mbps|Kbps|bps)\s*$') {
        $NumberText = $Matches[1].Replace(',', '.')
        $Value = [double]::Parse(
            $NumberText,
            [System.Globalization.CultureInfo]::InvariantCulture
        )

        switch ($Matches[2]) {
            'Gbps' { return [math]::Round($Value * 1000, 2) }
            'Mbps' { return [math]::Round($Value, 2) }
            'Kbps' { return [math]::Round($Value / 1000, 4) }
            'bps'  { return [math]::Round($Value / 1000000, 6) }
        }
    }

    return $null
}

function Get-MTNetworkEffectiveInterfaceHealthState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Topology,
        [AllowNull()][Nullable[int]]$InterfaceIndex
    )

    $State = [ordered]@{
        InterfaceIndex = $InterfaceIndex
        Known = $false
        Name = $null
        Description = $null
        IsVPN = $false
        IsVirtual = $false
        HardwareInterface = $false
        LinkSpeed = $null
        LinkSpeedMbps = $null
        MTU = $null
        InterfaceMetric = $null
        AutomaticMetric = $null
        ConnectionState = $null
        Source = 'Unavailable'
        Detail = $null
    }

    if ($null -eq $InterfaceIndex) {
        return [pscustomobject]$State
    }

    $Adapter = @(
        $Topology.Adapters |
        Where-Object {
            [int]$_.InterfaceIndex -eq [int]$InterfaceIndex
        }
    ) | Select-Object -First 1

    if ($null -ne $Adapter) {
        $State.Name = [string]$Adapter.Name
        $State.Description = [string]$Adapter.Description
        $State.IsVPN = [bool]$Adapter.IsVPN
        $State.IsVirtual = [bool]$Adapter.IsVirtual
        $State.HardwareInterface = [bool]$Adapter.HardwareInterface
        $State.LinkSpeed = [string]$Adapter.LinkSpeed
        $State.LinkSpeedMbps = ConvertTo-MTNetworkLinkSpeedMbps `
            -LinkSpeed ([string]$Adapter.LinkSpeed)
    }

    try {
        $IPInterface = Get-NetIPInterface `
            -AddressFamily IPv4 `
            -InterfaceIndex ([int]$InterfaceIndex) `
            -ErrorAction Stop |
            Select-Object -First 1

        if ($null -ne $IPInterface) {
            $State.Known = $true
            $State.MTU = [int]$IPInterface.NlMtu
            $State.InterfaceMetric = [int]$IPInterface.InterfaceMetric
            $State.AutomaticMetric = [string]$IPInterface.AutomaticMetric
            $State.ConnectionState = [string]$IPInterface.ConnectionState
            $State.Source = 'Get-NetIPInterface'
        }
        else {
            $State.Detail = 'No matching Get-NetIPInterface result.'
        }
    }
    catch {
        $State.Detail = $_.Exception.Message
    }

    return [pscustomobject]$State
}

function Get-MTNetworkDefaultRouteCompetitionState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Topology
    )

    $Routes = @($Topology.DefaultRoutes)

    if ($Routes.Count -eq 0) {
        return [pscustomobject]@{
            DefaultRouteCount = 0
            BestMetric = $null
            BestRouteCount = 0
            BestRoutes = @()
        }
    }

    $UsableMetrics = @(
        $Routes |
        Where-Object { $null -ne $_.TotalMetric } |
        ForEach-Object { [int]$_.TotalMetric }
    )

    if ($UsableMetrics.Count -eq 0) {
        return [pscustomobject]@{
            DefaultRouteCount = $Routes.Count
            BestMetric = $null
            BestRouteCount = 0
            BestRoutes = @()
        }
    }

    $BestMetric = ($UsableMetrics | Measure-Object -Minimum).Minimum
    $BestRoutes = @(
        $Routes |
        Where-Object {
            $null -ne $_.TotalMetric -and
            [int]$_.TotalMetric -eq [int]$BestMetric
        }
    )

    return [pscustomobject]@{
        DefaultRouteCount = $Routes.Count
        BestMetric = [int]$BestMetric
        BestRouteCount = $BestRoutes.Count
        BestRoutes = $BestRoutes
    }
}

function Test-MTNetworkDnsResolution {
    [CmdletBinding()]
    param(
        [string]$HostName = 'www.msftconnecttest.com'
    )

    if ([string]::IsNullOrWhiteSpace($HostName)) {
        return [pscustomobject]@{
            Attempted = $false
            HostName = $HostName
            Resolved = $null
            Addresses = @()
            AddressCount = 0
            Resolver = $null
            Detail = 'DNS probe target is empty.'
        }
    }

    try {
        $Addresses = @()

        if (Get-Command Resolve-DnsName -ErrorAction SilentlyContinue) {
            $Addresses = @(
                Resolve-DnsName `
                    -Name $HostName `
                    -Type A `
                    -DnsOnly `
                    -QuickTimeout `
                    -ErrorAction Stop |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace([string]$_.IPAddress)
                } |
                ForEach-Object {
                    [string]$_.IPAddress
                } |
                Select-Object -Unique
            )

            $Resolver = 'Resolve-DnsName'
        }
        else {
            $Addresses = @(
                [System.Net.Dns]::GetHostAddresses($HostName) |
                Where-Object {
                    $_.AddressFamily -eq
                        [System.Net.Sockets.AddressFamily]::InterNetwork
                } |
                ForEach-Object {
                    $_.IPAddressToString
                } |
                Select-Object -Unique
            )

            $Resolver = 'System.Net.Dns'
        }

        return [pscustomobject]@{
            Attempted = $true
            HostName = $HostName
            Resolved = ($Addresses.Count -gt 0)
            Addresses = $Addresses
            AddressCount = $Addresses.Count
            Resolver = $Resolver
            Detail = $null
        }
    }
    catch {
        return [pscustomobject]@{
            Attempted = $true
            HostName = $HostName
            Resolved = $false
            Addresses = @()
            AddressCount = 0
            Resolver = $null
            Detail = $_.Exception.Message
        }
    }
}

function Get-MTNetworkDnsProbeTarget {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Settings
    )

    $DefaultTarget = 'www.msftconnecttest.com'

    if ($null -eq $Settings) {
        return $DefaultTarget
    }

    $HealthProperty = $Settings.PSObject.Properties['Health']

    if ($null -eq $HealthProperty -or $null -eq $HealthProperty.Value) {
        return $DefaultTarget
    }

    $TargetProperty = $HealthProperty.Value.PSObject.Properties['DnsProbeHost']

    if (
        $null -eq $TargetProperty -or
        [string]::IsNullOrWhiteSpace([string]$TargetProperty.Value)
    ) {
        return $DefaultTarget
    }

    return [string]$TargetProperty.Value
}

function Get-MTNetworkHealthContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Topology,
        [AllowNull()][object]$Settings = $null
    )

    $Gateway = $null
    if ($null -ne $Topology.EffectivePath.DefaultRoute) {
        $Gateway = [string]$Topology.EffectivePath.DefaultRoute.NextHop
    }

    $GatewayProbe = Test-MTNetworkGatewayIcmp -Gateway $Gateway

    $AdapterByIndex = @{}
    foreach ($Adapter in @($Topology.Adapters)) {
        $AdapterByIndex[[int]$Adapter.InterfaceIndex] = $Adapter
    }

    $ApipaAddresses = @(
        foreach ($Address in @($Topology.IPv4Addresses)) {
            if ([string]$Address.IPAddress -notlike '169.254.*') {
                continue
            }

            $Adapter = $null
            if ($AdapterByIndex.ContainsKey([int]$Address.InterfaceIndex)) {
                $Adapter = $AdapterByIndex[[int]$Address.InterfaceIndex]
            }

            if (
                $null -ne $Adapter -and
                $Adapter.Status -eq 'Up' -and
                -not [bool]$Adapter.IsVPN
            ) {
                [pscustomobject]@{
                    InterfaceIndex = [int]$Address.InterfaceIndex
                    InterfaceAlias = [string]$Address.InterfaceAlias
                    IPAddress = [string]$Address.IPAddress
                    PrefixLength = [int]$Address.PrefixLength
                    AdapterName = [string]$Adapter.Name
                    AdapterDescription = [string]$Adapter.Description
                    IsVirtual = [bool]$Adapter.IsVirtual
                    PrefixOrigin = [string]$Address.PrefixOrigin
                }
            }
        }
    )

    $EffectiveInterfaceIndex = Get-MTNetworkEffectiveInterfaceIndex `
        -Topology $Topology

    $DnsState = Get-MTNetworkDnsHealthState `
        -Topology $Topology `
        -InterfaceIndex $EffectiveInterfaceIndex

    $DhcpState = Get-MTNetworkDhcpHealthState `
        -Topology $Topology `
        -InterfaceIndex $EffectiveInterfaceIndex

    $InterfaceState = Get-MTNetworkEffectiveInterfaceHealthState `
        -Topology $Topology `
        -InterfaceIndex $EffectiveInterfaceIndex

    $RouteCompetition = Get-MTNetworkDefaultRouteCompetitionState `
        -Topology $Topology

    $VpnState = Get-MTNetworkVpnContext -Topology $Topology

    $DnsProbeTarget = Get-MTNetworkDnsProbeTarget -Settings $Settings
    $DnsProbe = Test-MTNetworkDnsResolution -HostName $DnsProbeTarget

    return [pscustomobject]@{
        CollectedAt = (Get-Date).ToString('o')
        EffectiveInterfaceIndex = $EffectiveInterfaceIndex
        GatewayProbe = $GatewayProbe
        ActiveApipaCount = $ApipaAddresses.Count
        ActiveApipaAddresses = $ApipaAddresses
        DNS = $DnsState
        DHCP = $DhcpState
        EffectiveInterface = $InterfaceState
        DefaultRouteCompetition = $RouteCompetition
        VPN = $VpnState
        DnsProbe = $DnsProbe
    }
}

function Invoke-MTNetworkExtendedRules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Topology,
        [Parameter(Mandatory)][object]$Health,
        [Parameter(Mandatory)][object]$RulesConfiguration
    )

    $Results = New-Object System.Collections.ArrayList

    foreach ($Rule in @($RulesConfiguration.Rules)) {
        if (-not $Rule.Enabled) {
            continue
        }

        $Result = $null

        switch ([string]$Rule.Condition) {
            'GatewayNoIcmpResponse' {
                $Probe = $Health.GatewayProbe
                $Triggered = (
                    $null -ne $Probe -and
                    [bool]$Probe.Attempted -and
                    $Probe.Reachable -eq $false
                )

                $Result = New-NDRuleResult `
                    $Rule.Id `
                    $Rule.Severity `
                    $Triggered `
                    'NET003_TITLE' `
                    'NET003_MESSAGE' `
                    $Probe
            }

            'ActiveAdapterWithAPIPA' {
                $Triggered = ([int]$Health.ActiveApipaCount -gt 0)

                $Result = New-NDRuleResult `
                    $Rule.Id `
                    $Rule.Severity `
                    $Triggered `
                    'NET004_TITLE' `
                    'NET004_MESSAGE' `
                    ([pscustomobject]@{
                        ActiveApipaCount = [int]$Health.ActiveApipaCount
                        Addresses = @($Health.ActiveApipaAddresses)
                    })
            }

            'NoDnsServersOnEffectiveInterface' {
                $Triggered = (
                    $null -ne $Health.DNS -and
                    [int]$Health.DNS.ServerCount -eq 0
                )

                $Result = New-NDRuleResult `
                    $Rule.Id `
                    $Rule.Severity `
                    $Triggered `
                    'NET005_TITLE' `
                    'NET005_MESSAGE' `
                    $Health.DNS
            }

            'DuplicateDnsServersOnEffectiveInterface' {
                $Triggered = (
                    $null -ne $Health.DNS -and
                    [int]$Health.DNS.DuplicateCount -gt 0
                )

                $Result = New-NDRuleResult `
                    $Rule.Id `
                    $Rule.Severity `
                    $Triggered `
                    'NET006_TITLE' `
                    'NET006_MESSAGE' `
                    $Health.DNS
            }

            'DhcpDisabledWithoutUsableIPv4' {
                $Triggered = (
                    $null -ne $Health.DHCP -and
                    [bool]$Health.DHCP.Known -and
                    $Health.DHCP.Enabled -eq $false -and
                    [int]$Health.DHCP.UsableIPv4Count -eq 0
                )

                $Result = New-NDRuleResult `
                    $Rule.Id `
                    $Rule.Severity `
                    $Triggered `
                    'NET007_TITLE' `
                    'NET007_MESSAGE' `
                    $Health.DHCP
            }

            'LowMtuOnEffectiveNonVpnInterface' {
                $Interface = $Health.EffectiveInterface
                $Triggered = (
                    $null -ne $Interface -and
                    [bool]$Interface.Known -and
                    -not [bool]$Interface.IsVPN -and
                    $null -ne $Interface.MTU -and
                    [int]$Interface.MTU -lt 1280
                )

                $Result = New-NDRuleResult `
                    $Rule.Id `
                    $Rule.Severity `
                    $Triggered `
                    'NET008_TITLE' `
                    'NET008_MESSAGE' `
                    $Interface
            }

            'EqualCostCompetingDefaultRoutes' {
                $Competition = $Health.DefaultRouteCompetition
                $Triggered = (
                    $null -ne $Competition -and
                    [int]$Competition.BestRouteCount -gt 1
                )

                $Result = New-NDRuleResult `
                    $Rule.Id `
                    $Rule.Severity `
                    $Triggered `
                    'NET009_TITLE' `
                    'NET009_MESSAGE' `
                    $Competition
            }

            'LowLinkSpeedOnEffectivePhysicalInterface' {
                $Interface = $Health.EffectiveInterface
                $Triggered = (
                    $null -ne $Interface -and
                    -not [bool]$Interface.IsVPN -and
                    -not [bool]$Interface.IsVirtual -and
                    [bool]$Interface.HardwareInterface -and
                    $null -ne $Interface.LinkSpeedMbps -and
                    [double]$Interface.LinkSpeedMbps -le 10
                )

                $Result = New-NDRuleResult `
                    $Rule.Id `
                    $Rule.Severity `
                    $Triggered `
                    'NET010_TITLE' `
                    'NET010_MESSAGE' `
                    $Interface
            }

            'ActiveVpnWithoutTunnelIPv4' {
                $Triggered = (
                    $null -ne $Health.VPN -and
                    @($Health.VPN.ProfilesWithoutTunnelIPv4).Count -gt 0
                )

                $Result = New-NDRuleResult `
                    $Rule.Id `
                    $Rule.Severity `
                    $Triggered `
                    'VPN005_TITLE' `
                    'VPN005_MESSAGE' `
                    ([pscustomobject]@{
                        Count = @($Health.VPN.ProfilesWithoutTunnelIPv4).Count
                        Profiles = @($Health.VPN.ProfilesWithoutTunnelIPv4)
                    })
            }

            'ActiveVpnWithoutDns' {
                $Triggered = (
                    $null -ne $Health.VPN -and
                    @($Health.VPN.ProfilesWithoutDNS).Count -gt 0
                )

                $Result = New-NDRuleResult `
                    $Rule.Id `
                    $Rule.Severity `
                    $Triggered `
                    'VPN006_TITLE' `
                    'VPN006_MESSAGE' `
                    ([pscustomobject]@{
                        Count = @($Health.VPN.ProfilesWithoutDNS).Count
                        Profiles = @($Health.VPN.ProfilesWithoutDNS)
                    })
            }

            'ActiveVpnWithDuplicateRouteDestinations' {
                $Triggered = (
                    $null -ne $Health.VPN -and
                    @($Health.VPN.ProfilesWithDuplicateRoutes).Count -gt 0
                )

                $Result = New-NDRuleResult `
                    $Rule.Id `
                    $Rule.Severity `
                    $Triggered `
                    'VPN007_TITLE' `
                    'VPN007_MESSAGE' `
                    ([pscustomobject]@{
                        Count = @($Health.VPN.ProfilesWithDuplicateRoutes).Count
                        Profiles = @($Health.VPN.ProfilesWithDuplicateRoutes)
                    })
            }

            'ActiveVpnWithPublicDns' {
                $Triggered = (
                    $null -ne $Health.VPN -and
                    @($Health.VPN.ProfilesWithPublicDNS).Count -gt 0
                )

                $Result = New-NDRuleResult `
                    $Rule.Id `
                    $Rule.Severity `
                    $Triggered `
                    'VPN008_TITLE' `
                    'VPN008_MESSAGE' `
                    ([pscustomobject]@{
                        Count = @($Health.VPN.ProfilesWithPublicDNS).Count
                        Profiles = @($Health.VPN.ProfilesWithPublicDNS)
                    })
            }

            'ActiveVpnUnknownTechnology' {
                $Triggered = (
                    $null -ne $Health.VPN -and
                    @($Health.VPN.ProfilesWithUnknownTechnology).Count -gt 0
                )

                $Result = New-NDRuleResult `
                    $Rule.Id `
                    $Rule.Severity `
                    $Triggered `
                    'VPN009_TITLE' `
                    'VPN009_MESSAGE' `
                    ([pscustomobject]@{
                        Count = @($Health.VPN.ProfilesWithUnknownTechnology).Count
                        Profiles = @($Health.VPN.ProfilesWithUnknownTechnology)
                    })
            }

            'DnsResolutionFailed' {
                $ProbeProperty = $Health.PSObject.Properties['DnsProbe']
                $Probe = if ($null -ne $ProbeProperty) {
                    $ProbeProperty.Value
                }
                else {
                    $null
                }

                $Triggered = (
                    $null -ne $Probe -and
                    [bool]$Probe.Attempted -and
                    $Probe.Resolved -eq $false
                )

                $Result = New-NDRuleResult `
                    $Rule.Id `
                    $Rule.Severity `
                    $Triggered `
                    'NET011_TITLE' `
                    'NET011_MESSAGE' `
                    $Probe
            }
        }

        if ($null -ne $Result) {
            [void]$Results.Add($Result)
        }
    }

    return @($Results)
}

function Invoke-MTNetworkRules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Topology,
        [Parameter(Mandatory)][object]$Health,
        [Parameter(Mandatory)][object]$RulesConfiguration
    )

    $Baseline = Invoke-NDRules `
        -Topology $Topology `
        -RulesConfiguration $RulesConfiguration

    $Extended = @(
        Invoke-MTNetworkExtendedRules `
            -Topology $Topology `
            -Health $Health `
            -RulesConfiguration $RulesConfiguration
    )

    $Results = @($Baseline.Results) + $Extended
    $Triggered = @($Results | Where-Object Triggered)

    return [pscustomobject]@{
        EvaluatedAt = (Get-Date).ToString('o')
        RuleCount = $Results.Count
        TriggeredCount = $Triggered.Count
        Results = $Results
        Triggered = $Triggered
    }
}
