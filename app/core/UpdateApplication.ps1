# These functions mutate only a validated transaction; never execute on import.
function Assert-MTMsiIdentity {
    param([string]$Path,[string]$Version)
    $Installer=$null;$Database=$null
    try {
        $Installer=New-Object -ComObject WindowsInstaller.Installer
        $Database=$Installer.OpenDatabase($Path,0)
        $Properties=@{}
        $View=$Database.OpenView('SELECT `Property`, `Value` FROM `Property`');$null=$View.Execute()
        try {while($Record=$View.Fetch()) {try{$Properties[$Record.StringData(1)]=$Record.StringData(2)}finally{$null=[Runtime.InteropServices.Marshal]::FinalReleaseComObject($Record)}}}finally{$null=$View.Close();$null=[Runtime.InteropServices.Marshal]::FinalReleaseComObject($View)}
        $Summary=$Database.SummaryInformation(0)
        try{$Template=$Summary.Property(7)}finally{$null=[Runtime.InteropServices.Marshal]::FinalReleaseComObject($Summary)}
        if($Properties['ProductName'] -cne 'Maintenance Toolkit' -or $Properties['Manufacturer'] -cne 'Kraugh' -or $Properties['ProductVersion'] -cne $Version -or $Properties['UpgradeCode'].Trim('{}') -ine 'C1F2A740-51FD-4C40-A0F8-BE1D4E1B72A6' -or $Template -notmatch '^x64;'){throw 'MT41_MSI_IDENTITY_INVALID'}
    }finally{
        if($Database){$null=[Runtime.InteropServices.Marshal]::FinalReleaseComObject($Database)}
        if($Installer){$null=[Runtime.InteropServices.Marshal]::FinalReleaseComObject($Installer)}
    }
}

function Assert-MTTransaction {
    param($Transaction,[string]$ProjectRoot)
    $Root=[IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')
    if($Transaction.id -notmatch '^[a-f0-9]{32}$' -or $Transaction.root -ne $Root -or $Transaction.kind -notin @('zip','msi')){throw 'MT41_STATE_INVALID'}
    $Work=Join-Path (Get-MTUpdateStatePath $Root) $Transaction.id
    if($Transaction.work -ne $Work -or (Split-Path -Parent (Split-Path -Parent $Transaction.payload)) -ne $Work){throw 'MT41_STATE_INVALID'}
    if($Transaction.kind -eq 'msi' -and (Split-Path -Parent $Transaction.msi) -ne $Work){throw 'MT41_STATE_INVALID'}
    if(-not (Test-MTProtectedPath $Work)){throw 'MT41_ROOT_UNPROTECTED'}
}

function Assert-MTInstalledPayload {
    param([string]$InstalledRoot,[string]$Payload,[string]$Version,[string]$Kind)
    $Mutable=@('config\settings.json','config\MaintenanceToolkit.ini')
    foreach($File in @(Get-ChildItem -LiteralPath $Payload -Recurse -File)) {
        $Relative=$File.FullName.Substring($Payload.TrimEnd('\').Length+1)
        if($Relative -in $Mutable){continue}
        if($Kind -eq 'msi' -and $Relative -notmatch '^(app\\|config\\|languages\\|themes\\|rules\\|MaintenanceToolkit\.exe$|Avvia_Manutenzione\.bat$|kraugh_it\\version\.json$|docs\\ABOUT\.txt$)'){continue}
        $Installed=Join-Path $InstalledRoot $Relative
        if(-not (Test-Path -LiteralPath $Installed -PathType Leaf) -or (Get-FileHash -LiteralPath $Installed -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $File.FullName -Algorithm SHA256).Hash){throw 'MT41_POSTVERIFY_FAILED'}
    }
    if((Read-MTStrictJson (Join-Path $InstalledRoot 'config/version.json')).Version -ne $Version){throw 'MT41_POSTVERIFY_FAILED'}
    # No uncatalogued executable content may remain in the application tree.
    foreach($File in @(Get-ChildItem -LiteralPath (Join-Path $InstalledRoot 'app') -Recurse -File)) {
        $Relative=$File.FullName.Substring($InstalledRoot.TrimEnd('\').Length+1)
        if(-not (Test-Path -LiteralPath (Join-Path $Payload $Relative) -PathType Leaf)){throw 'MT41_POSTVERIFY_FAILED'}
    }
}

function Copy-MTMutableState {
    param([string]$Source,[string]$Destination)
    foreach($Relative in @('config\settings.json','config\MaintenanceToolkit.ini','logs','reports')) {
        $Path=Join-Path $Source $Relative
        if(Test-Path -LiteralPath $Path) {
            if(@(Get-Item -LiteralPath $Path; Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0}).Count -gt 1 -or ((Get-Item $Path).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'MT41_ROOT_UNPROTECTED'}
            $Target=Join-Path $Destination $Relative
            New-Item -ItemType Directory -Path (Split-Path -Parent $Target) -Force | Out-Null
            if((Get-Item $Path).PSIsContainer) {
                New-Item -ItemType Directory -Path $Target -Force | Out-Null
                foreach($Child in @(Get-ChildItem -LiteralPath $Path -Force)){Copy-Item -LiteralPath $Child.FullName -Destination $Target -Recurse -Force}
            } else {Copy-Item -LiteralPath $Path -Destination $Target -Force}
        }
    }
}

function Get-MTRecoveryHashes {
    param([string]$Root)
    $Entries=@()
    foreach($Path in @((Join-Path $Root 'app'),(Join-Path $Root 'MaintenanceToolkit.exe'),(Join-Path $Root 'config\version.json'))) {
        if(Test-Path -LiteralPath $Path){
            foreach($File in @(Get-ChildItem -LiteralPath $Path -Recurse -File)){
                $Entries+=[pscustomobject]@{path=$File.FullName.Substring($Root.TrimEnd('\').Length+1);sha256=(Get-FileHash -LiteralPath $File.FullName -Algorithm SHA256).Hash}
            }
        }
    }
    $Entries
}

function Assert-MTRecoveryHashes {
    param([string]$Root,$Entries)
    foreach($Entry in @($Entries)) {
        $Path=[IO.Path]::GetFullPath((Join-Path $Root $Entry.path))
        if(-not $Path.StartsWith($Root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $Path) -or (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ine $Entry.sha256){throw 'MT41_RECOVERY_REQUIRED'}
    }
    if(@($Entries).Count -eq 0){throw 'MT41_RECOVERY_REQUIRED'}
}

function Repair-MTUpdateTransaction {
    param([string]$ProjectRoot)
    if(-not (Test-MTAdministrator)){throw 'MT41_ADMIN_REQUIRED'}
    $State=Get-MTUpdateStatePath $ProjectRoot;$Journal=Join-Path $State 'transaction.json'
    if(-not (Test-MTProtectedPath $Journal)){throw 'MT41_STATE_INVALID'}
    $Transaction=Read-MTStrictJson $Journal
    Assert-MTTransaction $Transaction $ProjectRoot
    if($Transaction.phase -notin @('Applying','RecoveryRequired','Recovered')){throw 'MT41_STATE_INVALID'}
    $Backup=$ProjectRoot+'.mt-backup-'+$Transaction.id
    $Failed=$ProjectRoot+'.mt-next-'+$Transaction.id
    try {
        if($Transaction.kind -eq 'zip' -and (Test-Path $Backup)) {
            Assert-MTRecoveryHashes $Backup $Transaction.previousHashes
            if(Test-Path $Failed){throw 'MT41_STATE_INVALID'}
            if(Test-Path $ProjectRoot){[IO.Directory]::Move($ProjectRoot,$Failed)}
            [IO.Directory]::Move($Backup,$ProjectRoot)
        }
        Copy-MTMutableState (Join-Path $Transaction.work 'mutable') $ProjectRoot
        if($Transaction.kind -eq 'msi' -and $Transaction.PSObject.Properties['msiTaskXml'] -and $Transaction.msiTaskXml){Register-ScheduledTask -TaskPath '\Kraugh\' -TaskName 'Maintenance Toolkit - MSI Managed' -Xml $Transaction.msiTaskXml -Force | Out-Null}
        Assert-MTRecoveryHashes $ProjectRoot $Transaction.previousHashes
        $Transaction.phase='Recovered';Save-MTUpdateJson $Journal $Transaction
        if(Test-Path $Failed){Remove-Item -LiteralPath $Failed -Recurse -Force}
        'Recovered'
    } catch {
        $Transaction.phase='RecoveryRequired';Save-MTUpdateJson $Journal $Transaction
        'RecoveryRequired'
    }
}

function Invoke-MTPreparedApplication {
    param([Parameter(Mandatory)]$Transaction)
    $Root=$Transaction.root
    Assert-MTTransaction $Transaction $Root
    $State=Get-MTUpdateStatePath $Root;$Journal=Join-Path $State 'transaction.json'
    if($Transaction.phase -ne 'Prepared'){throw 'MT41_STATE_INVALID'}
    if(-not (Get-MTSelfUpdateConfiguration $Root).CanInstall){throw 'MT41_MANAGEMENT_BLOCKED'}
    Assert-MTUpdateCatalog $Transaction.payload (Join-Path $Transaction.work 'payload.cat')
    $Backup=$Root+'.mt-backup-'+$Transaction.id
    $Next=$Root+'.mt-next-'+$Transaction.id
    $Snapshot=Join-Path $Transaction.work 'mutable'
    $OldVersion=(Read-MTStrictJson (Join-Path $Root 'config/version.json')).Version
    $MsiTaskXml=$null
    $Started=$false
    try {
        if(-not (Test-MTProtectedPath $Root)){throw 'MT41_ROOT_UNPROTECTED'}
        if(Test-Path $Backup){throw 'MT41_STATE_INVALID'}
        if(Test-Path $Next){throw 'MT41_STATE_INVALID'}
        Copy-MTMutableState $Root $Snapshot
        if($Transaction.kind -eq 'zip') {
            Copy-Item -LiteralPath $Transaction.payload -Destination $Next -Recurse -ErrorAction Stop
            Copy-MTMutableState $Snapshot $Next
            Assert-MTInstalledPayload $Next $Transaction.payload $Transaction.version 'zip'
        } else {
            $Artifact=(Read-MTStrictJson (Join-Path $Transaction.work 'metadata\update-v1.json')).artifacts.msi
            Assert-MTArtifactHash $Transaction.msi $Artifact
            Assert-MTUpdateSignature $Transaction.msi
            Assert-MTMsiIdentity $Transaction.msi $Transaction.version
            $Task=Get-ScheduledTask -TaskPath '\Kraugh\' -TaskName 'Maintenance Toolkit - MSI Managed' -ErrorAction SilentlyContinue
            if($Task -and @($Task.Actions).Count -eq 1 -and $Task.Actions[0].Execute -eq (Join-Path $Root 'MaintenanceToolkit.exe')){$MsiTaskXml=Export-ScheduledTask -TaskPath '\Kraugh\' -TaskName 'Maintenance Toolkit - MSI Managed'}
        }
        $Transaction | Add-Member -NotePropertyName previousHashes -NotePropertyValue @(Get-MTRecoveryHashes $Root) -Force
        $Transaction | Add-Member -NotePropertyName msiTaskXml -NotePropertyValue $MsiTaskXml -Force
        $Transaction.phase='Applying';Save-MTUpdateJson $Journal $Transaction;$Started=$true
        if($Transaction.kind -eq 'zip') {
            # Same-volume sibling renames must fail atomically: Move-Item can
            # partially move children when a locked file blocks the directory.
            [IO.Directory]::Move($Root,$Backup)
            [IO.Directory]::Move($Next,$Root)
        } else {
            $ShareKey=Get-ItemProperty 'HKLM:\Software\Kraugh\Maintenance Toolkit' -ErrorAction SilentlyContinue
            $Share=if($ShareKey -and $ShareKey.PSObject.Properties['InventoryShare']){[string]$ShareKey.InventoryShare}else{''}
            $Args='/i '+(ConvertTo-MTWindowsArgument $Transaction.msi)+' /qn /norestart REBOOT=ReallySuppress CREATE_TASK=0 INVENTORY_SHARE='+(ConvertTo-MTWindowsArgument $Share)+' /L*v '+(ConvertTo-MTWindowsArgument (Join-Path $State 'last-msi.log'))
            $Process=Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\msiexec.exe') -ArgumentList $Args -Wait -PassThru -WindowStyle Hidden
            if($Process.ExitCode -notin @(0,3010)){throw 'MT41_MSI_FAILED'}
            if($Process.ExitCode -eq 3010){throw 'MT41_RESTART_PENDING'}
            Copy-MTMutableState $Snapshot $Root
            if($MsiTaskXml){Register-ScheduledTask -TaskPath '\Kraugh\' -TaskName 'Maintenance Toolkit - MSI Managed' -Xml $MsiTaskXml -Force | Out-Null}
        }
        Assert-MTInstalledPayload $Root $Transaction.payload $Transaction.version $Transaction.kind
        $Transaction.phase='Verified';Save-MTUpdateJson $Journal $Transaction
        Save-MTUpdateJson (Join-Path $State 'sequence.json') ([pscustomobject]@{sequence=$Transaction.sequence})
        if($Transaction.kind -eq 'zip' -and (Test-Path $Backup)){Remove-Item -LiteralPath $Backup -Recurse -Force -ErrorAction SilentlyContinue}
        [pscustomobject]@{Status='Verified';CanResume=$true}
    } catch {
        $Transaction.errorCode=if($_.Exception.Message -match '^MT41_[A-Z_]+$'){$_.Exception.Message}else{'MT41_APPLY_FAILED'}
        if(-not $Started){$Transaction.phase='PreparationFailed';Save-MTUpdateJson $Journal $Transaction;return [pscustomobject]@{Status='WARN';CanResume=$true}}
        try {
            if($Transaction.kind -eq 'zip' -and (Test-Path $Backup)) {
                if(Test-Path $Root){
                    if(Test-Path $Next){Remove-Item -LiteralPath $Next -Recurse -Force}
                    [IO.Directory]::Move($Root,$Next)
                }
                [IO.Directory]::Move($Backup,$Root)
                if((Read-MTStrictJson (Join-Path $Root 'config/version.json')).Version -ne $OldVersion){throw 'MT41_RECOVERY_REQUIRED'}
                Assert-MTRecoveryHashes $Root $Transaction.previousHashes
                $Transaction.phase='Recovered'
            } else {
                # MSI rollback belongs to Windows Installer. Restore mutable
                # state only; never attempt a blind downgrade or continue work.
                Copy-MTMutableState $Snapshot $Root
                if($MsiTaskXml){Register-ScheduledTask -TaskPath '\Kraugh\' -TaskName 'Maintenance Toolkit - MSI Managed' -Xml $MsiTaskXml -Force | Out-Null}
                $Transaction.phase='RecoveryRequired'
            }
        } catch {$Transaction.phase='RecoveryRequired'}
        Save-MTUpdateJson $Journal $Transaction
        [pscustomobject]@{Status=$Transaction.phase;CanResume=$false}
    } finally {
        if(Test-Path $Next){Remove-Item -LiteralPath $Next -Recurse -Force -ErrorAction SilentlyContinue}
    }
}
