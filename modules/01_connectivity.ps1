. "$PSScriptRoot\00_common.ps1"
$Module = "CONNECTIVITY"
$Errors = 0

try {
    $Gateway = (
        Get-NetRoute -DestinationPrefix "0.0.0.0/0" |
            Sort-Object RouteMetric |
            Select-Object -First 1
    ).NextHop

    if ($Gateway -and (Test-Connection $Gateway -Count 1 -Quiet)) {
        Write-Ok "Gateway raggiungibile: $Gateway" $Module
    }
    else {
        $Errors++
        Write-ErrorLog "Gateway non raggiungibile: $Gateway" $Module
    }
}
catch {
    $Errors++
    Write-ErrorLog $_.Exception.Message $Module
}

try {
    Resolve-DnsName www.microsoft.com -ErrorAction Stop | Out-Null
    Write-Ok "Risoluzione DNS funzionante." $Module
}
catch {
    $Errors++
    Write-ErrorLog "DNS non funzionante: $($_.Exception.Message)" $Module
}

$TestHost = "www.microsoft.com"
$TestPort = 443
$TimeoutMilliseconds = 5000

$ConnectivityMessage = (
    "Verifica connettività HTTPS verso {0}:{1}. " +
    "Nessun dato viene trasmesso: viene aperta soltanto una connessione TCP di prova."
) -f $TestHost, $TestPort

Write-Main $ConnectivityMessage

try {
    Add-Log "INFO" (
        "Verifica TCP esplicita verso {0}:{1}, usata esclusivamente per controllare la connettività HTTPS." -f
        $TestHost,
        $TestPort
    ) $Module

    $Client = New-Object System.Net.Sockets.TcpClient

    try {
        $Connect = $Client.BeginConnect($TestHost, $TestPort, $null, $null)

        if (
            $Connect.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false) -and
            $Client.Connected
        ) {
            $Client.EndConnect($Connect)
            Write-Ok ("HTTPS raggiungibile: {0}:{1}." -f $TestHost, $TestPort) $Module
        }
        else {
            $Errors++
            Write-ErrorLog ("HTTPS non raggiungibile: {0}:{1}." -f $TestHost, $TestPort) $Module
        }
    }
    finally {
        $Client.Close()
    }
}
catch {
    $Errors++
    Write-ErrorLog (
        "Errore durante il test HTTPS verso {0}:{1} - {2}" -f `
            $TestHost,
            $TestPort,
            $_.Exception.Message
    ) $Module
}

if ($Errors -gt 0) {
    Set-ModuleResult "Controllo connettivita" "ERROR" "$Errors controlli falliti"
    exit 1
}

Set-ModuleResult "Controllo connettivita" "OK" "Gateway, DNS e HTTPS funzionanti"
exit 0
