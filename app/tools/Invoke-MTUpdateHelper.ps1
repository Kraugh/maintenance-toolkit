[CmdletBinding()]
param([Parameter(Mandatory)][string]$ProjectRoot,[switch]$Recover)
$ErrorActionPreference='Stop'
foreach($File in @('Privileges.ps1','UpdateTrust.ps1','SelfUpdate.ps1','Scheduling.ps1','UpdateApplication.ps1')){. (Join-Path $PSScriptRoot $File)}
$State=Get-MTUpdateStatePath $ProjectRoot
$Journal=Join-Path $State 'transaction.json'
if(-not (Test-MTProtectedPath $Journal)){throw 'MT41_ROOT_UNPROTECTED'}
$Transaction=Read-MTStrictJson $Journal
Assert-MTTransaction $Transaction $ProjectRoot
# Helper must be the copy in the protected transaction, never a payload path.
if($PSScriptRoot -ne $Transaction.work){throw 'MT41_STATE_INVALID'}
if($Recover){
    $RecoveryMutex=Enter-MTInstallationLock $ProjectRoot
    try{Repair-MTUpdateTransaction $ProjectRoot}finally{Exit-MTInstallationLock $RecoveryMutex}
    exit
}
$Parent=Get-Process -Id $Transaction.parentPid -ErrorAction SilentlyContinue
if($Parent -and $Parent.StartTime.ToUniversalTime().ToString('o') -eq $Transaction.parentStartedAt){
    if(-not $Parent.WaitForExit(120000)){throw 'MT41_BUSY'}
}
if($Transaction.PSObject.Properties['launcherPid'] -and $Transaction.launcherPid){
    $Launcher=Get-Process -Id $Transaction.launcherPid -ErrorAction SilentlyContinue
    if($Launcher -and $Launcher.StartTime.ToUniversalTime().ToString('o') -eq $Transaction.launcherStartedAt -and -not $Launcher.WaitForExit(120000)){throw 'MT41_BUSY'}
}
$Mutex=Enter-MTInstallationLock $ProjectRoot 120
try {
    $Result=Invoke-MTPreparedApplication $Transaction
    if($Result.CanResume) {
        $Args=Get-MTResumeProcessArguments $Transaction
        if(@($Transaction.resumeArguments).Count){$Style='Hidden'}else{$Style='Normal'}
        Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $Args -WindowStyle $Style | Out-Null
    }
} finally {Exit-MTInstallationLock $Mutex}
