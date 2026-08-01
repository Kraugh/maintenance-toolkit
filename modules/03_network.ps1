###############################################################################
# Maintenance Toolkit 3.7.2 - Modulo report rete
###############################################################################

. "$PSScriptRoot\00_common.ps1"

$Module = "NETWORK"

try {
    $OutputPath = Join-Path $env:MT_SESSION_DIR "rete.txt"
    $Report = [System.Collections.Generic.List[string]]::new()

    $Report.Add("REPORT RETE")
    $Report.Add("===========")
    $Report.Add("")
    $Report.Add("Computer: $env:COMPUTERNAME")
    $Report.Add("Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $Report.Add("")

    $Report.Add("CONFIGURAZIONE IP")
    $Report.Add("-----------------")
    $Report.Add((Get-NetIPConfiguration | Format-List * | Out-String -Width 4096).TrimEnd())
    $Report.Add("")

    $Report.Add("INDIRIZZI IP")
    $Report.Add("------------")
    $Report.Add((Get-NetIPAddress | Sort-Object InterfaceAlias, AddressFamily, IPAddress | Format-Table InterfaceAlias, AddressFamily, IPAddress, PrefixLength, AddressState -AutoSize | Out-String -Width 4096).TrimEnd())
    $Report.Add("")

    $Report.Add("DNS CLIENT")
    $Report.Add("----------")
    $Report.Add((Get-DnsClientServerAddress | Sort-Object InterfaceAlias, AddressFamily | Format-Table InterfaceAlias, AddressFamily, ServerAddresses -AutoSize | Out-String -Width 4096).TrimEnd())
    $Report.Add("")

    $Report.Add("ROUTE IPv4")
    $Report.Add("----------")
    $Report.Add((Get-NetRoute -AddressFamily IPv4 | Sort-Object RouteMetric, DestinationPrefix | Format-Table ifIndex, DestinationPrefix, NextHop, RouteMetric, State -AutoSize | Out-String -Width 4096).TrimEnd())
    $Report.Add("")

    $Report.Add("ARP / NEIGHBOR")
    $Report.Add("--------------")
    $Report.Add((Get-NetNeighbor -AddressFamily IPv4 | Sort-Object InterfaceIndex, IPAddress | Format-Table InterfaceIndex, IPAddress, LinkLayerAddress, State -AutoSize | Out-String -Width 4096).TrimEnd())
    $Report.Add("")

    $Report.Add("CONNESSIONI TCP")
    $Report.Add("---------------")
    $Report.Add((Get-NetTCPConnection -ErrorAction SilentlyContinue | Sort-Object State, LocalAddress, LocalPort | Format-Table LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess -AutoSize | Out-String -Width 4096).TrimEnd())

    $Content = $Report -join [Environment]::NewLine

    $Written = Write-TextLineRobust -Path $OutputPath -Line $Content -Retries 8 -DelayMilliseconds 300
    if (-not $Written) {
        throw "Impossibile scrivere il report rete dopo più tentativi: $OutputPath"
    }

    Write-Ok "Report rete salvato: $OutputPath" $Module
    Set-ModuleResult "Report rete" "OK" "Creato rete.txt"
    exit 0
}
catch {
    Write-ErrorLog $_.Exception.Message $Module
    Write-ErrorLog $_.InvocationInfo.PositionMessage $Module
    Set-ModuleResult "Report rete" "ERROR" $_.Exception.Message
    exit 1
}
