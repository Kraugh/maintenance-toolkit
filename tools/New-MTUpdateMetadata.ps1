[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('PayloadCatalog','Metadata')][string]$Mode,
    [Parameter(Mandatory)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
    [Parameter(Mandatory)][string]$ZipPath,
    [string]$MsiPath,
    [Parameter(Mandatory)][string]$PayloadCatalogPath,
    [long]$Sequence=1,
    [int]$ValidityDays=30
)
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
. (Join-Path $Root 'app/core/UpdateTrust.ps1')
. (Join-Path $Root 'app/core/UpdateApplication.ps1')
$ZipPath=(Resolve-Path -LiteralPath $ZipPath).Path
$CatalogFull=[IO.Path]::GetFullPath($PayloadCatalogPath)
$Output=Join-Path $Root ('dist\updates\'+$Version)
$Build=Join-Path $Root ('dist\staging\MaintenanceToolkit-Metadata-'+[guid]::NewGuid().ToString('N'))
$Dist=[IO.Path]::GetFullPath((Join-Path $Root 'dist')).TrimEnd('\')+'\'
if(-not $CatalogFull.StartsWith($Dist,[StringComparison]::OrdinalIgnoreCase)){throw 'Catalog output must remain under dist.'}
if($Sequence -lt 1 -or $ValidityDays -lt 1 -or $ValidityDays -gt 90){throw 'Invalid sequence or metadata validity.'}
if(Test-Path -LiteralPath $Build){throw 'Staging already exists.'}
New-Item -ItemType Directory -Path $Build | Out-Null
try {
    Expand-MTVerifiedZip $ZipPath (Join-Path $Build 'expanded') ('Maintenance-Toolkit-'+$Version)
    $Payload=Join-Path $Build ('expanded\Maintenance-Toolkit-'+$Version)
    if($Mode -eq 'PayloadCatalog') {
        if(Test-Path -LiteralPath $CatalogFull){throw 'Catalog already exists; never overwrite.'}
        New-Item -ItemType Directory -Path (Split-Path -Parent $CatalogFull) -Force | Out-Null
        New-FileCatalog -Path $Payload -CatalogFilePath $CatalogFull -CatalogVersion 2 | Out-Null
        'Created unsigned payload catalog. Sign and timestamp it explicitly before Metadata mode.'
        return
    }
    if(-not $MsiPath){throw 'MsiPath required.'}
    $MsiPath=(Resolve-Path -LiteralPath $MsiPath).Path
    if(Test-Path -LiteralPath $Output){throw 'Metadata version directory already exists; never overwrite.'}
    Assert-MTUpdateCatalog $Payload $CatalogFull
    Assert-MTUpdateSignature (Join-Path $Payload 'MaintenanceToolkit.exe')
    Assert-MTUpdateSignature $MsiPath
    Assert-MTMsiIdentity $MsiPath $Version
    if((Read-MTStrictJson (Join-Path $Payload 'config/version.json')).Version -ne $Version){throw 'Payload version mismatch.'}
    function New-Artifact {param($Path,$Name) [pscustomobject]@{fileName=$Name;url=('https://github.com/Kraugh/maintenance-toolkit/releases/download/v'+$Version+'/'+$Name);size=(Get-Item -LiteralPath $Path).Length;sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}}
    $ArtifactName='MaintenanceToolkit-'+$Version.Replace('.','_')
    $Msi=New-Artifact $MsiPath ($ArtifactName+'.msi');$Msi | Add-Member -NotePropertyName upgradeCode -NotePropertyValue 'C1F2A740-51FD-4C40-A0F8-BE1D4E1B72A6'
    $Zip=New-Artifact $ZipPath ($ArtifactName+'.zip');$Zip | Add-Member -NotePropertyName rootDirectory -NotePropertyValue ('Maintenance-Toolkit-'+$Version)
    $Zip | Add-Member -NotePropertyName catalog -NotePropertyValue (New-Artifact $CatalogFull ($ArtifactName+'-payload.cat'))
    $Now=[DateTimeOffset]::UtcNow
    $Manifest=[pscustomobject]@{schemaVersion='1.0';productId='maintenance-toolkit';version=$Version;channel='stable';architecture='x64';sequence=$Sequence;publishedAt=$Now.ToString('o');expiresAt=$Now.AddDays($ValidityDays).ToString('o');minimumUpdaterVersion='4.1.0';artifacts=[pscustomobject]@{msi=$Msi;zip=$Zip}}
    $null=Assert-MTUpdateManifest $Manifest '0.0.0'
    $Meta=Join-Path $Build 'metadata';New-Item -ItemType Directory -Path $Meta | Out-Null
    $Manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $Meta 'update-v1.json') -Encoding UTF8
    New-FileCatalog -Path $Meta -CatalogFilePath (Join-Path $Build 'update-v1.cat') -CatalogVersion 2 | Out-Null
    New-Item -ItemType Directory -Path $Output | Out-Null
    Copy-Item -LiteralPath (Join-Path $Meta 'update-v1.json'),(Join-Path $Build 'update-v1.cat') -Destination $Output
    'Created metadata and unsigned metadata catalog. Explicit signing/verification and publication remain separate.'
}finally{
    $Expected=[IO.Path]::GetFullPath((Join-Path $Root 'dist\staging'))
    if((Split-Path -Parent ([IO.Path]::GetFullPath($Build))) -eq $Expected){Remove-Item -LiteralPath $Build -Recurse -Force}
}
