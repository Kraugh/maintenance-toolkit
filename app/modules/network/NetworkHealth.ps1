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

    return [pscustomobject]@{
        CollectedAt = (Get-Date).ToString('o')
        GatewayProbe = $GatewayProbe
        ActiveApipaCount = $ApipaAddresses.Count
        ActiveApipaAddresses = $ApipaAddresses
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
