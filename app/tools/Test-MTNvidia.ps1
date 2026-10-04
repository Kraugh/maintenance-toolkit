param([string]$ProjectRoot='')
$ErrorActionPreference='Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
. (Join-Path $ProjectRoot 'app/modules/gpu/NvidiaDriver.ps1')
$FixturePath = Join-Path $PSScriptRoot 'fixtures/nvidia-p620-response.json'
function Read-Fixture { Get-Content -LiteralPath $FixturePath -Raw -Encoding UTF8 | ConvertFrom-Json }
$Candidate=Get-MTNvidiaCandidate (Read-Fixture)
if ($null -eq $Candidate -or $Candidate.version -ne '582.78') { throw 'NVIDIA fixture: expected 582.78.' }
if ((ConvertTo-MTNvidiaVersion '31.0.15.2889').ToString() -ne '528.89') { throw 'NVIDIA version conversion failed.' }
if ((ConvertTo-MTNvidiaVersion '32.0.15.8278').ToString() -ne '582.78') { throw 'NVIDIA target version conversion failed.' }
foreach ($Case in @('beta','nonwhql','inactive','preview','foreignUrl','wrongVersionUrl','wrongOs','wrongProduct','wrongBranch')) {
    $Fixture=Read-Fixture
    foreach ($Entry in $Fixture.IDS) {
        switch ($Case) {
            'beta' { $Entry.downloadInfo.IsBeta='1' }
            'nonwhql' { $Entry.downloadInfo.IsWHQL='0' }
            'inactive' { $Entry.downloadInfo.IsActive='0' }
            'preview' { $Entry.downloadInfo.IsFeaturePreview='1' }
            'foreignUrl' { $Entry.downloadInfo.DownloadURL='https://example.org/driver.exe' }
            'wrongVersionUrl' { $Entry.downloadInfo.DownloadURL=$Entry.downloadInfo.DownloadURL.Replace($Entry.downloadInfo.Version,'999.99') }
            'wrongOs' { $Entry.downloadInfo.OSList=@() }
            'wrongProduct' { $Entry.downloadInfo.series=@() }
            'wrongBranch' { $Entry.downloadInfo.ReleaseNotes='New Feature Branch' }
        }
    }
    if ($null -ne (Get-MTNvidiaCandidate $Fixture)) { throw "Unsafe NVIDIA candidate accepted: $Case" }
}
'PASS: NVIDIA real response selection, version conversion and nine rejection cases.'

$Desktop=[pscustomobject]@{Name='Quadro P620';Value='865';SeriesName='Quadro Series';SeriesId='73'}
$Mobile=[pscustomobject]@{Name='Quadro P620';Value='1865';SeriesName='Quadro Notebook Series';SeriesId='74'}
$Matches=@($Desktop,$Mobile)
if ((Get-MTNvidiaProductMatch -DeviceName 'NVIDIA Quadro P620' -Products $Matches -IsMobile $false).Value -ne '865') { throw 'Desktop model mapping failed.' }
if ((Get-MTNvidiaProductMatch -DeviceName 'NVIDIA Quadro P620' -Products $Matches -IsMobile $true).Value -ne '1865') { throw 'Mobile model mapping failed.' }
$Other=[pscustomobject]@{Name='Quadro P620';Value='999';SeriesName='Quadro Series';SeriesId='88'}
if ($null -ne (Get-MTNvidiaProductMatch -DeviceName 'NVIDIA Quadro P620' -Products @($Desktop,$Other) -IsMobile $false)) { throw 'Ambiguous model accepted.' }
if ($null -ne (Get-MTNvidiaProductMatch -DeviceName 'NVIDIA Quadro P620 Laptop GPU' -Products @($Desktop) -IsMobile $false)) { throw 'Distinct model qualifier discarded.' }
$Module=Get-Content -LiteralPath (Join-Path $ProjectRoot 'app/modules/15_nvidia.ps1') -Raw
if ($Module -match '(?i)-OutFile|Invoke-LoggedProcess|Start-Process|Checkpoint-Computer|Unblock-File|Copy-MTNvidiaArchive|NvidiaInstall') { throw 'NVDOK must remain advisory-only.' }
$Main=Get-Content -LiteralPath (Join-Path $ProjectRoot 'app/MaintenanceToolkit.ps1') -Raw
if ($Main -match '\[switch\]\$NvidiaInstall|\[switch\]\$NvidiaUseCachedOnly') { throw 'NVIDIA install CLI still enabled.' }
'PASS: desktop/mobile model mapping, ambiguity rejection, model qualifier and advisory-only contracts.'
