. "$PSScriptRoot\00_common.ps1";$R=Invoke-LoggedProcess "$env:SystemRoot\System32\dism.exe" @("/Online","/Cleanup-Image","/StartComponentCleanup","/NoRestart") "DISM StartComponentCleanup" "COMPONENTS" @(0,3010)
if($R-eq3010){Set-ModuleResult "Pulizia componenti Windows" "WARN" "Completata; riavvio richiesto" $true;exit 20}
if($R-eq0){Set-ModuleResult "Pulizia componenti Windows" "OK" "Completata";exit 0}
Set-ModuleResult "Pulizia componenti Windows" "ERROR" "Exit code $R";exit 1
