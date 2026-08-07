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
        Write-Ok (Get-MTRuntimeText "CONNECTIVITY_GATEWAY_OK" @($Gateway)) $Module
    }
    else {
        $Errors++
        Write-ErrorLog (Get-MTRuntimeText "CONNECTIVITY_GATEWAY_FAIL" @($Gateway)) $Module
    }
}
catch {
    $Errors++
    Write-ErrorLog $_.Exception.Message $Module
}

try {
    Resolve-DnsName www.microsoft.com -ErrorAction Stop | Out-Null
    Write-Ok (Get-MTRuntimeText "CONNECTIVITY_DNS_OK") $Module
}
catch {
    $Errors++
    Write-ErrorLog (
        Get-MTRuntimeText "CONNECTIVITY_DNS_FAIL" @($_.Exception.Message)
    ) $Module
}

$TestHost = "www.microsoft.com"
$TestPort = 443
$TimeoutMilliseconds = 5000

Write-Main (
    Get-MTRuntimeText "CONNECTIVITY_HTTPS_TEST" @($TestHost, $TestPort)
)

try {
    Add-Log "INFO" (
        Get-MTRuntimeText "CONNECTIVITY_TCP_LOG" @($TestHost, $TestPort)
    ) $Module

    $Client = New-Object System.Net.Sockets.TcpClient

    try {
        $Connect = $Client.BeginConnect($TestHost, $TestPort, $null, $null)

        if (
            $Connect.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false) -and
            $Client.Connected
        ) {
            $Client.EndConnect($Connect)
            Write-Ok (
                Get-MTRuntimeText "CONNECTIVITY_HTTPS_OK" @($TestHost, $TestPort)
            ) $Module
        }
        else {
            $Errors++
            Write-ErrorLog (
                Get-MTRuntimeText "CONNECTIVITY_HTTPS_FAIL" @($TestHost, $TestPort)
            ) $Module
        }
    }
    finally {
        $Client.Close()
    }
}
catch {
    $Errors++
    Write-ErrorLog (
        Get-MTRuntimeText "CONNECTIVITY_HTTPS_ERROR" @(
            $TestHost,
            $TestPort,
            $_.Exception.Message
        )
    ) $Module
}

if ($Errors -gt 0) {
    Set-ModuleResult `
        (Get-MTRuntimeText "MODULE_CONNECTIVITY") `
        "ERROR" `
        (Get-MTRuntimeText "CONNECTIVITY_RESULT_ERROR" @($Errors))
    exit 1
}

Set-ModuleResult `
    (Get-MTRuntimeText "MODULE_CONNECTIVITY") `
    "OK" `
    (Get-MTRuntimeText "CONNECTIVITY_RESULT_OK")
exit 0
