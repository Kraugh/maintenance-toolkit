function Test-NDPatternMatch {
    param(
        [string]$Text,
        [object[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        if ($Text -match [regex]::Escape([string]$pattern)) {
            return $true
        }
    }

    return $false
}

function Get-NDRoutingAnalysis {
    param(
        [Parameter(Mandatory)]
        [object]$Settings
    )

    $adapters = @(
        Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue
    )

    $ipInterfaces = @(
        Get-NetIPInterface -AddressFamily IPv4 -ErrorAction SilentlyContinue
    )

    $routes = @(
        Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object {
                $_.State -eq "Alive" -and
                $_.DestinationPrefix -ne "255.255.255.255/32"
            }
    )

    $adapterByIndex = @{}
    foreach ($adapter in $adapters) {
        $adapterByIndex[[int]$adapter.ifIndex] = $adapter
    }

    $interfaceByIndex = @{}
    foreach ($item in $ipInterfaces) {
        $interfaceByIndex[[int]$item.InterfaceIndex] = $item
    }

    $defaultRoutes = @(
        $routes |
            Where-Object { $_.DestinationPrefix -eq "0.0.0.0/0" } |
            ForEach-Object {
                $interfaceMetric = 0
                if ($interfaceByIndex.ContainsKey([int]$_.InterfaceIndex)) {
                    $interfaceMetric = [int]$interfaceByIndex[[int]$_.InterfaceIndex].InterfaceMetric
                }

                [pscustomobject]@{
                    DestinationPrefix = $_.DestinationPrefix
                    NextHop = $_.NextHop
                    InterfaceIndex = [int]$_.InterfaceIndex
                    InterfaceAlias = $_.InterfaceAlias
                    RouteMetric = [int]$_.RouteMetric
                    InterfaceMetric = $interfaceMetric
                    TotalMetric = ([int]$_.RouteMetric + $interfaceMetric)
                }
            } |
            Sort-Object TotalMetric, RouteMetric
    )

    $selectedDefault = $defaultRoutes | Select-Object -First 1
    $selectedAdapter = $null
    if ($selectedDefault -and $adapterByIndex.ContainsKey([int]$selectedDefault.InterfaceIndex)) {
        $selectedAdapter = $adapterByIndex[[int]$selectedDefault.InterfaceIndex]
    }

    $vpnPatterns = @($Settings.Routing.VPNNamePatterns)
    $virtualPatterns = @($Settings.Routing.VirtualAdapterPatterns)

    $vpnAdapters = @(
        $adapters |
            Where-Object {
                Test-NDPatternMatch `
                    -Text ("{0} {1}" -f $_.Name, $_.InterfaceDescription) `
                    -Patterns $vpnPatterns
            }
    )

    $activeVpnAdapters = @(
        $vpnAdapters | Where-Object { $_.Status -eq "Up" }
    )

    $vpnIndexes = @(
        $activeVpnAdapters | ForEach-Object { [int]$_.ifIndex }
    )

    $vpnRoutes = @(
        $routes |
            Where-Object {
                $vpnIndexes -contains [int]$_.InterfaceIndex -and
                $_.DestinationPrefix -ne "0.0.0.0/0" -and
                $_.DestinationPrefix -notlike "169.254.*"
            } |
            Sort-Object DestinationPrefix
    )

    $vpnDefaultRoute = $false
    if ($selectedDefault) {
        $vpnDefaultRoute = $vpnIndexes -contains [int]$selectedDefault.InterfaceIndex
    }

    $routingMode = "NoVPN"
    if ($activeVpnAdapters.Count -gt 0) {
        if ($vpnDefaultRoute) {
            $routingMode = "FullTunnel"
        }
        elseif ($vpnRoutes.Count -gt 0) {
            $routingMode = "SplitTunnel"
        }
        else {
            $routingMode = "VPNWithoutRoutes"
        }
    }

    $isVirtualRoutingAdapter = $false
    if ($selectedAdapter) {
        $isVirtualRoutingAdapter = Test-NDPatternMatch `
            -Text ("{0} {1}" -f $selectedAdapter.Name, $selectedAdapter.InterfaceDescription) `
            -Patterns $virtualPatterns
    }

    $physicalBackend = $null

    if ($isVirtualRoutingAdapter -and $selectedAdapter) {
        # Hyper-V external switches often preserve the physical adapter MAC
        # on the host vEthernet interface. Use this as the first correlation.
        $sameMacCandidates = @(
            $adapters |
                Where-Object {
                    $_.Status -eq "Up" -and
                    $_.HardwareInterface -eq $true -and
                    $_.MacAddress -and
                    $_.MacAddress -eq $selectedAdapter.MacAddress
                }
        )

        if ($sameMacCandidates.Count -gt 0) {
            $physicalBackend = $sameMacCandidates | Select-Object -First 1
        }
        else {
            $upPhysical = @(
                $adapters |
                    Where-Object {
                        $_.Status -eq "Up" -and
                        $_.HardwareInterface -eq $true
                    }
            )

            if ($upPhysical.Count -eq 1) {
                $physicalBackend = $upPhysical[0]
            }
        }
    }
    elseif ($selectedAdapter -and $selectedAdapter.HardwareInterface) {
        $physicalBackend = $selectedAdapter
    }

    return [pscustomobject]@{
        DefaultRoutes = $defaultRoutes
        SelectedDefaultRoute = $selectedDefault
        RoutingAdapter = $selectedAdapter
        RoutingAdapterIsVirtual = $isVirtualRoutingAdapter
        PhysicalBackend = $physicalBackend
        VPNAdapters = $vpnAdapters
        ActiveVPNAdapters = $activeVpnAdapters
        VPNRoutes = $vpnRoutes
        VPNDefaultRoute = $vpnDefaultRoute
        RoutingMode = $routingMode
        AllRoutes = $routes
    }
}

function Show-NDRoutingAnalysis {
    param(
        [Parameter(Mandatory)]
        [object]$Analysis,
        [Parameter(Mandatory)]
        [object]$LanguageData,
        [Parameter(Mandatory)]
        [object]$Settings
    )

    Write-NDHeader (Get-NDText $LanguageData "ROUTING_ANALYSIS")

    if ($Analysis.SelectedDefaultRoute) {
        Write-NDStatus `
            -Level Success `
            -Label (Get-NDText $LanguageData "ROUTING_INTERFACE") `
            -Value $Analysis.SelectedDefaultRoute.InterfaceAlias | Out-Null

        Write-NDStatus `
            -Level Info `
            -Label (Get-NDText $LanguageData "DEFAULT_GATEWAY") `
            -Value $Analysis.SelectedDefaultRoute.NextHop | Out-Null

        Write-NDStatus `
            -Level Info `
            -Label (Get-NDText $LanguageData "TOTAL_METRIC") `
            -Value ([string]$Analysis.SelectedDefaultRoute.TotalMetric) | Out-Null
    }

    if ($Analysis.RoutingAdapterIsVirtual) {
        Write-NDStatus `
            -Level Info `
            -Label (Get-NDText $LanguageData "LOGICAL_INTERFACE") `
            -Value $Analysis.RoutingAdapter.InterfaceDescription | Out-Null

        if ($Analysis.PhysicalBackend) {
            Write-NDStatus `
                -Level Success `
                -Label (Get-NDText $LanguageData "PHYSICAL_INTERFACE") `
                -Value ("{0} - {1}" -f
                    $Analysis.PhysicalBackend.Name,
                    $Analysis.PhysicalBackend.InterfaceDescription
                ) | Out-Null
        }
        else {
            Write-NDStatus `
                -Level Warning `
                -Label (Get-NDText $LanguageData "PHYSICAL_INTERFACE") `
                -Value (Get-NDText $LanguageData "BACKEND_NOT_DETECTED") | Out-Null
        }
    }

    switch ($Analysis.RoutingMode) {
        "FullTunnel" {
            Write-NDStatus `
                -Level Success `
                -Label (Get-NDText $LanguageData "ROUTING_MODE") `
                -Value (Get-NDText $LanguageData "FULL_TUNNEL") | Out-Null
        }
        "SplitTunnel" {
            Write-NDStatus `
                -Level Success `
                -Label (Get-NDText $LanguageData "ROUTING_MODE") `
                -Value (Get-NDText $LanguageData "SPLIT_TUNNEL") | Out-Null
        }
        "VPNWithoutRoutes" {
            Write-NDStatus `
                -Level Warning `
                -Label (Get-NDText $LanguageData "ROUTING_MODE") `
                -Value (Get-NDText $LanguageData "VPN_ROUTE_WARNING") | Out-Null
        }
        default {
            Write-NDStatus `
                -Level Info `
                -Label (Get-NDText $LanguageData "ROUTING_MODE") `
                -Value (Get-NDText $LanguageData "NO_VPN_ROUTE") | Out-Null
        }
    }

    if ($Analysis.ActiveVPNAdapters.Count -gt 0) {
        Write-NDStatus `
            -Level Success `
            -Label (Get-NDText $LanguageData "VPN_ACTIVE") `
            -Value (($Analysis.ActiveVPNAdapters.Name) -join ", ") | Out-Null
    }

    if ($Analysis.VPNRoutes.Count -gt 0) {
        Write-Host ""
        Write-Host (Get-NDText $LanguageData "VPN_SPECIFIC_ROUTES") -ForegroundColor Cyan

        $maxRoutes = [int]$Settings.Routing.MaxDisplayedRoutes
        $displayRoutes = @($Analysis.VPNRoutes | Select-Object -First $maxRoutes)

        foreach ($route in $displayRoutes) {
            Write-Host (
                "  {0,-22} -> {1,-15} ({2})" -f
                $route.DestinationPrefix,
                $route.NextHop,
                $route.InterfaceAlias
            )
        }

        if ($Analysis.VPNRoutes.Count -gt $maxRoutes) {
            Write-Host ("  ... +{0}" -f ($Analysis.VPNRoutes.Count - $maxRoutes))
        }
    }
}
