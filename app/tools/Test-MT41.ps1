[CmdletBinding()]
param([string]$ProjectRoot='', [string]$MsiIdentityFixture='', [string]$MsiIdentityVersion='')
if(-not $ProjectRoot){$ProjectRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)}
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Fixture=Join-Path $ProjectRoot ('launcher\build\MaintenanceToolkit-MT41Test-'+[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([datetime]::UtcNow,'W. Europe Standard Time').ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $Fixture | Out-Null
'Temporary fixture: '+$Fixture
$OriginalProgramData=$env:ProgramData
$env:ProgramData=Join-Path $Fixture 'state'
$script:Checks=0
function Assert-Test {param([bool]$Condition,[string]$Name) if(-not $Condition){throw ('FAIL: '+$Name)};$script:Checks++;'PASS: '+$Name}
function Assert-Rejected {param([scriptblock]$Action,[string]$Name) $Rejected=$false;try{& $Action | Out-Null}catch{$Rejected=$true};Assert-Test $Rejected $Name}
try {
    foreach($Name in @('Privileges','UpdateTrust','SelfUpdate','Scheduling','UpdateApplication')){. (Join-Path $ProjectRoot ('app/core/'+$Name+'.ps1'))}
    $HostingRequest=New-MTUpdateWebRequest 'https://www.kraugh.it/api/maintenance-toolkit/update-v1.json'
    Assert-Test ($HostingRequest.UserAgent -match '^MaintenanceToolkit/\d+\.\d+$') 'hosting requests identify only the MT product line before transport'
    & {
        $InstallRoot=Join-Path $Fixture 'registered-installation'
        $Entries=[ordered]@{
            bad=[pscustomobject]@{DisplayName='Unrelated application';InstallLocation='"C:\Unrelated Software"'}
            good=[pscustomobject]@{DisplayName='Maintenance Toolkit';Publisher='Kraugh';WindowsInstaller=1;InstallLocation=$InstallRoot}
        }
        function Get-ChildItem {param($Path,$ErrorAction) foreach($Key in $Entries.Keys){[pscustomobject]@{PSPath=$Key}}}
        function Get-ItemProperty {param($LiteralPath) $Entries[$LiteralPath]}
        Assert-Test ((Get-MTInstallKind $InstallRoot) -eq 'msi') 'unrelated quoted uninstall location does not block valid MSI identification'
        $Entries.bad.DisplayName='Maintenance Toolkit'
        Assert-Rejected {Get-MTInstallKind $InstallRoot} 'malformed MT registration remains fail-closed'
        $Entries.Remove('good');$Entries.bad.DisplayName='Unrelated application'
        Assert-Rejected {Get-MTInstallKind (Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'MTMissingRegistration')} 'Program Files without valid MSI registration never falls back to ZIP'
        Assert-Test ((Get-MTInstallKind (Join-Path $Fixture 'standalone')) -eq 'zip') 'unrelated invalid registry data does not prevent standalone ZIP classification'
    }
    if($MsiIdentityFixture) {
        Assert-Test (@(Assert-MTMsiIdentity $MsiIdentityFixture $MsiIdentityVersion).Count -eq 0) 'real MSI COM identity validation emits no pipeline values'
        Assert-Rejected {Assert-MTMsiIdentity $MsiIdentityFixture '0.0.0'} 'real MSI COM rejects different product version'
    }
    . (Join-Path $ProjectRoot 'app/core/Localization.ps1')
    foreach($Language in @('en-US','it-IT','fr-FR','es-ES','de-DE','zh-CN','ja-JP')) {
        $Resolved=Import-MTLanguage -ProjectRoot $ProjectRoot -Settings ([pscustomobject]@{Language=$Language;DefaultLanguage='en-US'})
        Assert-Test ($Resolved.Resolution.Language -eq $Language) ('language selected '+$Language)
        Assert-Test (-not [string]::IsNullOrWhiteSpace((Get-MTText $Resolved.Data 'MT41_MENU_UPDATE'))) ('localized menu '+$Language)
    }
    foreach($Language in @('en-US','it-IT','fr-FR','es-ES','de-DE','zh-CN','ja-JP','sv-SE')) {
        $Resource=Read-MTStrictJson (Join-Path $ProjectRoot ('languages/'+$Language+'.json'))
        $TaskText=Get-MTText $Resource 'MT41_TASK_INFO' @('MT','Ready','previous',20,'next','-ScheduledMode analysis')
        $ConditionText=Get-MTText $Resource 'MT41_TASK_CONDITIONS' @($true,$false,$false)
        Assert-Test ($Resource.PSObject.Properties['MT41_TASK_ACTIONS'] -and $TaskText.Contains('next') -and $ConditionText.Contains('True')) ('task management resource and formatting '+$Language)
    }
    $LanguageFixture=Join-Path $Fixture 'language'
    New-Item -ItemType Directory -Path (Join-Path $LanguageFixture 'languages'),(Join-Path $LanguageFixture 'config') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $LanguageFixture 'languages\en-US.json') '{"LANGUAGE_NAME":"English","EXAMPLE":"English fallback {0}"}'
    Set-Content -LiteralPath (Join-Path $LanguageFixture 'languages\fr-FR.json') '{"LANGUAGE_NAME":"Francais"}'
    Set-Content -LiteralPath (Join-Path $LanguageFixture 'config\settings.json') '{"Language":"auto","SelfUpdate":{"Management":"unknown","AutomaticInstallEnabled":false}}'
    $Fallback=Import-MTLanguage $LanguageFixture ([pscustomobject]@{Language='fr-FR';DefaultLanguage='en-US'})
    Assert-Test ((Get-MTText $Fallback.Data 'EXAMPLE' @('value')) -eq 'English fallback value') 'missing translation resolves to formatted English'
    $Fallback=Import-MTLanguage $LanguageFixture ([pscustomobject]@{Language='xx-YY';DefaultLanguage='fr-FR'})
    Assert-Test ($Fallback.Resolution.Language -eq 'en-US') 'unsupported language uses English regardless of configured default'
    $Fallback=Import-MTLanguage $LanguageFixture ([pscustomobject]@{Language='zh-TW';DefaultLanguage='en-US'})
    Assert-Test ($Fallback.Resolution.Language -eq 'en-US') 'traditional Chinese does not select simplified Chinese'
    Set-MTLanguagePreference $LanguageFixture 'fr-FR'
    $Stored=Read-MTStrictJson (Join-Path $LanguageFixture 'config\settings.json')
    Assert-Test ($Stored.Language -eq 'fr-FR' -and $Stored.SelfUpdate.Management -eq 'unknown' -and -not $Stored.SelfUpdate.AutomaticInstallEnabled) 'language persistence preserves update settings'
    $MainSource=Get-Content (Join-Path $ProjectRoot 'app/MaintenanceToolkit.ps1') -Raw -Encoding UTF8
    Assert-Test ($MainSource -notmatch '\[U\]|\[R\]' -and $MainSource -match '\[H\]') 'menu has Languages and no U/R entries'
    $ParseTokens=$null;$ParseErrors=$null
    $MainAst=[Management.Automation.Language.Parser]::ParseInput($MainSource,[ref]$ParseTokens,[ref]$ParseErrors)
    $LanguageFunction=$MainAst.Find({param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] -and $Node.Name -eq 'Invoke-MTLanguageMenu'},$true)
    $Parent=$LanguageFunction.Parent;$Nested=$false
    while($Parent){if($Parent -is [Management.Automation.Language.FunctionDefinitionAst]){$Nested=$true};$Parent=$Parent.Parent}
    Assert-Test (-not $Nested) 'language command defined before dispatcher, not inside menu loop'
    $MenuFunction=$MainAst.Find({param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] -and $Node.Name -eq 'Select-Modules'},$true)
    Invoke-Expression $LanguageFunction.Extent.Text
    Invoke-Expression $MenuFunction.Extent.Text
    foreach($Lang in @('en-US','it-IT','fr-FR','es-ES','de-DE','zh-CN','ja-JP')){Copy-Item -LiteralPath (Join-Path $ProjectRoot ('languages/'+$Lang+'.json')) -Destination (Join-Path $LanguageFixture 'languages') -Force}
    $Root=$LanguageFixture
    $script:MT4Settings=[pscustomobject]@{Language='en-US';DefaultLanguage='en-US'}
    $script:LanguageData=(Import-MTLanguage $Root $script:MT4Settings).Data
    $Catalog=@([pscustomobject]@{NameKey='MODULE_CONNECTIVITY';Name='Connectivity';Id=1;Key='Connectivity'})
    $Config=@{}
    $script:MenuInputs=New-Object 'System.Collections.Generic.Queue[string]'
    foreach($InputValue in @('h','3','q')){$script:MenuInputs.Enqueue($InputValue)}
    function Show-Menu {}
    function Read-Host {param($Prompt) if(-not $script:MenuInputs.Count){throw 'Unexpected menu prompt'};$script:MenuInputs.Dequeue()}
    function T {param($Key,$Arguments=@()) Get-MTText -LanguageData $script:LanguageData -Key $Key -Arguments $Arguments}
    $OriginalRuntimeLanguage=$env:MT_LANGUAGE
    try{
        $MenuResult=Select-Modules
        Assert-Test ($null -eq $MenuResult -and $script:MenuInputs.Count -eq 0) 'first H selection returns to menu then Q without aborting'
        Assert-Test ($script:CurrentLanguage -eq 'fr-FR' -and (Read-MTStrictJson (Join-Path $Root 'config/settings.json')).Language -eq 'fr-FR') 'real language menu changes and persists French'
    }finally{$env:MT_LANGUAGE=$OriginalRuntimeLanguage}
    $Standalone=[pscustomobject]@{Management='standalone';AutomaticInstallEnabled=$true}
    $Policy=[pscustomobject]@{Management='gpo';AutomaticInstallEnabled=$false}
    Assert-Test ((Resolve-MTSelfUpdateConfiguration).Management -eq 'unknown') 'missing config defaults to unknown'
    Assert-Test (-not (Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Standalone -MachinePolicy $Policy -PolicyPresent $true).CanInstall) 'GPO overrides local opt-in'
    Assert-Test ((Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Standalone).AutomaticInstallEnabled) 'explicit standalone opt-in'
    Assert-Test ((Resolve-MTSelfUpdateConfiguration -LocalConfiguration ([pscustomobject]@{Management='unknown';AutomaticInstallEnabled=$true})).Status -eq 'Invalid') 'unknown cannot enable automation'
    Assert-Test ((Resolve-MTSelfUpdateConfiguration -LocalConfiguration ([pscustomobject]@{Management='standalone';AutomaticInstallEnabled='false'})).Status -eq 'Invalid') 'string false is not a boolean'
    Assert-Test ((Resolve-MTSelfUpdateConfiguration -MachinePolicy $null -PolicyPresent $true).Status -eq 'Invalid') 'unreadable policy never falls back'
    $Duplicate=Join-Path $Fixture 'duplicate.json'
    Set-Content $Duplicate '{"SelfUpdate":{"Management":"gpo","management":"standalone"}}'
    Assert-Rejected {Read-MTStrictJson $Duplicate} 'case-variant duplicate keys rejected'
    Set-Content $Duplicate '{"SelfUpdate":{"Management":"gpo","\u004danagement":"standalone"}}'
    Assert-Rejected {Read-MTStrictJson $Duplicate} 'escaped duplicate keys rejected'
    $TestRoot=Join-Path $Fixture 'installation'
    foreach($Mode in @('maintenance','analysis','updates')){
        $Plan=New-MTSchedulePlan -ProjectRoot $TestRoot -Mode $Mode -Frequency weekly -Times @('03:00','15:30') -Days @('Monday','Friday') -JsonDestination '\\server\reports\'
        Assert-Test ($Plan.Arguments -like ('-ScheduledMode '+$Mode+'*')) ('explicit scheduled mode '+$Mode)
    }
    Assert-Rejected {New-MTSchedulePlan -ProjectRoot $TestRoot -Times @('25:00')} 'invalid time rejected'
    Assert-Rejected {New-MTSchedulePlan -ProjectRoot $TestRoot -Times @('03:00','03:00')} 'duplicate trigger time rejected'
    Assert-Rejected {New-MTSchedulePlan -ProjectRoot $TestRoot -Frequency weekly -Days @()} 'weekly schedule requires days'
    Assert-Rejected {New-MTSchedulePlan -ProjectRoot $TestRoot -JsonDestination 'reports'} 'relative destination rejected'
    Assert-Rejected {New-MTSchedulePlan -ProjectRoot $TestRoot -JsonDestination (Join-Path $TestRoot 'app')} 'destination inside runtime rejected'
    Assert-Test ((ConvertTo-MTWindowsArgument 'C:\Reports\') -eq '"C:\Reports\\"') 'trailing slash survives Windows quoting'
    $Now=[DateTimeOffset]::UtcNow
    $Manifest=[pscustomobject]@{schemaVersion='1.0';productId='maintenance-toolkit';version='4.1.0';channel='stable';architecture='x64';sequence=1;publishedAt=$Now.AddHours(-1).ToString('o');expiresAt=$Now.AddDays(1).ToString('o');minimumUpdaterVersion='4.1.0';artifacts=[pscustomobject]@{
        msi=[pscustomobject]@{fileName='MaintenanceToolkit-4_1_0.msi';url='https://github.com/Kraugh/maintenance-toolkit/releases/download/v4.1.0/MaintenanceToolkit-4_1_0.msi';sha256=('a'*64);size=10;upgradeCode='C1F2A740-51FD-4C40-A0F8-BE1D4E1B72A6'}
        zip=[pscustomobject]@{fileName='MaintenanceToolkit-4_1_0.zip';url='https://github.com/Kraugh/maintenance-toolkit/releases/download/v4.1.0/MaintenanceToolkit-4_1_0.zip';sha256=('b'*64);size=10;rootDirectory='Maintenance-Toolkit-4.1.0';catalog=[pscustomobject]@{fileName='MaintenanceToolkit-4_1_0-payload.cat';url='https://github.com/Kraugh/maintenance-toolkit/releases/download/v4.1.0/MaintenanceToolkit-4_1_0-payload.cat';size=10;sha256=('c'*64)}}}}
    Assert-Test ((Assert-MTUpdateManifest $Manifest '4.0.6').version -eq '4.1.0') 'valid manifest accepted'
    Assert-Rejected {Assert-MTUpdateManifest $Manifest '4.1.0'} 'equal version rejected'
    Assert-Rejected {Assert-MTUpdateManifest $Manifest '4.0.6' 2} 'metadata sequence rollback rejected'
    $Manifest.expiresAt=$Now.AddDays(-1).ToString('o')
    Assert-Rejected {Assert-MTUpdateManifest $Manifest '4.0.6'} 'expired metadata rejected'
    $Manifest.expiresAt=$Now.AddDays(1).ToString('o')
    Assert-Rejected {Assert-MTUpdateUrl 'https://github.com.attacker.example/package.zip'} 'lookalike origin rejected'
    Assert-Rejected {Assert-MTUpdateUrl 'http://github.com/package.zip'} 'HTTP payload rejected'
    $File=Join-Path $Fixture 'file.txt';Set-Content $File 'original'
    $Artifact=[pscustomobject]@{size=(Get-Item $File).Length;sha256=(Get-FileHash $File -Algorithm SHA256).Hash}
    Assert-MTArtifactHash $File $Artifact
    Add-Content $File 'tampered'
    Assert-Rejected {Assert-MTArtifactHash $File $Artifact} 'payload tampering rejected'
    Assert-Rejected {Assert-MTUpdateSignature $File} 'unsigned file rejected'
    Assert-Rejected {Save-MTUpdateDownload 'http://github.com/test.zip' (Join-Path $Fixture 'download.zip')} 'untrusted download rejected without network'
    Assert-Test (-not (Test-Path (Join-Path $Fixture 'download.zip.partial'))) 'failed download removes partial payload'
    # In-memory HTTP responses exercise production streaming/redirect handling,
    # without networking, credential access or a real update feed.
    function New-MTUpdateWebRequest {
        param($Url)
        $Request=[pscustomobject]@{AllowAutoRedirect=$true;Timeout=0;ReadWriteTimeout=0;Url=$Url}
        $Request | Add-Member ScriptMethod GetResponse {
            $Response=[pscustomobject]@{StatusCode=$script:HttpCode;ContentLength=$script:HttpLength;Headers=@{Location=$script:HttpLocation}}
            $Response | Add-Member ScriptMethod GetResponseStream {New-Object IO.MemoryStream (,[byte[]]$script:HttpBytes)}
            $Response | Add-Member ScriptMethod Close {}
            $Response
        }
        $Request
    }
    $script:HttpBytes=[Text.Encoding]::UTF8.GetBytes('test payload');$script:HttpLength=$script:HttpBytes.Length;$script:HttpCode=200;$script:HttpLocation=''
    $Download=Join-Path $Fixture 'download.zip'
    Save-MTUpdateDownload 'https://www.kraugh.it/test.zip' $Download 100
    Assert-Test ((Get-Content $Download -Raw) -eq 'test payload') 'streaming download promotes complete payload atomically'
    Remove-Item -LiteralPath $Download
    $script:HttpLength=100
    Assert-Rejected {Save-MTUpdateDownload 'https://www.kraugh.it/test.zip' $Download 100} 'interrupted short response rejected before promotion'
    Assert-Test (-not (Test-Path $Download) -and -not (Test-Path ($Download+'.partial'))) 'interrupted download removes partial and final payload'
    $script:HttpLength=-1
    Assert-Rejected {Save-MTUpdateDownload 'https://www.kraugh.it/test.zip' $Download 3} 'unknown-length response cannot exceed download limit'
    Assert-Test (-not (Test-Path ($Download+'.partial'))) 'oversized streamed payload cleaned'
    $script:HttpCode=302;$script:HttpLocation='https://attacker.invalid/payload.zip'
    Assert-Rejected {Save-MTUpdateDownload 'https://www.kraugh.it/test.zip' $Download} 'redirect to unauthorized origin rejected'
    $script:HttpLocation='https://www.kraugh.it/loop'
    Assert-Rejected {Save-MTUpdateDownload 'https://www.kraugh.it/test.zip' $Download} 'redirect loop bounded'
    $script:HttpCode=200;$script:HttpLength=$script:HttpBytes.Length

    # Launch only a harmless parameter probe, never the real maintenance script.
    $ProbeRoot=Join-Path $Fixture 'resume probe'
    New-Item -ItemType Directory -Path (Join-Path $ProbeRoot 'app') | Out-Null
    Set-Content -LiteralPath (Join-Path $ProbeRoot 'app\MaintenanceToolkit.ps1') 'param([Parameter(Mandatory)][string]$ResumeTransaction) [pscustomobject]@{id=$ResumeTransaction;extra=@($args).Count} | ConvertTo-Json -Compress'
    $ProbeTransaction=[pscustomobject]@{id=('a'*32);root=$ProbeRoot;resumeArguments=@('analysis','')}
    $ProbeArgs=Get-MTResumeProcessArguments $ProbeTransaction
    $ProbeOut=Join-Path $Fixture 'resume-output.json';$ProbeError=Join-Path $Fixture 'resume-error.txt'
    $Probe=Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $ProbeArgs -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $ProbeOut -RedirectStandardError $ProbeError
    Assert-Test ($Probe.ExitCode -eq 0) 'real PowerShell scheduled resume accepts host flags before File'
    $ProbeData=Get-Content $ProbeOut -Raw | ConvertFrom-Json
    Assert-Test ($ProbeData.id -eq $ProbeTransaction.id -and $ProbeData.extra -eq 0) 'resume preserves transaction id without stray script arguments'
    $ProbeTransaction.resumeArguments=@()
    Assert-Test ((Get-MTResumeProcessArguments $ProbeTransaction) -notmatch '-NonInteractive') 'manual resume retains interactive host'
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $EvilZip=Join-Path $Fixture 'evil.zip'
    $Zip=[IO.Compression.ZipFile]::Open($EvilZip,[IO.Compression.ZipArchiveMode]::Create)
    try {$null=$Zip.CreateEntry('Maintenance-Toolkit-4.1.0/../../escape.ps1')}finally{$Zip.Dispose()}
    Assert-Rejected {Expand-MTVerifiedZip $EvilZip (Join-Path $Fixture 'expanded') 'Maintenance-Toolkit-4.1.0'} 'ZIP path traversal rejected before extraction'
    Assert-Test (-not (Test-Path (Join-Path $Fixture 'expanded'))) 'rejected ZIP creates no payload'
    $Session=Join-Path $Fixture 'session';New-Item -ItemType Directory -Path $Session | Out-Null
    Set-Content (Join-Path $Session 'report.json') '{"ok":true}'
    $Publication=Publish-MTSessionJson $Session (Join-Path $Fixture 'reports')
    Assert-Test ($Publication.Status -eq 'Published' -and $Publication.Files -eq 1) 'JSON publication succeeded'
    $Publication=Publish-MTSessionJson $Session $File
    Assert-Test ($Publication.Status -eq 'WARN' -and (Test-Path (Join-Path $Session 'report.json'))) 'publication failure retains local JSON'

    # Windows mutation boundaries are mocked. No real task, installer or ACL change.
    function Test-MTAdministrator {$true}
    function Test-MTProtectedPath {param($Path) $true}
    function Initialize-MTProtectedDirectory {param($Path) New-Item -ItemType Directory -Path $Path -Force | Out-Null}
    function Get-MTUpdateStatePath {param($ProjectRoot) Join-Path $Fixture 's'}
    function Get-MTSelfUpdateConfiguration {param($ProjectRoot) Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Standalone}
    $script:Task=$null;$script:Registrations=0
    function Get-ScheduledTask {param($TaskPath,$TaskName,$ErrorAction) $script:Task}
    function New-ScheduledTaskTrigger {param([switch]$AtStartup,[switch]$Daily,[switch]$Weekly,$At,$DaysOfWeek) [pscustomobject]@{At=$At;Days=$DaysOfWeek}}
    function New-ScheduledTaskAction {param($Execute,$Argument,$WorkingDirectory) [pscustomobject]@{Execute=$Execute;Arguments=$Argument}}
    function New-ScheduledTaskPrincipal {param($UserId,$LogonType,$RunLevel) Assert-Test ($UserId -eq 'SYSTEM') 'task principal SYSTEM' | Out-Null; [pscustomobject]@{UserId=$UserId}}
    function New-ScheduledTaskSettingsSet {param([switch]$StartWhenAvailable,[switch]$AllowStartIfOnBatteries,[switch]$DontStopIfGoingOnBatteries,[switch]$RunOnlyIfNetworkAvailable,$MultipleInstances,$ExecutionTimeLimit) Assert-Test ($MultipleInstances -eq 'IgnoreNew') 'task prevents overlap' | Out-Null;$script:TaskSettings=[pscustomobject]@{Missed=[bool]$StartWhenAvailable;Battery=[bool]$AllowStartIfOnBatteries;ContinueBattery=[bool]$DontStopIfGoingOnBatteries;Network=[bool]$RunOnlyIfNetworkAvailable};$script:TaskSettings}
    function Get-ScheduledTaskInfo {param($TaskPath,$TaskName,$ErrorAction) [pscustomobject]@{LastRunTime=[datetime]'2026-10-14T03:00:00';LastTaskResult=20;NextRunTime=[datetime]'2026-10-15T03:00:00'}}
    $script:Removals=0
    function Unregister-ScheduledTask {param($TaskPath,$TaskName,[switch]$Confirm,$ErrorAction) $script:Removals++;$script:Task=$null}
    function Register-ScheduledTask {param($TaskPath,$TaskName,$Action,$Trigger,$Principal,$Settings,[switch]$Force,$Xml) $script:Registrations++}
    New-Item -ItemType Directory -Path $TestRoot | Out-Null
    Set-Content (Join-Path $TestRoot 'MaintenanceToolkit.exe') 'dummy executable, never run'
    $Plan=New-MTSchedulePlan $TestRoot -Mode analysis -Frequency startup
    $Result=Register-MTStandaloneSchedule $Plan (Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Standalone)
    Assert-Test ($Result.TaskName -eq 'Maintenance Toolkit - Standalone Managed' -and $script:Registrations -eq 1) 'create uses standalone-owned task'
    Assert-Test ($script:TaskSettings.Missed -and -not $script:TaskSettings.Battery -and -not $script:TaskSettings.Network) 'task defaults recover missed run, require AC, no network gate'
    $script:Task=[pscustomobject]@{Actions=@([pscustomobject]@{Execute=$Plan.Executable})}
    Assert-Rejected {Register-MTStandaloneSchedule $Plan (Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Standalone)} 'existing owned task requires replacement consent'
    $Result=Register-MTStandaloneSchedule $Plan (Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Standalone) -ReplaceExisting
    Assert-Test ($Result.TaskName -eq 'Maintenance Toolkit - MSI Managed') 'MSI-owned task reused instead of adding a competing task'
    $script:Task=[pscustomobject]@{Actions=@([pscustomobject]@{Execute='C:\Other\MaintenanceToolkit.exe'})}
    Assert-Rejected {Register-MTStandaloneSchedule $Plan (Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Standalone) -ReplaceExisting} 'foreign task cannot be replaced'
    $script:Task=$null
    Assert-Rejected {Register-MTStandaloneSchedule $Plan (Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Policy)} 'GPO cannot create standalone task'
    Assert-Test ($null -eq (Get-MTStandaloneSchedule $TestRoot)) 'inspection reports absent task without creation'
    $script:Task=[pscustomobject]@{Actions=@([pscustomobject]@{Execute=$Plan.Executable;Arguments=$Plan.Arguments});State='Ready'}
    $Inspection=Get-MTStandaloneSchedule $TestRoot
    Assert-Test ($Inspection.LastTaskResult -eq 20 -and $Inspection.NextRunTime -eq [datetime]'2026-10-15T03:00:00') 'inspection returns last result and next run from scheduler'
    Assert-Rejected {Remove-MTStandaloneSchedule $TestRoot (Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Standalone)} 'removal requires explicit confirmation'
    Assert-Rejected {Remove-MTStandaloneSchedule $TestRoot (Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Policy) -Confirmed} 'GPO removal rejected'
    Assert-Test ($script:Removals -eq 0) 'rejected removal has no Windows mutation'
    $Removed=Remove-MTStandaloneSchedule $TestRoot (Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Standalone) -Confirmed
    Assert-Test ($script:Removals -eq 1 -and $null -eq $script:Task) 'confirmed removal unregisters only the owned task'
    Assert-Rejected {Remove-MTStandaloneSchedule $TestRoot (Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Standalone) -Confirmed} 'missing task is not removed'
    $script:Task=[pscustomobject]@{Actions=@([pscustomobject]@{Execute='C:\Other\MaintenanceToolkit.exe'})}
    Assert-Rejected {Remove-MTStandaloneSchedule $TestRoot (Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Standalone) -Confirmed} 'foreign task cannot be removed'
    $script:Task=$null
    $CustomPlan=New-MTSchedulePlan $TestRoot -Mode updates -Frequency daily -StartWhenAvailable $false -AllowBattery $true -RequireNetwork $true
    $null=Register-MTStandaloneSchedule $CustomPlan (Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Standalone)
    Assert-Test (-not $script:TaskSettings.Missed -and $script:TaskSettings.Battery -and $script:TaskSettings.ContinueBattery -and $script:TaskSettings.Network) 'explicit power, missed-run and network settings reach scheduler'
    $Events=@(Get-Content (Join-Path (Get-MTUpdateStatePath $TestRoot) 'schedule-events.jsonl') | ForEach-Object {$_ | ConvertFrom-Json})
    Assert-Test ($Events.operation -contains 'saved' -and $Events.operation -contains 'removed') 'task changes recorded in protected diagnostic journal'
    $script:Task=[pscustomobject]@{Actions=@([pscustomobject]@{Execute=$Plan.Executable;Arguments=$Plan.Arguments});State='Ready'}
    $script:MenuInputs.Enqueue('2')
    $Before=$script:Registrations
    Invoke-MTScheduleWizard $TestRoot
    Assert-Test ($script:MenuInputs.Count -eq 0 -and $script:Registrations -eq $Before) 'real wizard inspection returns without registration'
    $script:MenuInputs.Enqueue('3');$script:MenuInputs.Enqueue('NO')
    $Before=$script:Removals
    Invoke-MTScheduleWizard $TestRoot
    Assert-Test ($script:MenuInputs.Count -eq 0 -and $script:Removals -eq $Before) 'wizard removal cancellation leaves task intact'
    $script:MenuInputs.Enqueue('3');$script:MenuInputs.Enqueue('YES')
    Invoke-MTScheduleWizard $TestRoot
    Assert-Test ($script:MenuInputs.Count -eq 0 -and $script:Removals -eq $Before+1) 'wizard confirmed removal returns safely'
    foreach($Answer in @('1','3','3','','NO','YES','YES','YES','NO')){$script:MenuInputs.Enqueue($Answer)}
    $Before=$script:Registrations
    Invoke-MTScheduleWizard $TestRoot
    Assert-Test ($script:MenuInputs.Count -eq 0 -and $script:Registrations -eq $Before+1 -and $script:TaskSettings.Network -and $script:TaskSettings.Battery -and -not $script:TaskSettings.Missed) 'real startup wizard applies explicit conditions and consent'
    function Get-MTSelfUpdateConfiguration {param($ProjectRoot) Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Policy}
    Assert-Rejected {Register-MTStandaloneSchedule $Plan (Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Standalone)} 'policy changed after preview blocks registration'
    Assert-Rejected {Remove-MTStandaloneSchedule $TestRoot (Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Standalone) -Confirmed} 'policy changed after preview blocks removal'
    function Get-MTSelfUpdateConfiguration {param($ProjectRoot) Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Standalone}

    function Assert-MTUpdateCatalog {param($Directory,$Catalog)}
    function Assert-MTUpdateSignature {param($Path)}
    $State=Get-MTUpdateStatePath $TestRoot;New-Item -ItemType Directory -Path $State -Force | Out-Null
    function New-TestTransaction {
        $Id=[guid]::NewGuid().ToString('N');$Work=Join-Path $State $Id;$Payload=Join-Path $Work 'expanded\Maintenance-Toolkit-4.1.0'
        foreach($Dir in @('config','app')){New-Item -ItemType Directory -Path (Join-Path $Payload $Dir) -Force | Out-Null}
        Set-Content (Join-Path $Payload 'config\version.json') '{"Version":"4.1.0"}'
        Set-Content (Join-Path $Payload 'config\settings.json') '{"newDefault":true}'
        Set-Content (Join-Path $Payload 'app\fixture.ps1') '# never executed'
        [pscustomobject]@{schemaVersion='1.0';id=$Id;root=$TestRoot;phase='Prepared';kind='zip';version='4.1.0';sequence=1;work=$Work;payload=$Payload;msi=$null;resumeArguments=@('analysis');resumeStarted=$false;errorCode=$null}
    }
    New-Item -ItemType Directory -Path (Join-Path $TestRoot 'config') -Force | Out-Null
    Set-Content (Join-Path $TestRoot 'config\version.json') '{"Version":"4.0.6"}'
    Set-Content (Join-Path $TestRoot 'config\settings.json') '{"preserved":true}'
    $Transaction=New-TestTransaction
    $Result=Invoke-MTPreparedApplication $Transaction
    Assert-Test ($Result.Status -eq 'Verified') 'ZIP application verified on fictitious installation'
    Assert-Test ((Read-MTStrictJson (Join-Path $TestRoot 'config\settings.json')).preserved) 'local settings preserved'
    $Resume=Receive-MTResume $TestRoot $Transaction.id
    Assert-Test ($Resume.resumeStarted) 'resume handoff consumed'
    Assert-Test (-not (Test-Path $Transaction.work) -and (Read-MTStrictJson (Join-Path $State 'last-cleanup.json')).status -eq 'Removed') 'consumed verified update cleans payload and records exact work path'
    Assert-Rejected {Receive-MTResume $TestRoot $Transaction.id} 'handoff cannot be replayed'
    Set-Content (Join-Path $TestRoot 'config\version.json') '{"Version":"4.0.6"}'
    $Transaction=New-TestTransaction
    # Fail only after the swap; preparation against the sibling still verifies.
    function Assert-MTInstalledPayload {param($InstalledRoot,$Payload,$Version,$Kind) if($InstalledRoot -eq $TestRoot){throw 'MT41_POSTVERIFY_FAILED'}}
    $Result=Invoke-MTPreparedApplication $Transaction
    Assert-Test ($Result.Status -eq 'Recovered' -and -not $Result.CanResume) 'failed ZIP postverification recovers without continuing maintenance'
    Assert-Test ((Read-MTStrictJson (Join-Path $TestRoot 'config\version.json')).Version -eq '4.0.6') 'ZIP recovery restored previous version'
    $Transaction=New-TestTransaction;$Transaction.kind='msi';$Transaction.msi=Join-Path $Transaction.work 'dummy.msi'
    Set-Content $Transaction.msi 'dummy MSI, never executed'
    New-Item -ItemType Directory -Path (Join-Path $Transaction.work 'metadata') | Out-Null
    $Manifest | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $Transaction.work 'metadata\update-v1.json')
    function Assert-MTArtifactHash {param($Path,$Artifact)}
    function Assert-MTMsiIdentity {param($Path,$Version)}
    function Get-ItemProperty {param($Path,$ErrorAction) $null}
    function Start-Process {param($FilePath,$ArgumentList,[switch]$Wait,[switch]$PassThru,$WindowStyle) Assert-Test ($ArgumentList -match 'REBOOT=ReallySuppress' -and $ArgumentList -match 'CREATE_TASK=0') 'MSI command suppresses restart and task creation' | Out-Null;[pscustomobject]@{ExitCode=1603}}
    $Result=Invoke-MTPreparedApplication $Transaction
    Assert-Test ($Result.Status -eq 'RecoveryRequired' -and -not $Result.CanResume) 'uncertain MSI state blocks maintenance'
    Assert-Rejected {Assert-MTNoPendingRecovery $TestRoot} 'pending recovery blocks fresh execution'
    # Existing old installation remains intact in this simulated MSI failure.
    Assert-Test ((Repair-MTUpdateTransaction $TestRoot) -eq 'Recovered') 'explicit recovery verifies previous application hashes'
    # Exercise the actual Windows directory-rename failure, without any installer.
    # Reload production validation after the intentionally mocked postverify test.
    . (Join-Path $ProjectRoot 'app/core/UpdateApplication.ps1')
    $Transaction=New-TestTransaction
    Set-Content -LiteralPath (Join-Path $TestRoot 'MaintenanceToolkit.exe') 'harmless locked fixture, never executed'
    $BeforeHashes=@(Get-MTRecoveryHashes $TestRoot)
    $Locked=[IO.File]::Open((Join-Path $TestRoot 'MaintenanceToolkit.exe'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try{$Result=Invoke-MTPreparedApplication $Transaction}finally{$Locked.Dispose()}
    Assert-Test ($Result.Status -eq 'RecoveryRequired' -and -not $Result.CanResume) 'actual locked-file ZIP rename blocks maintenance'
    Assert-Test (-not (Test-Path ($TestRoot+'.mt-backup-'+$Transaction.id))) 'failed atomic rename creates no partial backup'
    Assert-MTRecoveryHashes $TestRoot $BeforeHashes
    Assert-Test ((Repair-MTUpdateTransaction $TestRoot) -eq 'Recovered') 'actual locked-file recovery verifies intact original bytes'
    'TOTAL PASS: '+$script:Checks
} finally {
    $env:ProgramData=$OriginalProgramData
    $Resolved=[IO.Path]::GetFullPath($Fixture)
    $ExpectedParent=[IO.Path]::GetFullPath((Join-Path $ProjectRoot 'launcher\build'))
    if((Split-Path -Parent $Resolved) -eq $ExpectedParent -and (Split-Path -Leaf $Resolved) -like 'MaintenanceToolkit-MT41Test-*') {Remove-Item -LiteralPath $Resolved -Recurse -Force}
    'Temporary fixture removed: '+(-not (Test-Path -LiteralPath $Fixture))
}
