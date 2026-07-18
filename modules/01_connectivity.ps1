. "$PSScriptRoot\00_common.ps1";$M="CONNECTIVITY"
$Errors=0
try{$Gw=(Get-NetRoute -DestinationPrefix "0.0.0.0/0"|Sort-Object RouteMetric|Select-Object -First 1).NextHop
 if($Gw -and (Test-Connection $Gw -Count 1 -Quiet)){Write-Ok "Gateway raggiungibile: $Gw" $M}else{$Errors++;Write-ErrorLog "Gateway non raggiungibile: $Gw" $M}
}catch{$Errors++;Write-ErrorLog $_.Exception.Message $M}
try{Resolve-DnsName www.microsoft.com -ErrorAction Stop|Out-Null;Write-Ok "Risoluzione DNS funzionante." $M}catch{$Errors++;Write-ErrorLog "DNS non funzionante: $($_.Exception.Message)" $M}
try{if(Test-NetConnection www.microsoft.com -Port 443 -InformationLevel Quiet){Write-Ok "HTTPS Internet raggiungibile." $M}else{$Errors++;Write-ErrorLog "HTTPS Internet non raggiungibile." $M}}catch{$Errors++}
if($Errors){Set-ModuleResult "Controllo connettivita" "ERROR" "$Errors controlli falliti";exit 1}
Set-ModuleResult "Controllo connettivita" "OK" "Gateway, DNS e HTTPS funzionanti";exit 0
