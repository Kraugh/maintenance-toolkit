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

function Get-MTNetworkHealthContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Topology
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

    return [pscustomobject]@{
        CollectedAt = (Get-Date).ToString('o')
        EffectiveInterfaceIndex = $EffectiveInterfaceIndex
        GatewayProbe = $GatewayProbe
        ActiveApipaCount = $ApipaAddresses.Count
        ActiveApipaAddresses = $ApipaAddresses
        DNS = $DnsState
        DHCP = $DhcpState
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
