param([string]$ProjectRoot='',[string]$Scenario='all',[string]$TestOutput)
$ErrorActionPreference='Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$Root=$ProjectRoot
$Case=$Scenario

if ($Scenario -eq 'all') {
    $Temp=Join-Path ([IO.Path]::GetTempPath()) ('MT-NVDOK-Test-'+[guid]::NewGuid().ToString('N'))
    $PowerShell=(Get-Process -Id $PID).Path
    New-Item -ItemType Directory -Path $Temp -Force | Out-Null
    try {
        foreach ($Case in @('current','available','unknown','multiple','offline','none')) {
            $Output=@(& $PowerShell -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -ProjectRoot $ProjectRoot -Scenario $Case -TestOutput $Temp 2>&1)
            $Code=$LASTEXITCODE
            $Expected=if ($Case -eq 'current') {0} elseif ($Case -eq 'none') {10} else {20}
            if ($Code -ne $Expected) { throw ('Unexpected exit code for '+$Case+': '+$Code+' '+($Output -join ' ')) }
            $Session=Join-Path (Join-Path $Temp $Case) 'session'
            $Result=Get-Content -LiteralPath (Join-Path $Session 'result.json') -Raw | ConvertFrom-Json
            $State=Get-Content -LiteralPath (Join-Path $Session 'NVIDIA/nvidia-status.json') -Raw | ConvertFrom-Json
            $ExpectedStatus=if ($Case -eq 'current') {'OK'} elseif ($Case -eq 'none') {'SKIP'} else {'WARN'}
            if ($Result.Status -ne $ExpectedStatus -or $State.downloadAttempted -or $State.installationAttempted -or $Result.RebootRequired) { throw ('Advisory contract failed: '+$Case) }
            if ($Case -eq 'available' -and ($State.devices[0].candidate.version -ne '582.78' -or $Result.Detail -notmatch 'https://www.nvidia.com/en-us/drivers/details/274521/')) { throw 'Available-version or official-link regression.' }
            if ($Case -eq 'available' -and $State.devices[0].updateAvailable -ne $true) { throw 'Availability flag missing.' }
            if ($Case -eq 'current' -and $State.devices[0].updateAvailable -ne $false) { throw 'Current flag incorrect.' }
            if ($Case -eq 'offline' -and $null -ne $State.devices[0].updateAvailable) { throw 'Unverified GPU treated as current.' }
            if ($Case -eq 'multiple' -and ($State.counts.current -ne 1 -or $State.counts.incomplete -ne 1)) { throw 'Per-GPU aggregation regression.' }
            if ($Case -eq 'offline' -and $State.devices[0].installedVersion -ne '582.78') { throw 'Installed version lost during catalogue outage.' }
            'PASS: NVIDIA advisory scenario '+$Case
        }
    }
    finally { Remove-Item -LiteralPath $Temp -Recurse -Force -ErrorAction SilentlyContinue }
    exit 0
}
if ($Scenario -notin @('current','available','unknown','multiple','offline','none') -or [string]::IsNullOrWhiteSpace($TestOutput)) { throw 'Invalid test scenario.' }
$env:MT_ROOT=$Root;$env:MT_LANGUAGE='it-IT';$env:MT_VERSION=[string](Get-Content (Join-Path $Root 'config/version.json') -Raw | ConvertFrom-Json).Version
$env:MT_LOGS=Join-Path $TestOutput $Case
$env:MT_SESSION_DIR=$env:MT_LOGS+'/session'
New-Item -ItemType Directory -Path $env:MT_SESSION_DIR -Force | Out-Null
$env:MT_RESULT=$env:MT_SESSION_DIR+'/result.json'
function Get-PnpDevice {
 [CmdletBinding()]param([string]$Class,[switch]$PresentOnly)
 if($Case -eq 'none'){return}
 $Name=if($Case -eq 'unknown'){'NVIDIA Quadro Unknown'}else{'NVIDIA Quadro P620'}
 [pscustomobject]@{InstanceId='PCI\VEN_10DE&DEV_1CB6&TEST';FriendlyName=$Name;Status='OK'}
 if($Case -eq 'multiple'){[pscustomobject]@{InstanceId='PCI\VEN_10DE&DEV_9999&TEST';FriendlyName='NVIDIA Quadro Unknown';Status='OK'}}
}
function Get-CimInstance {
 [CmdletBinding()]param([string]$ClassName,[string]$Filter)
 switch($ClassName){
 'Win32_PnPSignedDriver'{
 $Version=if($Case -eq 'available'){'31.0.15.2889'}else{'32.0.15.8278'}
 [pscustomobject]@{DeviceID='PCI\VEN_10DE&DEV_1CB6&TEST';DeviceName=if($Case -eq 'unknown'){'NVIDIA Quadro Unknown'}else{'NVIDIA Quadro P620'};DriverVersion=$Version}
 if($Case -eq 'multiple'){[pscustomobject]@{DeviceID='PCI\VEN_10DE&DEV_9999&TEST';DeviceName='NVIDIA Quadro Unknown';DriverVersion=$Version}}
 }
 'Win32_OperatingSystem'{[pscustomobject]@{Caption='Microsoft Windows 11 Pro';Version='10.0.26300';OSArchitecture='64 bit'}}
 'Win32_ComputerSystem'{[pscustomobject]@{PCSystemType=1}}
 'Win32_SystemEnclosure'{[pscustomobject]@{ChassisTypes=@(3)}}
 }
}
function Invoke-WebRequest {
 [CmdletBinding()]param([string]$Uri,[switch]$UseBasicParsing,[int]$TimeoutSec,[string]$OutFile)
 if($PSBoundParameters.ContainsKey('OutFile')){throw 'Driver download attempted'}
 if($Case -eq 'offline'){throw 'Simulated catalogue outage'}
 if($Uri -match 'TypeID=1'){$Body='<LookupValueSearch><LookupValues><LookupValue><Name>NVIDIA RTX PRO / RTX / Quadro</Name><Value>3</Value></LookupValue></LookupValues></LookupValueSearch>'}
 elseif($Uri -match 'TypeID=2'){$Body='<LookupValueSearch><LookupValues><LookupValue><Name>Quadro Series</Name><Value>73</Value></LookupValue></LookupValues></LookupValueSearch>'}
 elseif($Uri -match 'TypeID=3'){$Body='<LookupValueSearch><LookupValues><LookupValue><Name>Quadro P620</Name><Value>865</Value></LookupValue></LookupValues></LookupValueSearch>'}
 elseif($Uri -match 'DriverManualLookup'){$Body=Get-Content ($Root+'/app/tools/fixtures/nvidia-p620-response.json') -Raw}
 else{throw 'Unexpected network operation'}
 [pscustomobject]@{StatusCode=200;Content=$Body}
}
& ($Root+'/app/modules/15_nvidia.ps1')

exit $LASTEXITCODE
