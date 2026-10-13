# Machine-local policy. No persistent WinGet pins are created or removed.
function ConvertTo-MTWingetExceptionPolicy {
    param([Parameter(Mandatory=$true)][object]$Policy, [string]$ComputerName=$env:COMPUTERNAME)
    $Names=@($Policy.PSObject.Properties.Name)
    foreach ($Required in @('schemaVersion','computerName','mode','excludedPackageIds')) {
        if ($Required -notin $Names) { throw (Get-MTRuntimeText 'WINGET_EXCEPTION_INVALID') }
    }
    if ($Policy.schemaVersion -cne '1.0' -or [string]$Policy.computerName -ine $ComputerName -or
        $Policy.mode -notin @('exclude_packages','block_module') -or
        $Policy.excludedPackageIds -isnot [array]) { throw (Get-MTRuntimeText 'WINGET_EXCEPTION_INVALID') }
    $Ids=@()
    foreach ($Id in $Policy.excludedPackageIds) {
        if ($Id -isnot [string] -or $Id -notmatch '^[A-Za-z0-9][A-Za-z0-9.+_-]{0,199}$' -or $Id -in $Ids) {
            throw (Get-MTRuntimeText 'WINGET_EXCEPTION_INVALID')
        }
        $Ids += $Id
    }
    if ($Policy.mode -eq 'exclude_packages' -and $Ids.Count -eq 0) { throw (Get-MTRuntimeText 'WINGET_EXCEPTION_INVALID') }
    [pscustomobject]@{schemaVersion='1.0';computerName=$ComputerName;mode=$Policy.mode;excludedPackageIds=$Ids}
}

function Assert-MTWingetExceptionAccess {
    param([string]$Path)
    $Item=Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw (Get-MTRuntimeText 'WINGET_EXCEPTION_ACCESS') }
    $Acl=Get-Acl -LiteralPath $Path -ErrorAction Stop
    $Owner=([Security.Principal.NTAccount]$Acl.Owner).Translate([Security.Principal.SecurityIdentifier]).Value
    if ($Owner -notin @('S-1-5-18','S-1-5-32-544')) { throw (Get-MTRuntimeText 'WINGET_EXCEPTION_ACCESS') }
    $WriteMask=[Security.AccessControl.FileSystemRights]::Write -bor
        [Security.AccessControl.FileSystemRights]::Delete -bor
        [Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
        [Security.AccessControl.FileSystemRights]::ChangePermissions -bor
        [Security.AccessControl.FileSystemRights]::TakeOwnership
    foreach ($Rule in $Acl.Access) {
        $Sid=$Rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
        if ($Rule.AccessControlType -eq 'Allow' -and ($Rule.FileSystemRights -band $WriteMask) -and
            $Sid -notin @('S-1-5-18','S-1-5-32-544')) { throw (Get-MTRuntimeText 'WINGET_EXCEPTION_ACCESS') }
    }
}

function Read-MTWingetExceptionPolicy {
    $Folder=Join-Path $env:ProgramData 'Kraugh\MaintenanceToolkit\exceptions'
    $Path=Join-Path $Folder 'winget-exception.json'
    # Distinguish missing from access failures: Test-Path alone can hide errors.
    if (-not (Test-Path -LiteralPath $Folder -ErrorAction Stop)) { return $null }
    $Entries=@(Get-ChildItem -LiteralPath $Folder -Force -ErrorAction Stop)
    if (@($Entries | Where-Object Name -eq 'winget-exception.json').Count -eq 0) { return $null }
    Assert-MTWingetExceptionAccess -Path $Folder
    Assert-MTWingetExceptionAccess -Path $Path
    $Policy=Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    ConvertTo-MTWingetExceptionPolicy -Policy $Policy
}

function Get-MTWingetExceptionPlan {
    param([object]$Export,[object]$Policy)
    if ($null -eq $Export -or $null -eq $Export.PSObject.Properties['Sources'] -or $Export.Sources -isnot [array]) {
        throw (Get-MTRuntimeText 'WINGET_EXCEPTION_EXPORT_FAILED')
    }
    $Plan=@();$Seen=@()
    foreach ($Source in $Export.Sources) {
        if ($null -eq $Source.PSObject.Properties['SourceDetails'] -or
            $null -eq $Source.SourceDetails.PSObject.Properties['Name'] -or
            $null -eq $Source.PSObject.Properties['Packages'] -or $Source.Packages -isnot [array]) {
            throw (Get-MTRuntimeText 'WINGET_EXCEPTION_EXPORT_FAILED')
        }
        $SourceName=[string]$Source.SourceDetails.Name
        if ($SourceName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$') { throw (Get-MTRuntimeText 'WINGET_EXCEPTION_EXPORT_FAILED') }
        foreach ($Package in $Source.Packages) {
            if ($null -eq $Package.PSObject.Properties['PackageIdentifier']) { throw (Get-MTRuntimeText 'WINGET_EXCEPTION_EXPORT_FAILED') }
            $Id=[string]$Package.PackageIdentifier
            if ($Id -notmatch '^[A-Za-z0-9][A-Za-z0-9.+_-]{0,199}$') { throw (Get-MTRuntimeText 'WINGET_EXCEPTION_EXPORT_FAILED') }
            $Key=$SourceName+'|'+$Id
            if ($Key -in $Seen) { continue };$Seen += $Key
            $Plan += [pscustomobject]@{id=$Id;source=$SourceName;excluded=($Id -in $Policy.excludedPackageIds)}
        }
    }
    return $Plan
}

function Get-MTWingetExceptionArguments {
    param([object]$Item,[object]$Policy,[bool]$Silent=$true,[bool]$IncludeUnknown=$true)
    if ($Policy.mode -ne 'exclude_packages' -or $Item.excluded -or $Item.id -in $Policy.excludedPackageIds) {
        throw (Get-MTRuntimeText 'WINGET_EXCEPTION_BLOCKED')
    }
    $Arguments=@('upgrade','--id',[string]$Item.id,'--exact','--source',[string]$Item.source,
        '--skip-dependencies','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
    if ($Silent) { $Arguments += '--silent' }
    if ($IncludeUnknown) { $Arguments += '--include-unknown' }
    return $Arguments
}

function Invoke-MTWingetExceptionPass {
    param([string]$WingetPath,[object]$Policy,[int]$TimeoutSeconds)
    $ExportPath=Join-Path $env:MT_SESSION_DIR ('winget-export-'+[guid]::NewGuid().ToString('N')+'.json')
    $ExportRun=Invoke-LoggedProcessWithHeartbeat -FilePath $WingetPath `
        -ArgumentList @('export','--output',$ExportPath,'--accept-source-agreements','--disable-interactivity') `
        -Label (Get-MTRuntimeText 'WINGET_EXCEPTION_EXPORT_LABEL') -Module 'WINGET' `
        -SuccessCodes @(0) -HeartbeatSeconds 0 -OutputEncoding 'UTF8' -ShowProgressOutput $false -TimeoutSeconds 300
    if ($ExportRun.TimedOut -or $ExportRun.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $ExportPath)) {
        throw (Get-MTRuntimeText 'WINGET_EXCEPTION_EXPORT_FAILED')
    }
    $Export=Get-Content -LiteralPath $ExportPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    $Plan=@(Get-MTWingetExceptionPlan -Export $Export -Policy $Policy)
    $StatusFile=Join-Path $env:MT_SESSION_DIR 'winget-exceptions-status.json'
    $Status=[ordered]@{schemaVersion='1.0';status='active';mode=$Policy.mode;excludedPackageIds=@($Policy.excludedPackageIds);packages=@();dependencyProcessing='disabled';installerDependenciesGuaranteed=$false}
    $Status | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $StatusFile -Encoding UTF8
    $Deadline=(Get-Date).AddSeconds($TimeoutSeconds);$Failures=0;$TimedOut=$false;$Reboot=$false;$Index=0
    foreach ($Item in $Plan) {
        if ($Item.excluded) {
            $Status.packages += [pscustomobject]@{id=$Item.id;source=$Item.source;status='excluded';exitCode=$null}
            continue
        }
        $Remaining=[int]($Deadline-(Get-Date)).TotalSeconds
        if ($Remaining -lt 1) { $TimedOut=$true;break }
        $Arguments=Get-MTWingetExceptionArguments -Item $Item -Policy $Policy `
            -Silent (Get-IniBool $Config 'Winget' 'Silent' $true) `
            -IncludeUnknown (Get-IniBool $Config 'Winget' 'IncludeUnknown' $true)
        $Index++
        $Run=Invoke-WingetUpgradePass -Pass $Index -WingetPath $WingetPath -Arguments $Arguments -TimeoutSeconds $Remaining
        $Hex='0x{0:X8}' -f ([long]$Run.ExitCode -band 0xffffffffL)
        $NoUpgrade=$Hex -eq '0x8A15002B'
        $Reboot=$Reboot -or $Run.ExitCode -in @(1641,3010)
        $State=if($Run.TimedOut){'timeout'}elseif($NoUpgrade){'no_update'}elseif($Run.ExitCode -in @(0,1641,3010)){'processed'}else{'failed'}
        if ($State -eq 'failed') { $Failures++ }
        $Status.packages += [pscustomobject]@{id=$Item.id;source=$Item.source;status=$State;exitCode=$Run.ExitCode}
        if ($Run.TimedOut) { $TimedOut=$true;break }
        $Status | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $StatusFile -Encoding UTF8
    }
    $Status.status=if($TimedOut -or $Failures -gt 0){'incomplete'}else{'active'}
    $Status | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $StatusFile -Encoding UTF8
    [pscustomobject]@{ExitCode=$(if($Failures -gt 0){1}else{0});TimedOut=$TimedOut;RebootRequired=$Reboot}
}
