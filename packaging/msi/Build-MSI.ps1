[CmdletBinding()]
param(
    [string]$Version
)

$ErrorActionPreference = "Stop"

$MsiRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $MsiRoot "..\..")).Path
$ToolRoot = Join-Path $MsiRoot ".tools"
$OutputRoot = Join-Path $MsiRoot "out"
$WixExe = Join-Path $ToolRoot "wix.exe"
$VersionManifestPath = Join-Path $RepoRoot "config\version.json"
$RuntimeEntryPoint = Join-Path $RepoRoot "app\MaintenanceToolkit.ps1"
$LauncherPath = Join-Path $RepoRoot "MaintenanceToolkit.exe"

$Required = @(
    $LauncherPath,
    (Join-Path $RepoRoot "app"),
    (Join-Path $RepoRoot "config"),
    (Join-Path $RepoRoot "languages"),
    (Join-Path $RepoRoot "themes"),
    (Join-Path $RepoRoot "rules"),
    (Join-Path $RepoRoot "reports\README.md"),
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
    throw "Canonical runtime version is not a valid MSI version: $CanonicalVersion"
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

if (-not (Test-Path -LiteralPath $WixExe)) {
    Write-Host "Installing local WiX Toolset 5.0.2..."
    & dotnet tool install wix --tool-path $ToolRoot --version 5.0.2
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to install WiX Toolset 5.0.2."
    }
}

Push-Location $MsiRoot
try {
    # WiX v5 is intentionally pinned: reproducible build and no v6/v7 OSMF dependency.
    & $WixExe extension add WixToolset.Util.wixext/5.0.2
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to acquire WixToolset.Util.wixext 5.0.2."
    }

    $OutputMsi = Join-Path $OutputRoot ("MaintenanceToolkit-{0}-x64.msi" -f $Version)

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

    Write-Host ""
    Write-Host "MSI created:"
    Write-Host $OutputMsi
}
finally {
    Pop-Location
}
