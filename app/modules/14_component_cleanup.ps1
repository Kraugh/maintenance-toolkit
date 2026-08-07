. "$PSScriptRoot\00_common.ps1"
$Module = "COMPONENTS"

$Run = Invoke-LoggedProcessWithHeartbeat `
    -FilePath "$env:SystemRoot\System32\dism.exe" `
    -ArgumentList @("/Online", "/Cleanup-Image", "/StartComponentCleanup", "/NoRestart") `
    -Label "Pulizia componenti Windows" `
    -Module $Module `
    -SuccessCodes @(0, 3010) `
    -HeartbeatSeconds 60 `
    -OutputEncoding "Default" `
    -ShowProgressOutput $false

if ($Run.ExitCode -eq 3010) {
    Set-ModuleResult "Pulizia componenti Windows" "WARN" "Completata; riavvio richiesto" $true
    exit 20
}

if ($Run.ExitCode -eq 0) {
    Set-ModuleResult "Pulizia componenti Windows" "OK" "Completata in $($Run.Duration)"
    exit 0
}

Set-ModuleResult "Pulizia componenti Windows" "ERROR" "Exit code $($Run.ExitCode)"
exit 1
