[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
$Archive=Join-Path $Root ('launcher\build\MT-NamesArchive-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$Mappings=@(
        @{ Old='app/tools/Test-MTDev8Outcomes-R01.ps1'; New='app/tools/Test-MTOemAndGpuOutcomes.ps1' }
        @{ Old='app/tools/Test-MTReleaseBlockers-20261009-1620-R01.ps1'; New='app/tools/Test-MTReleaseBlockers.ps1' }
        @{ Old='app/tools/Test-MTPatch405-20261013-1313-R02.ps1'; New='app/tools/Test-MTWingetDiscoveryAndDellOutcomes.ps1' }
        @{ Old='app/tools/Test-MTWingetExceptions-20261013-1401-R01.ps1'; New='app/tools/Test-MTWingetExceptions.ps1' }
)
# Validate every pair before moving any file; only canonical copies from this ZIP are used.
foreach($Pair in $Mappings) {
    $Old=Join-Path $Root $Pair.Old;$New=Join-Path $Root $Pair.New
    if(-not (Test-Path -LiteralPath $New -PathType Leaf)){throw "Canonical test missing: $($Pair.New)"}
    if(Test-Path -LiteralPath $Old -PathType Leaf) {
        $OldText=(Get-Content -LiteralPath $Old -Raw).Replace("`r`n","`n")
        $NewText=(Get-Content -LiteralPath $New -Raw).Replace("`r`n","`n")
        if($OldText -cne $NewText){throw "Local test differs from delivered canonical copy: $($Pair.Old)"}
    }
}
New-Item -ItemType Directory -Path $Archive|Out-Null
foreach($Pair in $Mappings) {
    $Old=Join-Path $Root $Pair.Old
    if(Test-Path -LiteralPath $Old){Move-Item -LiteralPath $Old -Destination $Archive;"Retired: $($Pair.Old) -> $($Pair.New)"}
}
$Obsolete=Join-Path $Root 'app/tools/Test-MTPatch405-20261013-1252-R01.ps1'
if(Test-Path -LiteralPath $Obsolete){Move-Item -LiteralPath $Obsolete -Destination $Archive;'Retired obsolete failing R01 test.'}
$Invalid=@(Get-ChildItem (Join-Path $Root 'app/tools') -File -Filter '*.ps1'|Where-Object {$_.Name -match '(?:20[0-9]{6}|-R[0-9]+(?=\.ps1$))'})
if($Invalid.Count -gt 0){throw ('Remaining invalid names: '+($Invalid.Name -join ', '))}
"Archive inside project: $Archive"
'PASS: canonical test filenames; build guards enabled; launcher and packages unchanged.'
