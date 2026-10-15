[CmdletBinding()]
param(
    [string]$Version
)

$ErrorActionPreference = "Stop"

$MsiRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $MsiRoot "..\..")).Path

# Exchange revision names must never become public runtime test filenames.
$InvalidTestNames = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'app\tools') -File -Filter '*.ps1' |
    Where-Object { $_.Name -match '(?:20[0-9]{6}|-R[0-9]+(?=\.ps1$))' })
if ($InvalidTestNames.Count -gt 0) {
    throw ('Public test filenames contain exchange revisions: ' + (($InvalidTestNames.Name) -join ', '))
}

$ToolRoot = Join-Path $MsiRoot ".tools"
$OutputRoot = Join-Path $MsiRoot "out"
$WixExe = Join-Path $ToolRoot "wix.exe"
$VersionManifestPath = Join-Path $RepoRoot "config\version.json"
$RuntimeEntryPoint = Join-Path $RepoRoot "app\MaintenanceToolkit.ps1"
$LauncherPath = Join-Path $RepoRoot "MaintenanceToolkit.exe"

$Required = @(
    $LauncherPath,
    (Join-Path $RepoRoot "Avvia_Manutenzione.bat"),
    (Join-Path $RepoRoot "app"),
    (Join-Path $RepoRoot "config"),
    (Join-Path $RepoRoot "languages"),
    (Join-Path $RepoRoot "themes"),
    (Join-Path $RepoRoot "rules"),
    (Join-Path $RepoRoot "reports\README.md"),
    (Join-Path $RepoRoot "docs\ABOUT.txt"),
    (Join-Path $RepoRoot "kraugh_it\version.json"),
    $VersionManifestPath,
    $RuntimeEntryPoint,
    (Join-Path $MsiRoot "Product.wxs"),
    (Join-Path $MsiRoot "scripts\Configure-MTScheduledTask.ps1")
)

foreach ($Path in $Required) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required MSI source is missing: $Path"
    }
}

$VersionManifest = Get-Content -LiteralPath $VersionManifestPath -Raw |
    ConvertFrom-Json
$CanonicalVersion = [string]$VersionManifest.Version

if ([string]::IsNullOrWhiteSpace($CanonicalVersion)) {
    throw "Canonical runtime version is missing from: $VersionManifestPath"
}

try {
    [void][version]$CanonicalVersion
}
catch {
    throw "MSI build requires a finalized numeric runtime version; development version '$CanonicalVersion' cannot be packaged as a public MSI."
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = $CanonicalVersion
}
elseif ($Version -ne $CanonicalVersion) {
    throw (
        "Requested MSI version '{0}' does not match canonical runtime version '{1}' in {2}." -f
        $Version,
        $CanonicalVersion,
        $VersionManifestPath
    )
}

$RuntimeSource = Get-Content -LiteralPath $RuntimeEntryPoint -Raw
$RuntimeVersionMatch = [regex]::Match(
    $RuntimeSource,
    '(?m)^\$Version\s*=\s*["''](?<Version>[^"'']+)["'']'
)

if (-not $RuntimeVersionMatch.Success) {
    throw "Unable to verify the runtime version in: $RuntimeEntryPoint"
}

$RuntimeVersion = $RuntimeVersionMatch.Groups['Version'].Value
if ($RuntimeVersion -ne $CanonicalVersion) {
    throw (
        "Runtime source version '{0}' does not match canonical version '{1}'." -f
        $RuntimeVersion,
        $CanonicalVersion
    )
}

# The current native launcher has no reliable embedded product-version metadata.
# Build from the exact repository path and report its hash so provenance can be
# checked by the release process without inventing a fragile version heuristic.
$LauncherHash = (Get-FileHash -LiteralPath $LauncherPath -Algorithm SHA256).Hash
Write-Host "Canonical runtime version: $CanonicalVersion"
Write-Host "Launcher source: $LauncherPath"
Write-Host "Launcher SHA-256: $LauncherHash"

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw ".NET SDK 6 or later is required to build the MSI."
}

New-Item -ItemType Directory -Path $ToolRoot -Force | Out-Null
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null

$ExpectedOutput = Join-Path $OutputRoot ("MaintenanceToolkit-{0}.msi" -f $Version.Replace(".", "_"))
if (Test-Path -LiteralPath $ExpectedOutput) {
    throw "MSI already exists; preserve the verified package before rebuilding: $ExpectedOutput"
}

if (-not (Test-Path -LiteralPath $WixExe)) {
    throw "Existing WiX Toolset 5.0.2 is required. Dependency acquisition needs explicit authorization."
}

Push-Location $MsiRoot
try {
    # WiX v5 is intentionally pinned: reproducible build and no v6/v7 OSMF dependency.
    $UtilExtension = Join-Path $MsiRoot '.wix\extensions\WixToolset.Util.wixext\5.0.2\wixext5\WixToolset.Util.wixext.dll'
    if (-not (Test-Path -LiteralPath $UtilExtension)) {
        throw "Existing WixToolset.Util.wixext 5.0.2 is required. Dependency acquisition needs explicit authorization."
    }

    $OutputMsi = Join-Path $OutputRoot ("MaintenanceToolkit-{0}.msi" -f $Version.Replace(".", "_"))

    & $WixExe build `
        -arch x64 `
        -ext WixToolset.Util.wixext/5.0.2 `
        -d "MTVersion=$Version" `
        -d "SourceRoot=$RepoRoot" `
        -out $OutputMsi `
        (Join-Path $MsiRoot "Product.wxs")

    if ($LASTEXITCODE -ne 0) {
        throw "WiX build failed."
    }

    $ExternalCabinets = @(Get-ChildItem -LiteralPath $OutputRoot -Filter "*.cab" -File)
    if ($ExternalCabinets.Count -gt 0) {
        throw (
            "MSI build produced external cabinet(s): {0}. Release MSI must be self-contained." -f
            (($ExternalCabinets.Name) -join ", ")
        )
    }

    Write-Host "Self-contained MSI check: no external cabinet produced."
    Write-Host ""
    Write-Host "MSI created:"
    Write-Host $OutputMsi
}
finally {
    Pop-Location
}
