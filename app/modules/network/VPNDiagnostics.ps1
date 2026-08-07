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

function Get-MTNetworkVpnTechnology {
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Name,
        [AllowNull()][string]$Description
    )

    $Text = ("{0} {1}" -f $Name, $Description).Trim()

    $Technology = 'Unknown'
    $Vendor = 'Unknown'

    if ($Text -match '(?i)openvpn.*dco|data channel offload') {
        $Technology = 'OpenVPN DCO'
        $Vendor = 'OpenVPN'
    }
    elseif ($Text -match '(?i)openvpn|tap-windows|wintun') {
        $Technology = 'OpenVPN'
        $Vendor = 'OpenVPN'
    }
    elseif ($Text -match '(?i)fortinet|forticlient') {
        $Technology = 'Fortinet VPN'
        $Vendor = 'Fortinet'
    }
    elseif ($Text -match '(?i)zyxel|secuextender') {
        $Technology = 'Zyxel SecuExtender'
        $Vendor = 'Zyxel'
    }
    elseif ($Text -match '(?i)wireguard') {
        $Technology = 'WireGuard'
        $Vendor = 'WireGuard'
    }
    elseif ($Text -match '(?i)tailscale') {
        $Technology = 'Tailscale'
        $Vendor = 'Tailscale'
    }
    elseif ($Text -match '(?i)anyconnect|cisco secure client') {
        $Technology = 'Cisco AnyConnect'
        $Vendor = 'Cisco'
    }
    elseif ($Text -match '(?i)globalprotect|palo alto') {
        $Technology = 'GlobalProtect'
        $Vendor = 'Palo Alto Networks'
    }
    elseif ($Text -match '(?i)sstp|ikev2|l2tp|pptp|ras|wan miniport') {
        $Technology = 'Windows Native VPN'
        $Vendor = 'Microsoft'
    }

    return [pscustomobject]@{
        Technology = $Technology
        Vendor = $Vendor
        Matched = ($Technology -ne 'Unknown')
        SourceText = $Text
    }
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

            $Technology = Get-MTNetworkVpnTechnology `
                -Name ([string]$Adapter.Name) `
                -Description ([string]$Adapter.Description)

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
                Technology = [string]$Technology.Technology
                Vendor = [string]$Technology.Vendor
                TechnologyMatched = [bool]$Technology.Matched
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
        ProfilesWithUnknownTechnology = @(
            $Profiles |
            Where-Object {
                -not [bool]$_.TechnologyMatched
            }
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
