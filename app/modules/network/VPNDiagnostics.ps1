# MT4 Advanced VPN Diagnostics - batch 1
# Deterministic per-adapter VPN context built from the normalized topology.

function Test-MTNetworkPrivateIPv4 {
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Address
    )

    $Parsed = $null
    if (
        [string]::IsNullOrWhiteSpace($Address) -or
        -not [System.Net.IPAddress]::TryParse($Address, [ref]$Parsed) -or
        $Parsed.AddressFamily -ne
            [System.Net.Sockets.AddressFamily]::InterNetwork
    ) {
        return $false
    }

    $Bytes = $Parsed.GetAddressBytes()

    if ($Bytes[0] -eq 10) {
        return $true
    }

    if ($Bytes[0] -eq 172 -and $Bytes[1] -ge 16 -and $Bytes[1] -le 31) {
        return $true
    }

    if ($Bytes[0] -eq 192 -and $Bytes[1] -eq 168) {
        return $true
    }

    if ($Bytes[0] -eq 127) {
        return $true
    }

    if ($Bytes[0] -eq 169 -and $Bytes[1] -eq 254) {
        return $true
    }

    return $false
}

function Get-MTNetworkVpnContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Topology
    )

    $Profiles = @(
        foreach ($Adapter in @($Topology.ActiveVPNAdapters)) {
            $InterfaceIndex = [int]$Adapter.InterfaceIndex

            $Addresses = @(
                $Topology.IPv4Addresses |
                Where-Object {
                    [int]$_.InterfaceIndex -eq $InterfaceIndex -and
                    [string]$_.IPAddress -notlike '169.254.*' -and
                    [string]$_.IPAddress -notlike '127.*'
                }
            )

            $DnsServers = @(
                $Topology.DNS |
                Where-Object {
                    [int]$_.InterfaceIndex -eq $InterfaceIndex
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

            $Routes = @(
                $Topology.VPNRoutes |
                Where-Object {
                    [int]$_.InterfaceIndex -eq $InterfaceIndex
                }
            )

            $DefaultRoutes = @(
                $Routes |
                Where-Object DestinationPrefix -eq '0.0.0.0/0'
            )

            $SpecificRoutes = @(
                $Routes |
                Where-Object {
                    $_.DestinationPrefix -ne '0.0.0.0/0' -and
                    $_.DestinationPrefix -notlike '169.254.*'
                }
            )

            $Mode = if ($DefaultRoutes.Count -gt 0) {
                'FullTunnel'
            }
            elseif ($SpecificRoutes.Count -gt 0) {
                'SplitTunnel'
            }
            else {
                'NoRoutes'
            }

            $DuplicateRouteDestinations = @(
                $Routes |
                Group-Object DestinationPrefix |
                Where-Object Count -gt 1 |
                ForEach-Object {
                    [pscustomobject]@{
                        DestinationPrefix = [string]$_.Name
                        Count = [int]$_.Count
                        Routes = @($_.Group)
                    }
                }
            )

            $PublicDNSServers = @(
                $DnsServers |
                Where-Object {
                    -not (Test-MTNetworkPrivateIPv4 -Address ([string]$_))
                }
            )

            $IPInterface = $null
            $InterfaceDetail = $null

            try {
                $IPInterface = Get-NetIPInterface `
                    -AddressFamily IPv4 `
                    -InterfaceIndex $InterfaceIndex `
                    -ErrorAction Stop |
                    Select-Object -First 1
            }
            catch {
                $InterfaceDetail = $_.Exception.Message
            }

            [pscustomobject]@{
                InterfaceIndex = $InterfaceIndex
                Name = [string]$Adapter.Name
                Description = [string]$Adapter.Description
                Status = [string]$Adapter.Status
                Mode = $Mode
                TunnelIPv4 = @($Addresses)
                TunnelIPv4Count = $Addresses.Count
                DNSServers = $DnsServers
                DNSServerCount = $DnsServers.Count
                Routes = $Routes
                RouteCount = $Routes.Count
                SpecificRoutes = $SpecificRoutes
                SpecificRouteCount = $SpecificRoutes.Count
                DefaultRoutes = $DefaultRoutes
                DefaultRouteCount = $DefaultRoutes.Count
                DuplicateRouteDestinations = $DuplicateRouteDestinations
                DuplicateRouteDestinationCount = $DuplicateRouteDestinations.Count
                PublicDNSServers = $PublicDNSServers
                PublicDNSServerCount = $PublicDNSServers.Count
                MTU = if ($null -ne $IPInterface) {
                    [int]$IPInterface.NlMtu
                }
                else {
                    $null
                }
                InterfaceMetric = if ($null -ne $IPInterface) {
                    [int]$IPInterface.InterfaceMetric
                }
                else {
                    $null
                }
                InterfaceDetail = $InterfaceDetail
            }
        }
    )

    return [pscustomobject]@{
        CollectedAt = (Get-Date).ToString('o')
        ActiveVPNCount = $Profiles.Count
        Profiles = $Profiles
        ProfilesWithoutTunnelIPv4 = @(
            $Profiles |
            Where-Object TunnelIPv4Count -eq 0
        )
        ProfilesWithoutDNS = @(
            $Profiles |
            Where-Object DNSServerCount -eq 0
        )
        ProfilesWithDuplicateRoutes = @(
            $Profiles |
            Where-Object DuplicateRouteDestinationCount -gt 0
        )
        ProfilesWithPublicDNS = @(
            $Profiles |
            Where-Object PublicDNSServerCount -gt 0
        )
        SplitTunnelCount = @(
            $Profiles |
            Where-Object Mode -eq 'SplitTunnel'
        ).Count
        FullTunnelCount = @(
            $Profiles |
            Where-Object Mode -eq 'FullTunnel'
        ).Count
        NoRouteCount = @(
            $Profiles |
            Where-Object Mode -eq 'NoRoutes'
        ).Count
    }
}
