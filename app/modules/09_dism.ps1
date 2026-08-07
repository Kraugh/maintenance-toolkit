###############################################################################
# Maintenance Toolkit 3.7.2 - Modulo DISM
###############################################################################

. "$PSScriptRoot\00_common.ps1"
$Module = "DISM"
$Run = Invoke-LoggedProcessWithHeartbeat `
    -FilePath "$env:SystemRoot\System32\dism.exe" `
    -ArgumentList @("/Online", "/Cleanup-Image", "/RestoreHealth", "/NoRestart") `
    -Label "DISM RestoreHealth" -Module $Module -SuccessCodes @(0) -HeartbeatSeconds 60 -OutputEncoding "Default" -ShowProgressOutput $false
if ($Run.ExitCode -eq 0) {
    Set-ModuleResult "DISM RestoreHealth" "OK" "Completato in $($Run.Duration)"
    exit 0
}
Set-ModuleResult "DISM RestoreHealth" "ERROR" "Exit code $($Run.ExitCode)"
exit 1
