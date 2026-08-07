. "$PSScriptRoot\00_common.ps1";$M="DEFENDER"
if(!(Get-Command Update-MpSignature -ErrorAction SilentlyContinue)){Write-Skip "Defender non disponibile." $M;Set-ModuleResult "Microsoft Defender" "SKIP" "Cmdlet non disponibile";exit 10}
try{$B=Get-MpComputerStatus;Update-MpSignature -ErrorAction Stop;$A=Get-MpComputerStatus
 Write-Ok "Defender: $($B.AntivirusSignatureVersion) -> $($A.AntivirusSignatureVersion)" $M
 Set-ModuleResult "Microsoft Defender" "OK" "Firme $($A.AntivirusSignatureVersion)";exit 0
}catch{Write-ErrorLog $_.Exception.Message $M;Set-ModuleResult "Microsoft Defender" "ERROR" $_.Exception.Message;exit 1}
