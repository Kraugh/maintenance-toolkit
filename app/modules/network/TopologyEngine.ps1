function Test-NDTextPattern {
    param(
        [string]$Text,
        [object[]]$Patterns
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    foreach ($pattern in $Patterns) {
        if ($Text -match [regex]::Escape([string]$pattern)) {
            return $true
        }
    }

    return $false
}

function Get-NDHyperVBinding {
    param(
        [object]$LogicalAdapter,
        [object[]]$Adapters
    )

    $result = [pscustomobject]@{
        Available = $false
        SwitchName = $null
        SwitchType = $null
        NetAdapterInterfaceDescription = $null
        PhysicalAdapter = $null
        Source = $null
    }

    if ($null -eq $LogicalAdapter) {
        return $result
    }

    $getVMSwitch = Get-Command `
        -Name "Get-VMSwitch" `
        -ErrorAction SilentlyContinue

    if ($null -eq $getVMSwitch) {
        try {
            Import-Module `
                -Name "Hyper-V" `
                -ErrorAction Stop

            $getVMSwitch = Get-Command `
                -Name "Get-VMSwitch" `
                -ErrorAction SilentlyContinue
        }
        catch {
            return $result
        }
    }

    if ($null -eq $getVMSwitch) {
        return $result
    }

    try {
        $switches = @(
            & $getVMSwitch -ErrorAction Stop
        )

        $result.Available = $true

        $switchName = $null
        if ($LogicalAdapter.Name -match '^vEthernet \((.+)\)$') {
            $switchName = $Matches[1]
        }

        $matchedSwitch = $null

        if (-not [string]::IsNullOrWhiteSpace($switchName)) {
            $matchedSwitch = $switches |
                Where-Object { $_.Name -eq $switchName } |
                Select-Object -First 1
        }

        if ($null -eq $matchedSwitch) {
            $matchedSwitch = $switches |
                Where-Object {
                    $_.SwitchType -eq "External" -and
                    $_.NetAdapterInterfaceDescription
                } |
                Select-Object -First 1
        }

        if ($null -eq $matchedSwitch) {
            return $result
        }

        $result.SwitchName = [string]$matchedSwitch.Name
        $result.SwitchType = [string]$matchedSwitch.SwitchType
        $result.NetAdapterInterfaceDescription =
            [string]$matchedSwitch.NetAdapterInterfaceDescription
        $result.Source = "Get-VMSwitch"

        if (
            -not [string]::IsNullOrWhiteSpace(
                $result.NetAdapterInterfaceDescription
            )
        ) {
            $physical = @(
                $Adapters |
                    Where-Object {
                        $_.HardwareInterface -and
                        $_.Description -eq
                            $result.NetAdapterInterfaceDescription
                    }
            )

            if ($physical.Count -gt 0) {
                $result.PhysicalAdapter = $physical[0]
            }
        }
    }
    catch {
        # Hyper-V is optional. Failure is preserved as no authoritative binding.
    }

    return $result
}

function Get-NDTopology {
    param(
        [Parameter(Mandatory)]
        [object]$Settings
    )

    $rawAdapters = @(
        Get-NetAdapter -IncludeHidden -ErrorAction Stop
    )

    $rawInterfaces = @(
        Get-NetIPInterface `
            -AddressFamily IPv4 `
            -ErrorAction Stop
    )

    $rawAddresses = @(
        Get-NetIPAddress `
            -AddressFamily IPv4 `
            -ErrorAction SilentlyContinue
    )

    $rawDNS = @(
        Get-DnsClientServerAddress `
            -AddressFamily IPv4 `
            -ErrorAction SilentlyContinue
    )

    $rawRoutes = @(
        Get-NetRoute `
            -AddressFamily IPv4 `
            -ErrorAction Stop |
            Where-Object {
                @($Settings.Topology.ExcludeRouteStates) -notcontains
                    [string]$_.State
            }
    )

    $interfaceByIndex = @{}
    foreach ($interface in $rawInterfaces) {
        $interfaceByIndex[[int]$interface.InterfaceIndex] = $interface
    }

    $adapters = @(
        foreach ($adapter in $rawAdapters) {
            $text = "{0} {1}" -f `
                $adapter.Name,
                $adapter.InterfaceDescription

            [pscustomobject]@{
                InterfaceIndex = [int]$adapter.ifIndex
                Name = [string]$adapter.Name
                Description = [string]$adapter.InterfaceDescription
                InterfaceGuid = [string]$adapter.InterfaceGuid
                Status = [string]$adapter.Status
                LinkSpeed = [string]$adapter.LinkSpeed
                MacAddress = [string]$adapter.MacAddress
                HardwareInterface = [bool]$adapter.HardwareInterface
                IsVPN = Test-NDTextPattern `
                    -Text $text `
                    -Patterns @($Settings.Topology.VPNPatterns)
                IsVirtual = Test-NDTextPattern `
                    -Text $text `
                    -Patterns @($Settings.Topology.VirtualPatterns)
            }
        }
    )

    $routes = @(
        foreach ($route in $rawRoutes) {
            $interfaceMetric = $null

            if (
                $interfaceByIndex.ContainsKey(
                    [int]$route.InterfaceIndex
                )
            ) {
                $interfaceMetric = [int]$interfaceByIndex[
                    [int]$route.InterfaceIndex
                ].InterfaceMetric
            }

            [pscustomobject]@{
                DestinationPrefix = [string]$route.DestinationPrefix
                NextHop = [string]$route.NextHop
                InterfaceIndex = [int]$route.InterfaceIndex
                InterfaceAlias = [string]$route.InterfaceAlias
                RouteMetric = [int]$route.RouteMetric
                InterfaceMetric = $interfaceMetric
                TotalMetric = if ($null -ne $interfaceMetric) {
                    [int]$route.RouteMetric + $interfaceMetric
                }
                else {
                    $null
                }
                State = [string]$route.State
                PolicyStore = [string]$route.PolicyStore
                Protocol = [string]$route.Protocol
            }
        }
    )

    $defaultRoutes = @(
        $routes |
            Where-Object {
                $_.DestinationPrefix -eq "0.0.0.0/0"
            } |
            Sort-Object `
                @{
                    Expression = {
                        if ($null -eq $_.TotalMetric) {
                            [int]::MaxValue
                        }
                        else {
                            $_.TotalMetric
                        }
                    }
                },
                RouteMetric,
                InterfaceIndex
    )

    $effectiveDefaultRoute = $defaultRoutes |
        Select-Object -First 1

    $adapterByIndex = @{}
    foreach ($adapter in $adapters) {
        $adapterByIndex[[int]$adapter.InterfaceIndex] = $adapter
    }

    $logicalAdapter = $null
    if (
        $effectiveDefaultRoute -and
        $adapterByIndex.ContainsKey(
            [int]$effectiveDefaultRoute.InterfaceIndex
        )
    ) {
        $logicalAdapter = $adapterByIndex[
            [int]$effectiveDefaultRoute.InterfaceIndex
        ]
    }

    $activeVPNAdapters = @(
        $adapters |
            Where-Object {
                $_.IsVPN -and
                $_.Status -eq "Up"
            }
    )

    $activeVPNIndexes = @(
        $activeVPNAdapters |
            ForEach-Object {
                [int]$_.InterfaceIndex
            }
    )

    $vpnRoutes = @(
        $routes |
            Where-Object {
                $activeVPNIndexes -contains
                    [int]$_.InterfaceIndex
            } |
            Sort-Object DestinationPrefix, TotalMetric
    )

    $vpnSpecificRoutes = @(
        $vpnRoutes |
            Where-Object {
                $_.DestinationPrefix -ne "0.0.0.0/0" -and
                $_.DestinationPrefix -notlike "169.254.*"
            }
    )

    $vpnDefaultRoutes = @(
        $vpnRoutes |
            Where-Object {
                $_.DestinationPrefix -eq "0.0.0.0/0"
            }
    )

    $routingMode = "NoVPN"
    if ($activeVPNAdapters.Count -gt 0) {
        if ($vpnDefaultRoutes.Count -gt 0) {
            $routingMode = "FullTunnelCandidate"
        }
        elseif ($vpnSpecificRoutes.Count -gt 0) {
            $routingMode = "SplitTunnelCandidate"
        }
        else {
            $routingMode = "VPNWithoutRoutes"
        }
    }

    $hyperVBinding = Get-NDHyperVBinding `
        -LogicalAdapter $logicalAdapter `
        -Adapters $adapters

    $physicalBackendCandidates = @()
    $physicalBackend = $null
    $physicalBackendSource = $null

    if ($null -ne $hyperVBinding.PhysicalAdapter) {
        $physicalBackend = $hyperVBinding.PhysicalAdapter
        $physicalBackendCandidates = @($physicalBackend)
        $physicalBackendSource = "Get-VMSwitch"
    }
    elseif ($logicalAdapter) {
        if ($logicalAdapter.HardwareInterface) {
            $physicalBackend = $logicalAdapter
            $physicalBackendCandidates = @($logicalAdapter)
            $physicalBackendSource = "LogicalAdapter"
        }
        elseif ($logicalAdapter.MacAddress) {
            $physicalBackendCandidates = @(
                $adapters |
                    Where-Object {
                        $_.HardwareInterface -and
                        $_.Status -eq "Up" -and
                        $_.MacAddress -eq
                            $logicalAdapter.MacAddress
                    }
            )

            if ($physicalBackendCandidates.Count -eq 1) {
                $physicalBackend = $physicalBackendCandidates[0]
                $physicalBackendSource = "MacAddress"
            }
            elseif ($physicalBackendCandidates.Count -gt 1) {
                $physicalBackendSource = "MacAddressAmbiguous"
            }
        }
    }

    $addresses = @(
        foreach ($address in $rawAddresses) {
            [pscustomobject]@{
                InterfaceIndex = [int]$address.InterfaceIndex
                InterfaceAlias = [string]$address.InterfaceAlias
                IPAddress = [string]$address.IPAddress
                PrefixLength = [int]$address.PrefixLength
                PrefixOrigin = [string]$address.PrefixOrigin
                SuffixOrigin = [string]$address.SuffixOrigin
                AddressState = [string]$address.AddressState
            }
        }
    )

    $dns = @(
        foreach ($item in $rawDNS) {
            [pscustomobject]@{
                InterfaceIndex = [int]$item.InterfaceIndex
                InterfaceAlias = [string]$item.InterfaceAlias
                Servers = @($item.ServerAddresses)
            }
        }
    )

    return [pscustomobject]@{
        SchemaVersion = "1.1"
        CollectedAt = (Get-Date).ToString("o")
        ComputerName = $env:COMPUTERNAME
        UserName = "$env:USERDOMAIN\$env:USERNAME"
        UICulture = (Get-UICulture).Name

        Summary = [pscustomobject]@{
            AdapterCount = $adapters.Count
            ActiveAdapterCount = @(
                $adapters |
                    Where-Object {
                        $_.Status -eq "Up"
                    }
            ).Count
            RouteCount = $routes.Count
            DefaultRouteCount = $defaultRoutes.Count
            ActiveVPNCount = $activeVPNAdapters.Count
            VPNRouteCount = $vpnRoutes.Count
            VPNSpecificRouteCount = $vpnSpecificRoutes.Count
            RoutingModeCandidate = $routingMode
            PhysicalBackendResolved = $null -ne $physicalBackend
            PhysicalBackendSource = $physicalBackendSource
        }

        EffectivePath = [pscustomobject]@{
            DefaultRoute = $effectiveDefaultRoute
            LogicalAdapter = $logicalAdapter
            HyperVSwitch = $hyperVBinding
            PhysicalBackend = $physicalBackend
            PhysicalBackendCandidates = $physicalBackendCandidates
            PhysicalBackendSource = $physicalBackendSource
        }

        Adapters = $adapters
        IPv4Addresses = $addresses
        DNS = $dns
        DefaultRoutes = $defaultRoutes
        ActiveVPNAdapters = $activeVPNAdapters
        VPNRoutes = $vpnRoutes
        VPNSpecificRoutes = $vpnSpecificRoutes
        Routes = if ($Settings.Topology.IncludeAllIPv4Routes) {
            $routes
        }
        else {
            @()
        }
    }
}

function Export-NDTopology {
    param(
        [Parameter(Mandatory)]
        [object]$Topology,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $directory = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item `
            -ItemType Directory `
            -Path $directory `
            -Force |
            Out-Null
    }

    $Topology |
        ConvertTo-Json -Depth 14 |
        Set-Content `
            -LiteralPath $Path `
            -Encoding UTF8

    return $Path
}
