param([string]$ProjectRoot='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
if (-not $ProjectRoot) { $ProjectRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
function Get-MTRuntimeText { param($Key,$Arguments) $Key+' '+($Arguments -join ',') }
. (Join-Path $ProjectRoot 'app/modules/winget/WingetExceptions.ps1')
$Policy=[pscustomobject]@{schemaVersion='1.0';computerName='TEST-PC';mode='exclude_packages';excludedPackageIds=@('Microsoft.msodbcsql.17','Microsoft.VCRedist.2015+.x64')}
$Valid=ConvertTo-MTWingetExceptionPolicy -Policy $Policy -ComputerName 'TEST-PC'
function Assert-Rejected { param([scriptblock]$Action) $Rejected=$false;try { & $Action | Out-Null } catch { $Rejected=$true };if(-not $Rejected){throw 'Invalid policy accepted.'} }
Assert-Rejected { ConvertTo-MTWingetExceptionPolicy -Policy $Policy -ComputerName 'OTHER-PC' }
foreach ($Json in @(
    '{"schemaVersion":"2.0","computerName":"TEST-PC","mode":"exclude_packages","excludedPackageIds":["Vendor.App"]}',
    '{"schemaVersion":"1.0","computerName":"TEST-PC","mode":"exclude_packages","excludedPackageIds":"Vendor.App"}',
    '{"schemaVersion":"1.0","computerName":"TEST-PC","mode":"exclude_packages","excludedPackageIds":[]}',
    '{"schemaVersion":"1.0","computerName":"TEST-PC","mode":"exclude_packages","excludedPackageIds":["Vendor.App","vendor.app"]}',
    '{"schemaVersion":"1.0","computerName":"TEST-PC","mode":"exclude_packages","excludedPackageIds":["--all"]}',
    '{"schemaVersion":"1.0","computerName":"TEST-PC","mode":"exclude_packages"}'
)) { Assert-Rejected { ConvertTo-MTWingetExceptionPolicy -Policy ($Json|ConvertFrom-Json) -ComputerName 'TEST-PC' } }
'PASS: valid policy; wrong machine, schema, scalar, empty, duplicate, option and missing fields rejected.'
$Export=[pscustomobject]@{Sources=@([pscustomobject]@{SourceDetails=[pscustomobject]@{Name='winget'};Packages=@([pscustomobject]@{PackageIdentifier='microsoft.msodbcsql.17'},[pscustomobject]@{PackageIdentifier='Microsoft.VCRedist.2015+.x64'},[pscustomobject]@{PackageIdentifier='Vendor.Allowed'})})}
$Plan=@(Get-MTWingetExceptionPlan -Export $Export -Policy $Valid)
if (@($Plan|Where-Object excluded).Count -ne 2) {throw 'Exact exclusion matching failed.'}
foreach($Item in $Plan|Where-Object excluded){Assert-Rejected {Get-MTWingetExceptionArguments -Item $Item -Policy $Valid}}
$Allowed=$Plan|Where-Object {-not $_.excluded}|Select-Object -First 1
$Arguments=@(Get-MTWingetExceptionArguments -Item $Allowed -Policy $Valid)
if('--all' -in $Arguments -or '--force' -in $Arguments -or '--skip-dependencies' -notin $Arguments -or '--exact' -notin $Arguments -or 'Vendor.Allowed' -notin $Arguments){throw 'Unsafe selective command.'}
Assert-Rejected {Get-MTWingetExceptionPlan -Export ([pscustomobject]@{Sources='invalid'}) -Policy $Valid}
Assert-Rejected {Get-MTWingetExceptionPlan -Export ([pscustomobject]@{Sources=@([pscustomobject]@{SourceDetails=[pscustomobject]@{Name='bad source'};Packages=@()})}) -Policy $Valid}
'PASS: exact/case-insensitive exclusions, selective arguments, no --all or --force, dependencies disabled, malformed export rejected.'

# Execute the actual module with mocked process runner: no external commands.
$ModuleText=Get-Content (Join-Path $ProjectRoot 'app/modules/05_winget.ps1') -Raw
$ModuleText=$ModuleText -replace '(?m)^\. \"\$PSScriptRoot[^\r\n]*',''
# Remove only dot-source lines, leaving application control flow unchanged.
$ModuleText=($ModuleText -split "`n" | Where-Object {$_ -notmatch '^\. "\$PSScriptRoot'}) -join "`n"
$Workflow=[scriptblock]::Create(($ModuleText -replace '\bexit\s+(?:0|1|10|20)\b','return'))
function Read-IniFile {param($Path) @{} }
function Get-IniValue {param($Config,$Section,$Key,$Default) $Default }
function Get-IniBool {param($Config,$Section,$Key,$Default) $Default }
function Get-WingetCommand { [pscustomobject]@{Source='mock-winget.exe'} }
function Read-MTWingetExceptionPolicy {if($script:Case -eq 'invalid'){throw 'invalid policy'};if($script:Case -eq 'normal'){return $null};if($script:Case -eq 'blocked'){return [pscustomobject]@{mode='block_module';excludedPackageIds=@()}};return $Valid}
function Write-Main {param($Text)}
function Write-WarnLog {param($Text,$Module)}
function Write-ErrorLog {param($Text,$Module)}
function Write-Ok {param($Text,$Module)}
function Write-Skip {param($Text,$Module)}
function Set-ModuleResult {param($Module,$Status,$Detail,$RebootRequired=$false) $script:Result=$Status}
function Read-ProcessOutput {param($Path,$Encoding) @()}
function Invoke-LoggedProcess {param($FilePath,$ArgumentList,$Label,$Module,$OutputEncoding,$CopyOutputToMainLog,$TimeoutSeconds) 0}
function Invoke-LoggedProcessWithHeartbeat {
    param($FilePath,$ArgumentList,$Label,$Module,$SuccessCodes,$HeartbeatSeconds,$OutputEncoding,$ShowProgressOutput,$TimeoutSeconds)
    $script:Calls+=,@($ArgumentList)
    if($ArgumentList[0] -eq 'export') {
        if($script:Case -eq 'export_failed'){return [pscustomobject]@{ExitCode=1;TimedOut=$false;OutputPath='';ErrorPath=''}}
        $Index=[array]::IndexOf($ArgumentList,'--output')
        $Export|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $ArgumentList[$Index+1] -Encoding UTF8
    }
    [pscustomobject]@{ExitCode=0;TimedOut=$false;OutputPath='';ErrorPath=''}
}
$PreviousSession=$env:MT_SESSION_DIR;$PreviousStatus=$env:MT_WINGET_EXCEPTION_STATUS_PATH
$Temp=Join-Path ([IO.Path]::GetTempPath()) ('MT-ExceptionTest-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Temp|Out-Null
try {
    $env:MT_SESSION_DIR=$Temp
    foreach($script:Case in @('normal','selective','invalid','blocked','export_failed')) {
        $script:Calls=@();$script:Result=$null
        & $Workflow | Out-Null
        $UpgradeCalls=@($script:Calls|Where-Object {$_[0] -eq 'upgrade' -and $_.Count -gt 4})
        if($Case -eq 'normal') {if(@($UpgradeCalls|Where-Object {'--all' -in $_}).Count -ne 1){throw 'Normal workflow changed.'}}
        elseif($Case -eq 'selective') {
            if($UpgradeCalls.Count -ne 1 -or 'Vendor.Allowed' -notin $UpgradeCalls[0] -or '--all' -in $UpgradeCalls[0]){throw 'Excluded package upgrade attempted.'}
            if($script:Result -ne 'WARN'){throw 'Exceptions hidden in result.'}
        }
        else {if($UpgradeCalls.Count -ne 0){throw 'Upgrade attempted despite blocked policy/export.'}}
        "PASS: actual Winget module $Case"
    }
    . (Join-Path $ProjectRoot 'app/modules/inventory/InventorySnapshotWriter.ps1')
    $SnapshotPath=Join-Path $Temp 'inventory.json'
    Copy-Item (Join-Path $ProjectRoot 'docs/inventory-example-1.0.json') $SnapshotPath
    Update-MTInventoryWingetExceptionsStatus -Path $SnapshotPath -WingetExceptionsStatus ([pscustomobject]@{status='active';excludedPackageIds=$Valid.excludedPackageIds})
    $Snapshot=Get-Content $SnapshotPath -Raw|ConvertFrom-Json
    if($Snapshot.maintenance.status -ne 'partial' -or $Snapshot.maintenance.data.wingetExceptions.excludedPackageIds.Count -ne 2){throw 'Inventory exceptions lost.'}
    'PASS: exceptions retained in inventory and maintenance coverage marked partial.'
} finally {
    $env:MT_SESSION_DIR=$PreviousSession;$env:MT_WINGET_EXCEPTION_STATUS_PATH=$PreviousStatus
    Remove-Item -LiteralPath $Temp -Recurse -Force -ErrorAction SilentlyContinue
}
