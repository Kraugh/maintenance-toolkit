param([string]$ProjectRoot='')
$ErrorActionPreference='Stop'
if (-not $ProjectRoot) { $ProjectRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
. (Join-Path $ProjectRoot 'app/modules/oem/DellCommandUpdate.ps1')
$Temp=Join-Path ([IO.Path]::GetTempPath()) ('MT-Dev8-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Temp -Force | Out-Null
try {
    $Log=Join-Path $Temp 'apply.log'
    Set-Content $Log 'Installation for these updates were interrupted, will get installed after UserActivity Completes.'
    $Evidence=Get-MTDcuApplyEvidence -ExitCode 0 -LogPath $Log
    if (-not $Evidence.Deferred -or $Evidence.Outcome -ne 'deferred_by_user_activity') { throw 'False successful installation for deferred exit 0.' }
    Set-Content $Log 'Finished installing the updates.'
    foreach ($Code in @(0,1,5,500,2)) {
        $Expected=switch ($Code) {0 {'verification_required'} 1 {'restart_required'} 5 {'restart_required'} 500 {'no_applicable_updates'} default {'failed'}}
        $Evidence=Get-MTDcuApplyEvidence -ExitCode $Code -LogPath $Log
        if ($Evidence.Outcome -ne $Expected -or $Evidence.Deferred) { throw "Incorrect apply evidence: $Code" }
    }
    $Evidence=Get-MTDcuApplyEvidence -ExitCode 0 -LogPath (Join-Path $Temp 'missing.log')
    if ($Evidence.Outcome -ne 'verification_required') { throw 'Missing log treated as proof of installation.' }
    'PASS: DCU deferred exit 0, no-updates 500, reboot, failure and missing evidence.'
    . (Join-Path $ProjectRoot 'app/modules/gpu/NvidiaDriver.ps1')
    foreach ($Pair in @(@('31.0.15.3895','538.95'),@('32.0.15.8267','582.67'),@('31.0.15.5362','553.62'),@('32.0.15.9671','596.71'))) {
        if ((ConvertTo-MTNvidiaVersion $Pair[0]).ToString() -ne $Pair[1]) { throw 'Office GPU version conversion failed.' }
    }
    foreach ($Model in @('Quadro P2200','RTX A1000','RTX 4500 Ada Generation','RTX 500 Ada Generation Laptop GPU','T1000')) {
        $Mobile=$Model -match 'Laptop'
        $Product=[pscustomobject]@{Name=$Model;Value='123';SeriesName=$(if($Mobile){'RTX Notebook'}else{'RTX Desktop'})}
        if ($null -eq (Get-MTNvidiaProductMatch -DeviceName ('NVIDIA '+$Model) -Products @($Product) -IsMobile $Mobile)) { throw "Office model mapping failed: $Model" }
        if ($null -ne (Get-MTNvidiaProductMatch -DeviceName ('NVIDIA '+$Model) -Products @($Product) -IsMobile (-not $Mobile))) { throw 'Desktop/mobile mismatch accepted.' }
    }
    'PASS: anonymized office GPU versions and exact desktop/mobile mapping.'
    . (Join-Path $ProjectRoot 'app/modules/inventory/InventorySnapshotWriter.ps1')
    $Path=Join-Path $Temp 'inventory.json'
    Copy-Item (Join-Path $ProjectRoot 'docs/inventory-example-1.0.json') $Path
    $Gpu=[pscustomobject]@{schemaVersion=3;mode='advisory_only';status='action_required';devices=@([pscustomobject]@{name='Quadro P2200';windowsDriverVersion='31.0.15.3895';installedVersion='538.95';candidate=[pscustomobject]@{version='582.78';branch='Enterprise Production'};updateAvailable=$true;status='update_available'});downloadAttempted=$false;installationAttempted=$false}
    Update-MTInventoryGpuDriverStatus -Path $Path -GpuDriverStatus $Gpu
    $Snapshot=Get-Content $Path -Raw | ConvertFrom-Json
    if ($Snapshot.maintenance.data.gpuDrivers.devices[0].updateAvailable -ne $true -or $Snapshot.maintenance.status -ne 'partial') { throw 'DMT inventory availability contract failed.' }
    $Gpu.status='verification_incomplete';$Gpu.devices[0].updateAvailable=$null
    Update-MTInventoryGpuDriverStatus -Path $Path -GpuDriverStatus $Gpu
    $Snapshot=Get-Content $Path -Raw | ConvertFrom-Json
    if ($null -ne $Snapshot.maintenance.data.gpuDrivers.devices[0].updateAvailable -or $Snapshot.maintenance.status -ne 'partial') { throw 'Unknown availability incorrectly reported as current.' }
    'PASS: GPU availability and incomplete checks preserved in inventory.'
} finally { Remove-Item $Temp -Recurse -Force -ErrorAction SilentlyContinue }

# Execute the actual Dell workflow with deterministic tools/scans, no installations.
$ModuleText=Get-Content (Join-Path $ProjectRoot 'app/modules/08_oem.ps1') -Raw
$Begin=$ModuleText.IndexOf('if ($Manufacturer -match "Dell")')
$End=$ModuleText.IndexOf('if ($Manufacturer -match "HP|Hewlett")')
$DellWorkflow=[scriptblock]::Create(($ModuleText.Substring($Begin,$End-$Begin) -replace '\bexit\s+(?:0|1|20)\b','return'))
function Get-MTDellCommandUpdate { 'mock-dcu.exe' }
function Get-Item { param($LiteralPath) [pscustomobject]@{VersionInfo=[pscustomobject]@{FileVersion='5.7.2.7'}} }
function Get-CimInstance { param($ClassName) [pscustomobject]@{SMBIOSBIOSVersion='1.7.0'} }
function Get-MTVerifiedRestorePoint { param($Manufacturer) }
function Get-MTRuntimeText { param($Key,$Arguments) $Key+' '+($Arguments -join ',') }
function Write-Main { param($Text) }
function Write-WarnLog { param($Text,$Module) }
function Write-ErrorLog { param($Text,$Module) }
function Save-MTOemStatus { param($Status) $script:SavedStatus=$Status }
function Set-ModuleResult { param($Module,$Status,$Detail,$RebootRequired=$false) $script:SavedResult=[pscustomobject]@{Status=$Status;Detail=$Detail;RebootRequired=$RebootRequired} }
function Invoke-MTDcuScan {
    param($Executable,$UpdateType,$Purpose)
    $Updates=@()
    if ($Purpose -eq 'bios') { $Updates=@([pscustomobject]@{id='BIOS';targetVersion='1.9.0';severity='recommended';name='BIOS'}) }
    elseif ($Purpose -eq 'safe' -and $Case -ne 'none') { $Updates=@($TestUpdate) }
    elseif ($Purpose -eq 'verification' -and $Case -in @('deferred','remaining')) { $Updates=@($TestUpdate) }
    [pscustomobject]@{Updates=$Updates;RebootRequired=$false}
}
function Invoke-MTDcuSafeUpdates {
    param($Executable)
    $Code=if($Case -eq 'noapply'){500}elseif($Case -eq 'reboot'){1}else{0}
    [pscustomobject]@{ExitCode=$Code;SelfUpdateStarted=$false;PreviousToolVersion='5.7.2.7';LogPath='persisted.log';Evidence=[pscustomobject]@{Outcome=$(if($Case -eq 'deferred'){'deferred_by_user_activity'}else{'verification_required'});Deferred=($Case -eq 'deferred')}}
}
$TestUpdate=[pscustomobject]@{id='DRIVER';name='Test driver';type='Driver';currentVersion='1';targetVersion='2';severity='Recommended';rebootRequired=$false}
$Manufacturer='Dell';$Module='OEM'
foreach ($Case in @('deferred','remaining','installed','noapply','reboot','none')) {
    $script:SavedStatus=$null;$script:SavedResult=$null
    & $DellWorkflow
    if ($SavedResult.Status -ne 'WARN' -or $SavedResult.Detail -notmatch 'OEM_DELL_BIOS_URGENT' -or $SavedResult.Detail -notmatch '\|') { throw "BIOS masked non-BIOS outcome: $Case $($SavedResult.Detail)" }
    $Expected=switch($Case){deferred {'deferred_by_user_activity'} remaining {'still_applicable'} installed {'installed'} noapply {'no_longer_applicable'} reboot {'restart_required'} none {''}}
    if ($Case -ne 'none' -and $SavedStatus.updates[0].status -ne $Expected) { throw "Dell workflow classification failed: $Case" }
    if ($Case -eq 'deferred' -and $SavedResult.Detail -notmatch 'OEM_DELL_DEFERRED') { throw 'Deferral absent from summary.' }
    if ($SavedResult.RebootRequired -ne ($Case -eq 'reboot')) { throw "Dell reboot classification failed: $Case" }
    if ($Case -ne 'none' -and $SavedStatus.apply.outcome -ne $Expected) { throw "Final Dell apply outcome incorrect: $Case" }
    "PASS: Dell workflow $Case with final apply outcome."
}

# Resolver tests do not execute Winget or install anything.
. (Join-Path $ProjectRoot 'app/modules/winget/WingetDiscovery.ps1')
function Get-Command { param($Name,$CommandType,$ErrorAction) if ($script:PathCommand) { [pscustomobject]@{Source=$script:PathCommand} } }
function Get-MTWingetCandidates { $script:Candidates }
function Test-MTWingetExecutable {
    param($Path,[switch]$RequireMicrosoftSignature)
    $script:Probes += [pscustomobject]@{Path=$Path;Signature=[bool]$RequireMicrosoftSignature}
    return ($Path -in $script:WorkingPaths)
}
foreach ($Scenario in @('path','system','broken_alias','newest_broken','absent')) {
    $script:PathCommand=$null; $script:WorkingPaths=@(); $script:Candidates=@(); $script:Probes=@()
    if ($Scenario -eq 'path') { $script:PathCommand='alias.exe';$script:WorkingPaths=@('alias.exe') }
    if ($Scenario -eq 'broken_alias') { $script:PathCommand='broken.exe' }
    if ($Scenario -in @('system','broken_alias','newest_broken')) {
        $script:Candidates=@([pscustomobject]@{Source='older.exe';Version=[version]'1.0'},[pscustomobject]@{Source='newer.exe';Version=[version]'2.0'})
        $script:WorkingPaths=@($(if($Scenario -eq 'newest_broken'){'older.exe'}else{'newer.exe'}))
    }
    $Found=Get-WingetCommand
    $ExpectedPath=switch($Scenario){path {'alias.exe'} system {'newer.exe'} broken_alias {'newer.exe'} newest_broken {'older.exe'} absent {$null}}
    $ActualPath = if ($null -ne $Found) { $Found.Source } else { $null }
    if ($ActualPath -ne $ExpectedPath) { throw "Winget discovery failed: $Scenario" }
    if (@($script:Probes | Where-Object { $_.Path -in @('older.exe','newer.exe') -and -not $_.Signature }).Count -gt 0) { throw 'Fallback without signature validation.' }
    "PASS: Winget discovery $Scenario"
}
