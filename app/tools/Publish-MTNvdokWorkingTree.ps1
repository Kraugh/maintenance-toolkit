[CmdletBinding()]
param([string]$ProjectRoot='')
$ErrorActionPreference='Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
Set-Location -LiteralPath $ProjectRoot
function Invoke-PublishGit {
    param([string[]]$Arguments)
    & git @Arguments
    if ($LASTEXITCODE -ne 0) { throw ('git failed: '+($Arguments -join ' ')) }
}
$null=Get-Command git,gh,powershell.exe -ErrorAction Stop
$Manifest=Get-Content 'config/version.json' -Raw | ConvertFrom-Json
if ($Manifest.Version -ne '4.0.4-dev.7-NVDOK' -or $Manifest.Channel -ne 'development') { throw 'Expected NVDOK development sources.' }
$Branch=(& git branch --show-current | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $Branch -ne 'main') { throw 'Run from the maintenance-toolkit main working tree.' }
$Remote=(& git remote get-url origin | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $Remote -notmatch '(?i)github\.com[:/]Kraugh/maintenance-toolkit(?:\.git)?$') { throw 'Unexpected origin: must be Kraugh/maintenance-toolkit.' }
& gh auth status
if ($LASTEXITCODE -ne 0) { throw 'GitHub authentication unavailable.' }
Invoke-PublishGit -Arguments @('fetch','origin','main')
& git merge-base --is-ancestor origin/main HEAD
if ($LASTEXITCODE -ne 0) { throw 'Remote main contains changes not in this working tree. Integrate them before publishing; no reset or force push was performed.' }
$AlreadyStaged=@(& git diff --cached --name-only)
if ($LASTEXITCODE -ne 0 -or $AlreadyStaged.Count -gt 0) { throw 'The Git index must be empty before this publication to avoid committing unrelated staged files.' }
# Run tests in child PowerShell processes: test scripts can use exit safely.
foreach ($Test in @('app/tools/Test-MTNvidia.ps1','app/tools/Test-MTNvidiaAdvisory.ps1','app/tools/Test-MT4LegacyCompatibility.ps1','app/tools/Invoke-MT4FoundationAutotest.ps1')) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ProjectRoot $Test) -ProjectRoot $ProjectRoot
    if ($LASTEXITCODE -ne 0) { throw ('Validation failed: '+$Test+'. No commit or issue created.') }
}
$ParseFailures=@()
foreach ($File in @(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'app') -Filter '*.ps1' -Recurse -File)) {
    $Tokens=$null;$Errors=$null
    $null=[Management.Automation.Language.Parser]::ParseFile($File.FullName,[ref]$Tokens,[ref]$Errors)
    if ($Errors.Count -gt 0) { $ParseFailures += $Errors | ForEach-Object { $File.FullName+': '+$_.Message } }
}
if ($ParseFailures.Count -gt 0) { throw ($ParseFailures -join "`n") }
# Final live read-only NVIDIA check; WARN availability is an expected outcome.
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ProjectRoot 'app/MaintenanceToolkit.ps1') -Only NVIDIA -Language it-IT
if ($LASTEXITCODE -notin @(0,10,20)) { throw 'Live NVIDIA check failed; no commit or issue created.' }
# Remove only obsolete pilot documentation, never logs, cached drivers or public assets.
foreach ($Obsolete in @('docs/FNV01.it.md','docs/FNV02.it.md','docs/FNV03.it.md','docs/FNV04.it.md')) {
    if (Test-Path -LiteralPath $Obsolete -PathType Leaf) { Remove-Item -LiteralPath $Obsolete -Force }
}
$FileManifest=Get-Content 'project/NVDOK-FILES.json' -Raw | ConvertFrom-Json
$Paths=@($FileManifest | ForEach-Object { [string]$_ })
if ($Paths.Count -eq 0) { throw 'Publication file list is empty.' }
$Protected='^(?:dist/|external/|logs/|reports/|kraugh_it/|launcher/|packaging/|\.github/)|^(?:MaintenanceToolkit\.exe|Avvia_Manutenzione\.bat)$'
if (@($Paths | Where-Object { $_ -match $Protected -or $_ -match '(^|/)\.\.(/|$)|^[/\\]|:' }).Count -gt 0) { throw 'Invalid publication scope.' }
Invoke-PublishGit -Arguments (@('add','--')+$Paths)
foreach ($Obsolete in @('docs/FNV01.it.md','docs/FNV02.it.md','docs/FNV03.it.md','docs/FNV04.it.md')) {
    $Tracked=@(& git ls-files -- $Obsolete)
    if ($Tracked.Count -gt 0) { Invoke-PublishGit -Arguments @('add','-u','--',$Obsolete) }
}
Invoke-PublishGit -Arguments @('diff','--cached','--check')
$Staged=@(& git diff --cached --name-only)
if (@($Staged | Where-Object { $_ -match $Protected }).Count -gt 0) { throw 'Protected public-release files were staged. No commit performed.' }
$Title='NVIDIA: advisory-only driver availability and professional workstation validation'
$ExistingJson=& gh issue list --repo Kraugh/maintenance-toolkit --state all --search $Title --limit 100 --json title,url
if ($LASTEXITCODE -ne 0) { throw 'Cannot check existing NVIDIA issues.' }
$Existing=@(($ExistingJson | Out-String | ConvertFrom-Json) | Where-Object title -eq $Title)
if ($Existing.Count -gt 1) { throw 'Multiple matching issues: resolve before publishing.' }
if ($Existing.Count -eq 1) { $IssueUrl=$Existing[0].url }
else {
    $IssueUrl=(& gh issue create --repo Kraugh/maintenance-toolkit --title $Title --body-file 'project/NVIDIA-ISSUE.md' | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Issue creation failed.' }
}
Write-Host ('NVIDIA issue: '+$IssueUrl)
if ($Staged.Count -gt 0) {
    Invoke-PublishGit -Arguments @('commit','-m','Checkpoint 4.0.4-dev.7-NVDOK: advisory-only NVIDIA driver checks')
}
Invoke-PublishGit -Arguments @('push','origin','HEAD:main')
$Head=(& git rev-parse HEAD | Out-String).Trim()
$RemoteHead=(& git ls-remote origin refs/heads/main | Out-String).Trim().Split()[0]
if ($LASTEXITCODE -ne 0 -or $Head -ne $RemoteHead) { throw 'Push verification failed.' }
Write-Host ('Commit verified on origin/main: '+$Head)
Write-Host 'Development sources published; no release, tag, release asset or stable-manifest change was requested.'
Invoke-PublishGit -Arguments @('status','--short','--branch')
