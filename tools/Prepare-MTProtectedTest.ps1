[CmdletBinding()]
param([Parameter(Mandatory)][string]$SourceRoot)
$ErrorActionPreference='Stop'
$RepoRoot=Split-Path -Parent $PSScriptRoot
$SourceRoot=(Resolve-Path -LiteralPath $SourceRoot).Path
$BuildRoot=[IO.Path]::GetFullPath((Join-Path $RepoRoot 'launcher\build')).TrimEnd('\')
if((Split-Path -Parent $SourceRoot) -ne $BuildRoot){throw 'Source must be a candidate directly under launcher/build.'}
$Rome=[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([datetime]::UtcNow,'W. Europe Standard Time')
$Name='MaintenanceToolkit-ProtectedTest-'+$Rome.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
$Target=Join-Path $env:ProgramData $Name
$ManifestPath=Join-Path $BuildRoot ($Name+'-files.json')
$ResultPath=Join-Path $BuildRoot ($Name+'-result.json')
$Entries=@()
foreach($Directory in @('app','config','languages','rules','themes','kraugh_it','docs')){
    foreach($File in @(Get-ChildItem -LiteralPath (Join-Path $SourceRoot $Directory) -Recurse -File)){
        if(($File.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Source reparse point rejected.'}
        $Entries += [pscustomobject]@{relative=$File.FullName.Substring($SourceRoot.Length+1);sha256=(Get-FileHash -LiteralPath $File.FullName -Algorithm SHA256).Hash}
    }
}
foreach($File in @('MaintenanceToolkit.exe','Avvia_Manutenzione.bat','LEGGIMI-READ-ME.txt','BUILD-INFO.json')){
    $Entries += [pscustomobject]@{relative=$File;sha256=(Get-FileHash -LiteralPath (Join-Path $SourceRoot $File) -Algorithm SHA256).Hash}
}
$Entries | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
$ManifestHash=(Get-FileHash -LiteralPath $ManifestPath -Algorithm SHA256).Hash
# The elevated program is carried in the process command line, not in an
# editable script. The source file list is accepted only with this pinned hash.
$ElevatedCode=@'
$ErrorActionPreference='Stop'
$Source='__SOURCE__';$Target='__TARGET__';$Manifest='__MANIFEST__';$Result='__RESULT__';$ExpectedHash='__HASH__'
$Created=$false
try {
    if((Get-FileHash -LiteralPath $Manifest -Algorithm SHA256).Hash -ne $ExpectedHash){throw 'Source manifest changed.'}
    if((Split-Path -Parent ([IO.Path]::GetFullPath($Target))) -ne [IO.Path]::GetFullPath($env:ProgramData).TrimEnd('\')){throw 'Unexpected target parent.'}
    if(Test-Path -LiteralPath $Target){throw 'Target already exists; will not overwrite.'}
    $Entries=Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
    New-Item -ItemType Directory -Path $Target | Out-Null
    $Created=$true
    $DirAcl=New-Object Security.AccessControl.DirectorySecurity
    $DirAcl.SetSecurityDescriptorSddlForm('O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;0x1200a9;;;BU)')
    Set-Acl -LiteralPath $Target -AclObject $DirAcl
    foreach($Entry in $Entries){
        $Destination=[IO.Path]::GetFullPath((Join-Path $Target $Entry.relative))
        $Original=[IO.Path]::GetFullPath((Join-Path $Source $Entry.relative))
        if(-not $Destination.StartsWith($Target+'\',[StringComparison]::OrdinalIgnoreCase) -or -not $Original.StartsWith($Source+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe relative path.'}
        New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null
        Copy-Item -LiteralPath $Original -Destination $Destination
        if((Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash -ne $Entry.sha256){throw 'Copied file mismatch.'}
    }
    $FileAcl=New-Object Security.AccessControl.FileSecurity
    $FileAcl.SetSecurityDescriptorSddlForm('O:BAG:BAD:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;0x1200a9;;;BU)')
    foreach($Item in @(Get-ChildItem -LiteralPath $Target -Recurse -Force)){
        if(($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Target reparse point rejected.'}
        if($Item.PSIsContainer){Set-Acl -LiteralPath $Item.FullName -AclObject $DirAcl}else{Set-Acl -LiteralPath $Item.FullName -AclObject $FileAcl}
    }
    [pscustomobject]@{status='Prepared';target=$Target;files=@($Entries).Count;owner='Administrators';writers=@('Administrators','SYSTEM');readers=@('Users');tasksCreated=0;preferencesCreated=$false} | ConvertTo-Json | Set-Content -LiteralPath $Result -Encoding UTF8
}catch{
    [pscustomobject]@{status='Failed';target=$Target;error=$_.Exception.Message;partialCopyRetained=$Created} | ConvertTo-Json | Set-Content -LiteralPath $Result -Encoding UTF8
    exit 1
}
'@
foreach($Pair in @(@('__SOURCE__',$SourceRoot),@('__TARGET__',$Target),@('__MANIFEST__',$ManifestPath),@('__RESULT__',$ResultPath),@('__HASH__',$ManifestHash))){$ElevatedCode=$ElevatedCode.Replace($Pair[0],$Pair[1].Replace("'","''"))}
$Encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ElevatedCode))
'Target: '+$Target
'File manifest: '+$ManifestPath
'Result: '+$ResultPath
$Process=Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -Verb RunAs -WindowStyle Hidden -ArgumentList ('-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand '+$Encoded) -PassThru
$Process.WaitForExit()
if(-not (Test-Path -LiteralPath $ResultPath)){throw 'Preparation did not produce a result.'}
$Result=Get-Content -LiteralPath $ResultPath -Raw -Encoding UTF8 | ConvertFrom-Json
if($Result.status -ne 'Prepared'){throw ('Preparation failed: '+$Result.error)}
foreach($Entry in $Entries){if((Get-FileHash -LiteralPath (Join-Path $Target $Entry.relative) -Algorithm SHA256).Hash -ne $Entry.sha256){throw 'Post-copy verification failed.'}}
. (Join-Path $RepoRoot 'app/core/SelfUpdate.ps1')
foreach($Check in @($Target,(Join-Path $Target 'MaintenanceToolkit.exe'),(Join-Path $Target 'app\MaintenanceToolkit.ps1'),(Join-Path $Target 'config\settings.json'))){if(-not (Test-MTProtectedPath $Check)){throw ('Protection check failed: '+$Check)}}
$Report=Join-Path $Target 'PROTECTED-TEST-INFO.json'
# Keep verification information in the project; do not require further writes
# into the now protected target from this non-elevated parent process.
$Result | Add-Member -NotePropertyName runtimeVersion -NotePropertyValue ((Get-Content (Join-Path $Target 'config\version.json') -Raw -Encoding UTF8 | ConvertFrom-Json).Version)
$Result | Add-Member -NotePropertyName protectionVerified -NotePropertyValue $true
$Result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $BuildRoot ($Name+'-verification.json')) -Encoding UTF8
Remove-Item -LiteralPath $ManifestPath,$ResultPath
$Result | ConvertTo-Json
