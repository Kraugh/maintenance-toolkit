[CmdletBinding()]
param([string]$ProjectRoot = '')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$Temp = Join-Path ([IO.Path]::GetTempPath()) ('MT-ReleaseBlockers-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Temp -Force | Out-Null
$PreviousSession = $env:MT_SESSION_DIR
$env:MT_SESSION_DIR = $Temp
function Get-MTRuntimeText { param($Key,$Arguments) $Key + ' ' + ($Arguments -join ',') }
function Write-Ok { param($Text,$Module) $script:Messages += $Text }
function Add-Log { param($Level,$Text,$Module) $script:Messages += $Text }
function Write-ErrorLog { param($Text,$Module) throw $Text }
function Write-WarnLog { param($Text,$Module) $script:Messages += $Text }
function Get-ComputerRestorePoint { param($ErrorAction) if ($script:ReadFails) { throw 'Simulated restore query failure' }; $script:Points }
function Enable-ComputerRestore { param($Drive,$ErrorAction) }
function Checkpoint-Computer {
    param($Description,$RestorePointType,$ErrorAction)
    $script:Creations++
    if ($script:SkipCreation) { return }
    $script:Points = @([pscustomobject]@{SequenceNumber=99;Description=$Description;CreationTime=(Get-Date);EventType=100})
}
function New-TestPoint {
    param([int]$Sequence,[double]$AgeHours,[string]$Description='Windows point',[int]$EventType=100)
    [pscustomobject]@{SequenceNumber=$Sequence;Description=$Description;CreationTime=(Get-Date).AddHours(-$AgeHours);EventType=$EventType}
}
try {
    . (Join-Path $ProjectRoot 'app/modules/oem/HPImageAssistant.ps1')
    $script:ReadFails=$false;$script:SkipCreation=$false;$script:Creations=0;$script:Messages=@()
    $script:Points=@((New-TestPoint 12 1))
    $Marker=Get-MTVerifiedRestorePoint -Manufacturer Dell
    if ($Marker.sequenceNumber -ne 12 -or $Creations -ne 0) { throw 'Recent Windows point was not reused.' }
    'PASS: completed recent Windows point reused without requesting creation.'

    $script:Points=@((New-TestPoint 13 2),(New-TestPoint 14 1))
    $Marker=Get-MTVerifiedRestorePoint -Manufacturer Dell
    if ($Marker.sequenceNumber -ne 14) { throw 'Deleted session marker trusted.' }
    'PASS: deleted marker revalidated against actual points.'

    Set-Content (Join-Path $Temp 'restore-point.json') '{broken'
    $Marker=Get-MTVerifiedRestorePoint -Manufacturer Dell
    if ($Marker.sequenceNumber -ne 14) { throw 'Corrupt marker prevented valid reuse.' }
    'PASS: corrupt marker recovered from verified restore points.'

    $script:Points=@((New-TestPoint 14 25),(New-TestPoint 15 -1),(New-TestPoint 16 1 'Incomplete point' 101))
    $Marker=Get-MTVerifiedRestorePoint -Manufacturer Dell
    if ($Marker.sequenceNumber -ne 99 -or $Creations -ne 1) { throw 'Stale, future or incomplete point accepted.' }
    'PASS: old/future/incomplete points rejected; new point created and verified.'

    $script:ReadFails=$true;$Before=$Creations;$Caught=$false
    try { $null=Get-MTVerifiedRestorePoint -Manufacturer Dell } catch { $Caught=$true }
    if (-not $Caught -or $Creations -ne $Before) { throw 'Unreadable restore inventory did not fail closed.' }
    $script:ReadFails=$false
    'PASS: restore query failure blocks OEM preparation.'

    $script:Points=@();$script:SkipCreation=$true;$Caught=$false
    function Start-Sleep { param($Seconds) throw 'Simulated verification wait failure' }
    try { $null=Get-MTVerifiedRestorePoint -Manufacturer Dell } catch { $Caught=$true }
    if (-not $Caught) { throw 'Unverified creation accepted.' }
    $script:SkipCreation=$false
    'PASS: accepted creation request without a verified point blocks OEM preparation.'

    . (Join-Path $ProjectRoot 'app/modules/oem/DellCommandUpdate.ps1')
    $Log=Join-Path $Temp 'native.log'
    foreach ($Pair in @(@(0,1,1),@(0,500,500),@(0,2,2),@(9002,0,9002),@(2,0,2))) {
        Set-Content $Log ('The program exited with return code: ' + $Pair[1])
        $Actual=Get-MTDcuEffectiveExitCode -ProcessExitCode $Pair[0] -LogPath $Log
        if ($Actual -ne $Pair[2]) { throw "Incorrect process/native reconciliation: $Pair" }
    }
    Set-Content $Log 'Native code unavailable'
    if ((Get-MTDcuEffectiveExitCode -ProcessExitCode 5 -LogPath $Log) -ne 5) { throw 'Missing native code did not preserve process code.' }
    'PASS: native reboot/no-update/failure codes preserved; runner failures never masked.'

    # Exercise the real process runner with a fake process, not an installer.
    . (Join-Path $ProjectRoot 'app/core/ProcessRunner.ps1')
    function Start-Process {
        param($FilePath,$ArgumentList,[switch]$PassThru,[switch]$NoNewWindow,$RedirectStandardOutput,$RedirectStandardError)
        $Process=[pscustomobject]@{ExitCode=0;Id=123}
        $Process | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { param($Milliseconds) if ($null -ne $Milliseconds) { return $true } }
        return $Process
    }
    function Read-ProcessOutput { param($Path,$Encoding) }
    $script:Messages=@()
    $Code=Invoke-LoggedProcess -FilePath 'fake-dcu.exe' -Label 'DCU' -Module OEM -ProcessOutcomeOnly
    if ($Code -ne 0 -or ($Messages -join ' ') -notmatch 'PROCESS_EXIT_PENDING_VERIFICATION' -or ($Messages -join ' ') -match 'PROCESS_COMPLETED') {
        throw 'DCU process exit was logged as a completed operation.'
    }
    'PASS: DCU process termination logged neutrally pending outcome verification.'
    foreach ($Language in @('en-US','it-IT','sv-SE')) {
        $Data=Get-Content (Join-Path $ProjectRoot "languages/$Language.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($Key in @('PROCESS_EXIT_PENDING_VERIFICATION','OEM_DELL_EXIT_EVIDENCE','OEM_DELL_EXIT_NATIVE_MISSING')) {
            if (-not $Data.PSObject.Properties[$Key]) { throw "Missing localization: $Language $Key" }
        }
    }
    'PASS: new messages present in all three language files.'
}
finally {
    $env:MT_SESSION_DIR=$PreviousSession
    Remove-Item -LiteralPath $Temp -Recurse -Force -ErrorAction SilentlyContinue
}
