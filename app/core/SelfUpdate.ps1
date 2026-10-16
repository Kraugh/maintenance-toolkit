# MT 4.1 ownership, signed staging and transactional application.
function Test-MTProtectedPath {
    param([Parameter(Mandatory)][string]$Path,[switch]$AllowChildCreation)
    try {
        $Item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        $Current = $Item.FullName
        $First=$true
        while ($Current) {
            $Node = Get-Item -LiteralPath $Current -Force -ErrorAction Stop
            if (($Node.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
            $Acl = Get-Acl -LiteralPath $Current -ErrorAction Stop
            $Owner = $Acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
            if ($Owner -notin @('S-1-5-18','S-1-5-32-544','S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464')) { return $false }
            $Write = if ($First -and -not $AllowChildCreation) { [Security.AccessControl.FileSystemRights]'WriteData,AppendData,WriteAttributes,WriteExtendedAttributes,Delete,DeleteSubdirectoriesAndFiles,ChangePermissions,TakeOwnership' } else { [Security.AccessControl.FileSystemRights]'DeleteSubdirectoriesAndFiles,ChangePermissions,TakeOwnership' }
            foreach ($Rule in $Acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])) {
                if ($Rule.AccessControlType -eq 'Allow' -and ($Rule.FileSystemRights -band $Write) -ne 0 -and $Rule.IdentityReference.Value -notin @('S-1-5-18','S-1-5-32-544','S-1-3-0','S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464') -and ($Rule.PropagationFlags -band [Security.AccessControl.PropagationFlags]::InheritOnly) -eq 0) { return $false }
            }
            $Current = Split-Path -Parent $Current
            $First=$false
        }
        return $true
    } catch { return $false }
}

function Resolve-MTSelfUpdateConfiguration {
    [CmdletBinding()]
    param($LocalConfiguration, $MachinePolicy, [bool]$PolicyPresent=$false)
    $Source = 'Default'; $Data = $null
    if ($PolicyPresent) { $Source='MachinePolicy'; $Data=$MachinePolicy }
    elseif ($null -ne $LocalConfiguration) { $Source='LocalJson'; $Data=$LocalConfiguration }
    $Management='unknown'; $Automatic=$false; $Status='Valid'
    if ($null -ne $Data) {
        if($Data -isnot [pscustomobject]){$Status='Invalid'}
        $Names=@($Data.PSObject.Properties.Name)
        if (@($Names | Where-Object { $_ -notin @('Management','AutomaticInstallEnabled') }).Count -gt 0) { $Status='Invalid' }
        if ($Names -contains 'Management') {
            if ($Data.Management -isnot [string] -or $Data.Management -cnotin @('unknown','standalone','gpo')) { $Status='Invalid' }
            else { $Management=$Data.Management }
        }
        if ($Names -contains 'AutomaticInstallEnabled') {
            if ($Data.AutomaticInstallEnabled -isnot [bool]) { $Status='Invalid' } else { $Automatic=$Data.AutomaticInstallEnabled }
        }
    } elseif ($PolicyPresent) { $Status='Invalid' }
    if ($Automatic -and $Management -ne 'standalone') { $Status='Invalid' }
    if ($Status -ne 'Valid') { $Management='unknown'; $Automatic=$false }
    [pscustomobject]@{Status=$Status; Source=$Source; Management=$Management; AutomaticInstallEnabled=$Automatic; CanInstall=($Status -eq 'Valid' -and $Management -eq 'standalone')}
}

function Get-MTSelfUpdateConfiguration {
    param([Parameter(Mandatory)][string]$ProjectRoot)
    $PolicyPath='HKLM:\SOFTWARE\Policies\Kraugh\Maintenance Toolkit\SelfUpdate'
    try {
        if (Test-Path -LiteralPath $PolicyPath -ErrorAction Stop) {
            $Key=Get-Item -LiteralPath $PolicyPath -ErrorAction Stop
            $PolicyAcl=$Key.GetAccessControl()
            if($PolicyAcl.GetOwner([Security.Principal.SecurityIdentifier]).Value -notin @('S-1-5-18','S-1-5-32-544')){throw 'MT41_POLICY_INVALID'}
            $PolicyWrite=[Security.AccessControl.RegistryRights]'SetValue,CreateSubKey,Delete,ChangePermissions,TakeOwnership'
            foreach($Rule in $PolicyAcl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])) {
                if($Rule.AccessControlType -eq 'Allow' -and ($Rule.RegistryRights -band $PolicyWrite) -ne 0 -and $Rule.IdentityReference.Value -notin @('S-1-5-18','S-1-5-32-544','S-1-3-0')){throw 'MT41_POLICY_INVALID'}
            }
            $Data=[pscustomobject]@{}
            foreach($Name in $Key.GetValueNames()) {
                if ($Name -notin @('Management','AutomaticInstallEnabled')) { throw 'MT41_POLICY_INVALID' }
                $Value=$Key.GetValue($Name)
                if ($Name -eq 'AutomaticInstallEnabled') {
                    if ($Key.GetValueKind($Name) -ne 'DWord' -or $Value -notin @(0,1)) { throw 'MT41_POLICY_INVALID' }
                    $Value=[bool]$Value
                } elseif ($Key.GetValueKind($Name) -ne 'String') { throw 'MT41_POLICY_INVALID' }
                $Data | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
            }
            return Resolve-MTSelfUpdateConfiguration -MachinePolicy $Data -PolicyPresent $true
        }
        $Path=Join-Path $ProjectRoot 'config/settings.json'
        $Settings=Read-MTStrictJson -Path $Path
        $Local=$null
        if ($Settings.PSObject.Properties['SelfUpdate']) { $Local=$Settings.SelfUpdate; if ($null -eq $Local) { throw 'MT41_CONFIG_INVALID' } }
        $PreferencePath=Join-Path (Get-MTUpdateStatePath $ProjectRoot) 'preferences.json'
        if(Test-Path -LiteralPath $PreferencePath) {
            if(-not (Test-MTProtectedPath $PreferencePath)){throw 'MT41_CONFIG_INVALID'}
            $Local=Read-MTStrictJson $PreferencePath
        }
        $Result=Resolve-MTSelfUpdateConfiguration -LocalConfiguration $Local
        if ($Result.AutomaticInstallEnabled -and -not (Test-MTProtectedPath -Path $(if(Test-Path -LiteralPath $PreferencePath){$PreferencePath}else{$Path}))) { return Resolve-MTSelfUpdateConfiguration -MachinePolicy $null -PolicyPresent $true }
        $Result
    } catch { Resolve-MTSelfUpdateConfiguration -MachinePolicy $null -PolicyPresent $true }
}

function Get-MTInstallationId {
    param([string]$ProjectRoot)
    $Hash=[Security.Cryptography.SHA256]::Create()
    try {[BitConverter]::ToString($Hash.ComputeHash([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\').ToLowerInvariant()))).Replace('-','').Substring(0,24)}finally{$Hash.Dispose()}
}

function Get-MTUpdateStatePath {
    param([string]$ProjectRoot)
    Join-Path $env:ProgramData ('Kraugh\MaintenanceToolkit\self-update\'+(Get-MTInstallationId $ProjectRoot))
}

function Initialize-MTProtectedDirectory {
    param([string]$Path)
    if(Test-Path -LiteralPath $Path) {
        if(-not (Test-MTProtectedPath $Path)){throw 'MT41_ROOT_UNPROTECTED'}
        return
    }
    $Parent=Split-Path -Parent $Path
    if(-not (Test-Path -LiteralPath $Parent)){Initialize-MTProtectedDirectory $Parent}
    if(-not (Test-MTProtectedPath $Parent -AllowChildCreation)){throw 'MT41_ROOT_UNPROTECTED'}
    New-Item -ItemType Directory -Path $Path -ErrorAction Stop | Out-Null
    $Acl=New-Object Security.AccessControl.DirectorySecurity
    $Acl.SetSecurityDescriptorSddlForm('O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)')
    Set-Acl -LiteralPath $Path -AclObject $Acl -ErrorAction Stop
}

function Save-MTUpdateJson {
    param([string]$Path,$Data)
    $Temp=$Path+'.'+[guid]::NewGuid().ToString('N')+'.partial'
    try {
        $Data | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Temp -Encoding UTF8 -ErrorAction Stop
        Move-Item -LiteralPath $Temp -Destination $Path -Force -ErrorAction Stop
    }finally{if(Test-Path -LiteralPath $Temp){Remove-Item -LiteralPath $Temp -Force}}
}

function Set-MTStandalonePreference {
    param([string]$ProjectRoot,[bool]$AutomaticInstallEnabled,[switch]$PreserveUnknown)
    if(-not (Test-MTAdministrator)){throw 'MT41_ADMIN_REQUIRED'}
    if(Test-Path 'HKLM:\SOFTWARE\Policies\Kraugh\Maintenance Toolkit\SelfUpdate'){throw 'MT41_POLICY_OWNED'}
    if(-not (Test-MTProtectedPath $ProjectRoot)){throw 'MT41_ROOT_UNPROTECTED'}
    if((Get-MTSelfUpdateConfiguration $ProjectRoot).Management -eq 'gpo'){throw 'MT41_MANAGEMENT_BLOCKED'}
    if($PreserveUnknown -and $AutomaticInstallEnabled){throw 'MT41_CONFIG_INVALID'}
    $State=Get-MTUpdateStatePath $ProjectRoot
    Initialize-MTProtectedDirectory $State
    $Management=if($PreserveUnknown){'unknown'}else{'standalone'}
    Save-MTUpdateJson (Join-Path $State 'preferences.json') ([pscustomobject]@{Management=$Management;AutomaticInstallEnabled=$AutomaticInstallEnabled})
}

function Get-MTManagementMenuAvailability {
    param([string]$ProjectRoot)
    $Configuration=Get-MTSelfUpdateConfiguration $ProjectRoot
    [pscustomobject]@{
        Preferences=($Configuration.Status -eq 'Valid' -and $Configuration.Management -ne 'gpo' -and $Configuration.Source -ne 'MachinePolicy')
        Schedule=[bool]$Configuration.CanInstall
    }
}

function Enter-MTInstallationLock {
    param([string]$ProjectRoot,[int]$TimeoutSeconds=0)
    $Name='Global\Kraugh.MT.'+(Get-MTInstallationId $ProjectRoot)
    $Security=New-Object Security.AccessControl.MutexSecurity
    foreach($Sid in @('S-1-5-18','S-1-5-32-544')) {
        $Security.AddAccessRule((New-Object Security.AccessControl.MutexAccessRule ((New-Object Security.Principal.SecurityIdentifier $Sid),[Security.AccessControl.MutexRights]::FullControl,'Allow')))
    }
    $Created=$false
    $Mutex=New-Object Threading.Mutex($false,$Name,[ref]$Created,$Security)
    try {
        $Acquired=$false
        try{$Acquired=$Mutex.WaitOne([timespan]::FromSeconds($TimeoutSeconds))}catch [Threading.AbandonedMutexException]{$Acquired=$true}
        if(-not $Acquired){throw 'MT41_BUSY'}
        $Mutex
    }catch{$Mutex.Dispose();throw}
}

function Exit-MTInstallationLock {
    param($Mutex)
    if($Mutex){try{$Mutex.ReleaseMutex()}finally{$Mutex.Dispose()}}
}

function Get-MTInstallKind {
    param([string]$ProjectRoot)
    $Root=[IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')
    $Matches=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction Stop | ForEach-Object {
        $Product=Get-ItemProperty -LiteralPath $_.PSPath
        if($Product.PSObject.Properties['InstallLocation'] -and $Product.InstallLocation){
            try{$Location=[IO.Path]::GetFullPath($Product.InstallLocation).TrimEnd('\')}
            catch{
                # An unrelated malformed uninstall entry cannot identify this installation.
                # Malformed MT registration remains ambiguous and must fail closed.
                if($Product.PSObject.Properties['DisplayName'] -and $Product.DisplayName -eq 'Maintenance Toolkit'){throw 'MT41_INSTALL_KIND_INVALID'}
                return
            }
            if($Location -eq $Root){$Product}
        }
    })
    if($Matches.Count -gt 1){throw 'MT41_INSTALL_KIND_INVALID'}
    if($Matches.Count -eq 1) {
        if($Matches[0].DisplayName -ne 'Maintenance Toolkit' -or $Matches[0].Publisher -ne 'Kraugh' -or $Matches[0].WindowsInstaller -ne 1){throw 'MT41_INSTALL_KIND_INVALID'}
        return 'msi'
    }
    if($Root.StartsWith([Environment]::GetFolderPath('ProgramFiles'),[StringComparison]::OrdinalIgnoreCase)){throw 'MT41_INSTALL_KIND_INVALID'}
    'zip'
}

function Remove-MTUpdateWork {
    param([string]$StatePath,[string]$Id)
    if($Id -notmatch '^[a-f0-9]{32}$'){throw 'MT41_STATE_INVALID'}
    $Target=[IO.Path]::GetFullPath((Join-Path $StatePath $Id))
    if((Split-Path -Parent $Target) -ne [IO.Path]::GetFullPath($StatePath).TrimEnd('\')){throw 'MT41_STATE_INVALID'}
    if(Test-Path -LiteralPath $Target){Remove-Item -LiteralPath $Target -Recurse -Force -ErrorAction Stop}
}

function New-MTPreparedUpdate {
    param([string]$ProjectRoot,[string]$InstalledVersion,[string[]]$ResumeArguments=@())
    if(-not (Test-MTAdministrator)){throw 'MT41_ADMIN_REQUIRED'}
    $Configuration=Get-MTSelfUpdateConfiguration $ProjectRoot
    if(-not $Configuration.CanInstall){throw 'MT41_MANAGEMENT_BLOCKED'}
    if(-not (Test-MTProtectedPath $ProjectRoot)){throw 'MT41_ROOT_UNPROTECTED'}
    $StatePath=Get-MTUpdateStatePath $ProjectRoot
    Initialize-MTProtectedDirectory $StatePath
    $JournalPath=Join-Path $StatePath 'transaction.json'
    if(Test-Path -LiteralPath $JournalPath){
        $Old=Read-MTStrictJson $JournalPath
        if($Old.phase -notin @('Verified','Recovered','Consumed','PreparationFailed')){throw 'MT41_RECOVERY_REQUIRED'}
    }
    $Id=[guid]::NewGuid().ToString('N');$Work=Join-Path $StatePath $Id
    Initialize-MTProtectedDirectory $Work
    $Metadata=Join-Path $Work 'metadata';Initialize-MTProtectedDirectory $Metadata
    try {
        [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
        Save-MTUpdateDownload $script:MTUpdateManifestUrl (Join-Path $Metadata 'update-v1.json') 1048576
        Save-MTUpdateDownload ($script:MTUpdateManifestUrl.Replace('.json','.cat')) (Join-Path $Work 'manifest.cat') 1048576
        Assert-MTUpdateCatalog $Metadata (Join-Path $Work 'manifest.cat')
        $MinimumSequence=0L
        $SequencePath=Join-Path $StatePath 'sequence.json'
        if(Test-Path $SequencePath){$MinimumSequence=(Read-MTStrictJson $SequencePath).sequence}
        $Manifest=Assert-MTUpdateManifest (Read-MTStrictJson (Join-Path $Metadata 'update-v1.json')) $InstalledVersion $MinimumSequence
        $ZipPath=Join-Path $Work $Manifest.artifacts.zip.fileName
        Save-MTUpdateDownload $Manifest.artifacts.zip.url $ZipPath $Manifest.artifacts.zip.size
        Assert-MTArtifactHash $ZipPath $Manifest.artifacts.zip
        $CatalogPath=Join-Path $Work 'payload.cat'
        Save-MTUpdateDownload $Manifest.artifacts.zip.catalog.url $CatalogPath 1048576
        Assert-MTArtifactHash $CatalogPath $Manifest.artifacts.zip.catalog
        $Expanded=Join-Path $Work 'expanded'
        Expand-MTVerifiedZip $ZipPath $Expanded $Manifest.artifacts.zip.rootDirectory
        $Payload=Join-Path $Expanded $Manifest.artifacts.zip.rootDirectory
        Assert-MTUpdateCatalog $Payload $CatalogPath
        Assert-MTUpdateSignature (Join-Path $Payload 'MaintenanceToolkit.exe')
        if((Read-MTStrictJson (Join-Path $Payload 'config/version.json')).Version -ne $Manifest.version){throw 'MT41_METADATA_INVALID'}
        $Kind=Get-MTInstallKind $ProjectRoot
        $MsiPath=$null
        if($Kind -eq 'msi'){
            $MsiPath=Join-Path $Work $Manifest.artifacts.msi.fileName
            Save-MTUpdateDownload $Manifest.artifacts.msi.url $MsiPath $Manifest.artifacts.msi.size
            Assert-MTArtifactHash $MsiPath $Manifest.artifacts.msi
            Assert-MTUpdateSignature $MsiPath
            Assert-MTMsiIdentity $MsiPath $Manifest.version
        }
        # Only authenticated payloads may lose Mark of the Web. The signed
        # catalog covers scripts/resources; MSI also passed embedded identity.
        foreach($VerifiedFile in @(Get-ChildItem -LiteralPath $Payload -Recurse -File)) {
            Unblock-File -LiteralPath $VerifiedFile.FullName -ErrorAction Stop
        }
        if($MsiPath){Unblock-File -LiteralPath $MsiPath -ErrorAction Stop}
        $CurrentProcess=Get-Process -Id $PID
        $Journal=[pscustomobject]@{schemaVersion='1.0';id=$Id;root=[IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\');phase='Prepared';kind=$Kind;version=$Manifest.version;sequence=$Manifest.sequence;work=$Work;payload=$Payload;msi=$MsiPath;resumeArguments=@($ResumeArguments);parentPid=$PID;parentStartedAt=$CurrentProcess.StartTime.ToUniversalTime().ToString('o');resumeStarted=$false;errorCode=$null}
        foreach($Relative in @('app/core/SelfUpdate.ps1','app/core/UpdateTrust.ps1','app/core/UpdateApplication.ps1','app/core/Scheduling.ps1','app/core/Privileges.ps1','app/tools/Invoke-MTUpdateHelper.ps1')) {
            $Source=Join-Path $ProjectRoot $Relative
            if(-not (Test-MTProtectedPath $Source)){throw 'MT41_ROOT_UNPROTECTED'}
            Copy-Item -LiteralPath $Source -Destination $Work
        }
        Save-MTUpdateJson $JournalPath $Journal
        $Journal
    }catch{
        $Code=if($_.Exception.Message -match '^MT41_[A-Z_]+$'){$_.Exception.Message}else{'MT41_UPDATE_WARN'}
        Save-MTUpdateJson (Join-Path $StatePath 'last-preparation.json') ([pscustomobject]@{attemptId=$Id;at=[DateTimeOffset]::Now.ToString('o');errorCode=$Code;installationChanged=$false})
        Remove-MTUpdateWork $StatePath $Id
        throw
    }
}

function Start-MTPreparedHelper {
    param($Transaction)
    $ParentId=0
    $ProcessInfo=Get-CimInstance Win32_Process -Filter ('ProcessId='+$PID) -ErrorAction Stop
    $ParentId=[int]$ProcessInfo.ParentProcessId
    $Parent=Get-Process -Id $ParentId -ErrorAction SilentlyContinue
    if($Parent -and $Parent.Path -eq (Join-Path $Transaction.root 'MaintenanceToolkit.exe')) {
        $Transaction | Add-Member -NotePropertyName launcherPid -NotePropertyValue $Parent.Id -Force
        $Transaction | Add-Member -NotePropertyName launcherStartedAt -NotePropertyValue $Parent.StartTime.ToUniversalTime().ToString('o') -Force
    }
    Save-MTUpdateJson (Join-Path (Get-MTUpdateStatePath $Transaction.root) 'transaction.json') $Transaction
    $Args='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File '+(ConvertTo-MTWindowsArgument (Join-Path $Transaction.work 'Invoke-MTUpdateHelper.ps1'))+' -ProjectRoot '+(ConvertTo-MTWindowsArgument $Transaction.root)
    try {Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $Args -WindowStyle Hidden -ErrorAction Stop | Out-Null}
    catch {
        $Transaction.phase='PreparationFailed'
        Save-MTUpdateJson (Join-Path (Get-MTUpdateStatePath $Transaction.root) 'transaction.json') $Transaction
        Remove-MTUpdateWork (Get-MTUpdateStatePath $Transaction.root) $Transaction.id
        throw
    }
}

function Get-MTResumeProcessArguments {
    param([Parameter(Mandatory)]$Transaction)
    if($Transaction.id -notmatch '^[a-f0-9]{32}$'){throw 'MT41_STATE_INVALID'}
    $Arguments='-NoLogo -NoProfile'
    # Host switches must precede -File; otherwise PowerShell binds them to MT.
    if(@($Transaction.resumeArguments).Count){$Arguments+=' -NonInteractive'}
    $Arguments+=' -ExecutionPolicy Bypass -File '+(ConvertTo-MTWindowsArgument (Join-Path $Transaction.root 'app\MaintenanceToolkit.ps1'))+' -ResumeTransaction '+$Transaction.id
    $Arguments
}

function Receive-MTResume {
    param([string]$ProjectRoot,[string]$Id)
    $State=Get-MTUpdateStatePath $ProjectRoot;$Path=Join-Path $State 'transaction.json'
    if(-not (Test-MTProtectedPath $Path)){throw 'MT41_STATE_INVALID'}
    $Transaction=Read-MTStrictJson $Path
    Assert-MTTransaction $Transaction $ProjectRoot
    if($Transaction.id -cne $Id -or $Transaction.resumeStarted -or $Transaction.phase -notin @('Verified','PreparationFailed')){throw 'MT41_STATE_INVALID'}
    if($Transaction.phase -eq 'Verified'){
        Assert-MTInstalledPayload $ProjectRoot $Transaction.payload $Transaction.version $Transaction.kind
    }
    if(@($Transaction.resumeArguments).Count -gt 2){throw 'MT41_STATE_INVALID'}
    $Transaction.resumeStarted=$true;$Transaction.phase='Consumed'
    Save-MTUpdateJson $Path $Transaction
    # The resumed process has the installation lock and has reverified the
    # installed bytes. It no longer needs the downloaded payload/helper copy.
    $CleanupStatus='Removed'
    try{Remove-MTUpdateWork $State $Transaction.id}catch{$CleanupStatus='Retained'}
    Save-MTUpdateJson (Join-Path $State 'last-cleanup.json') ([pscustomobject]@{transactionId=$Transaction.id;work=$Transaction.work;status=$CleanupStatus;at=[DateTimeOffset]::Now.ToString('o')})
    $Transaction
}

function Assert-MTNoPendingRecovery {
    param([string]$ProjectRoot)
    $Path=Join-Path (Get-MTUpdateStatePath $ProjectRoot) 'transaction.json'
    if(Test-Path -LiteralPath $Path){
        if(-not (Test-MTProtectedPath $Path)){throw 'MT41_STATE_INVALID'}
        $Transaction=Read-MTStrictJson $Path
        if($Transaction.phase -notin @('Consumed','PreparationFailed','Verified','Recovered')){throw 'MT41_RECOVERY_REQUIRED'}
        # A handoff which has not been consumed must not race a fresh run.
        if($Transaction.phase -eq 'Verified' -and -not $Transaction.resumeStarted){throw 'MT41_RECOVERY_REQUIRED'}
    }
}

function Invoke-MTUpdateMenu {
    param([string]$ProjectRoot,[string]$InstalledVersion)
    $Mutex=$null
    try {
        $Detection=Invoke-MTUpdateCheck
        if($Detection.Status -ne 'UPDATE_AVAILABLE'){return}
        $Configuration=Get-MTSelfUpdateConfiguration $ProjectRoot
        if(-not $Configuration.CanInstall){throw 'MT41_MANAGEMENT_BLOCKED'}
        if((Read-Host (T 'MT41_UPDATE_CONFIRM')) -cne 'YES'){return}
        $Mutex=Enter-MTInstallationLock $ProjectRoot
        Assert-MTNoPendingRecovery $ProjectRoot
        $Transaction=New-MTPreparedUpdate $ProjectRoot $InstalledVersion @()
        Write-Host (T 'MT41_UPDATE_READY' @($Transaction.version))
        if((Read-Host (T 'MT41_CONFIRM')) -cne 'YES'){
            $Transaction.phase='PreparationFailed'
            Save-MTUpdateJson (Join-Path (Get-MTUpdateStatePath $ProjectRoot) 'transaction.json') $Transaction
            Remove-MTUpdateWork (Get-MTUpdateStatePath $ProjectRoot) $Transaction.id
            return
        }
        Start-MTPreparedHelper $Transaction
        exit 0
    }catch{
        $Code=$_.Exception.Message
        if($Code -notmatch '^MT41_[A-Z_]+$'){$Code='MT41_UPDATE_WARN'}
        Write-Host (T $Code) -ForegroundColor Yellow
    }finally{Exit-MTInstallationLock $Mutex}
}

function Invoke-MTPreferenceWizard {
    param([string]$ProjectRoot)
    try {
        if(-not (Get-MTManagementMenuAvailability $ProjectRoot).Preferences){throw 'MT41_MANAGEMENT_BLOCKED'}
        $Configuration=Get-MTSelfUpdateConfiguration $ProjectRoot
        $Current=T $(if($Configuration.AutomaticInstallEnabled){'MT41_AUTO_ON'}else{'MT41_AUTO_OFF'})
        $Answer=(Read-Host (T 'MT41_AUTO_CONFIRM' @($Current))).Trim().ToUpperInvariant()
        if($Answer -in @('YES','Y','SI','SÌ','SÍ','S','OUI','JA','J','是','はい')){$Automatic=$true}
        elseif($Answer -in @('NO','N','NON','NEIN','NEJ','否','いいえ')){$Automatic=$false}
        else{return}
        Set-MTStandalonePreference $ProjectRoot $Automatic -PreserveUnknown:($Configuration.Management -eq 'unknown' -and -not $Automatic)
        Write-Host (T 'MT41_PREFERENCES_SAVED')
    }catch{
        $Code=$_.Exception.Message
        if($Code -notmatch '^MT41_[A-Z_]+$'){$Code='MT41_CONFIG_INVALID'}
        Write-Host (T $Code) -ForegroundColor Yellow
    }
}
