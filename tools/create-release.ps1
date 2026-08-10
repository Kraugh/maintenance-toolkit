[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Version,

    [string]$Destination
)

$ErrorActionPreference = "Stop"

$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if ([string]::IsNullOrWhiteSpace($Destination)) {
    $Destination = Join-Path $RepositoryRoot "dist"
}
elseif (-not [System.IO.Path]::IsPathRooted($Destination)) {
    $Destination = Join-Path $RepositoryRoot $Destination
}

$Destination = [System.IO.Path]::GetFullPath($Destination)

$BuildRoot = Join-Path `
    $env:TEMP `
    ("MaintenanceToolkit-{0}-{1}" -f @(
        $Version,
        [guid]::NewGuid().ToString("N")
    ))

$PackageFolderName = "Maintenance-Toolkit-{0}" -f $Version
$PackageRoot = Join-Path $BuildRoot $PackageFolderName
$ZipPath = Join-Path $Destination ($PackageFolderName + ".zip")
$ChecksumPath = $ZipPath + ".sha256"

$RuntimeDirectories = @(
    "app",
    "config",
    "languages",
    "rules",
    "themes"
)

# These directories are intentionally NEVER distributed.
$ExcludedReleaseDirectories = @(
    "external",
    "logs",
    "reports"
)

function Assert-ReleaseSource {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Release source missing: $Description ($Path)"
    }
}

function Assert-ReleaseVersionConsistency {
    param(
        [Parameter(Mandatory)]
        [string]$ExpectedVersion
    )

    $VersionManifestPath = Join-Path $RepositoryRoot 'config\version.json'
    Assert-ReleaseSource -Path $VersionManifestPath -Description 'version manifest'

    $VersionManifest = Get-Content `
        -LiteralPath $VersionManifestPath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if ([string]$VersionManifest.Version -ne $ExpectedVersion) {
        throw (
            "Release version mismatch: requested '{0}', config/version.json contains '{1}'." -f @(
                $ExpectedVersion,
                [string]$VersionManifest.Version
            )
        )
    }

    $MainScriptPath = Join-Path $RepositoryRoot 'app\MaintenanceToolkit.ps1'
    Assert-ReleaseSource -Path $MainScriptPath -Description 'main runtime script'

    $MainScript = Get-Content `
        -LiteralPath $MainScriptPath `
        -Raw `
        -Encoding UTF8

    $EscapedVersion = [regex]::Escape($ExpectedVersion)

    if ($MainScript -notmatch ('\$Version\s*=\s*"' + $EscapedVersion + '"')) {
        throw (
            "Release version mismatch: app/MaintenanceToolkit.ps1 does not declare '{0}'." -f
            $ExpectedVersion
        )
    }
}

function Test-ZipForExcludedDirectories {
    param(
        [Parameter(Mandatory)]
        [string]$ArchivePath,
        [Parameter(Mandatory)]
        [string[]]$ExcludedDirectoryNames
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $Archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)

    try {
        foreach ($Entry in $Archive.Entries) {
            $EntryPath = $Entry.FullName.Replace("\", "/")
            $Parts = @($EntryPath.Split("/") | Where-Object { $_ })

            foreach ($ExcludedName in $ExcludedDirectoryNames) {
                if ($Parts -contains $ExcludedName) {
                    throw (
                        "Release validation failed: excluded directory '{0}' found in ZIP entry '{1}'." -f @(
                            $ExcludedName,
                            $Entry.FullName
                        )
                    )
                }
            }
        }
    }
    finally {
        $Archive.Dispose()
    }
}

try {
    Assert-ReleaseSource `
        -Path (Join-Path $RepositoryRoot "launcher\MaintenanceToolkitLauncher.cpp") `
        -Description "launcher source"

    Assert-ReleaseSource `
        -Path (Join-Path $RepositoryRoot "launcher\app.manifest") `
        -Description "launcher manifest"

    Assert-ReleaseSource `
        -Path (Join-Path $RepositoryRoot "launcher\build-launcher.cmd") `
        -Description "launcher build script"

    foreach ($Directory in $RuntimeDirectories) {
        Assert-ReleaseSource `
            -Path (Join-Path $RepositoryRoot $Directory) `
            -Description $Directory
    }

    Assert-ReleaseVersionConsistency -ExpectedVersion $Version

    # Always build the native launcher from the versioned sources.
    $LauncherBuildScript = Join-Path $RepositoryRoot "launcher\build-launcher.cmd"

    & $LauncherBuildScript

    if ($LASTEXITCODE -ne 0) {
        throw "Native launcher build failed with exit code $LASTEXITCODE."
    }

    $LauncherPath = Join-Path $RepositoryRoot "MaintenanceToolkit.exe"

    Assert-ReleaseSource `
        -Path $LauncherPath `
        -Description "built native launcher"

    New-Item -ItemType Directory -Path $PackageRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    # The extracted distribution root has one obvious human entry point.
    Copy-Item `
        -LiteralPath $LauncherPath `
        -Destination $PackageRoot `
        -Force

    foreach ($Directory in $RuntimeDirectories) {
        Copy-Item `
            -LiteralPath (Join-Path $RepositoryRoot $Directory) `
            -Destination $PackageRoot `
            -Recurse `
            -Force
    }

    # Runtime documentation only. Developer-only .github, project, tools,
    # repository metadata and test artifacts are deliberately excluded.
    $PackageDocs = Join-Path $PackageRoot "docs"
    New-Item -ItemType Directory -Path $PackageDocs -Force | Out-Null

    foreach ($DocFile in @(
        "README.md",
        "CONTRIBUTING.md",
        "LICENSE"
    )) {
        $Source = Join-Path $RepositoryRoot $DocFile

        if (Test-Path -LiteralPath $Source -PathType Leaf) {
            Copy-Item `
                -LiteralPath $Source `
                -Destination $PackageDocs `
                -Force
        }
    }

    foreach ($DocFile in @(
        "ABOUT.txt",
        "CHANGELOG.md"
    )) {
        $Source = Join-Path $RepositoryRoot ("docs\" + $DocFile)

        if (Test-Path -LiteralPath $Source -PathType Leaf) {
            Copy-Item `
                -LiteralPath $Source `
                -Destination $PackageDocs `
                -Force
        }
    }

    foreach ($DocLanguage in @("eng", "ita")) {
        $Source = Join-Path $RepositoryRoot ("docs\" + $DocLanguage)

        if (Test-Path -LiteralPath $Source -PathType Container) {
            Copy-Item `
                -LiteralPath $Source `
                -Destination $PackageDocs `
                -Recurse `
                -Force
        }
    }

    foreach ($RequiredPackageFile in @(
        'MaintenanceToolkit.exe',
        'app\MaintenanceToolkit.ps1',
        'config\version.json',
        'docs\README.md',
        'docs\LICENSE',
        'docs\ABOUT.txt',
        'docs\CHANGELOG.md'
    )) {
        $RequiredPackagePath = Join-Path $PackageRoot $RequiredPackageFile

        if (-not (Test-Path -LiteralPath $RequiredPackagePath -PathType Leaf)) {
            throw "Release validation failed: required package file missing: $RequiredPackageFile"
        }
    }

    # Staging-tree validation before compression.
    foreach ($ExcludedName in $ExcludedReleaseDirectories) {
        $ForbiddenPath = Join-Path $PackageRoot $ExcludedName

        if (Test-Path -LiteralPath $ForbiddenPath) {
            throw (
                "Release validation failed: excluded directory present in staging tree: {0}" -f
                $ForbiddenPath
            )
        }
    }

    $UnexpectedRootFiles = @(
        Get-ChildItem -LiteralPath $PackageRoot -File |
        Where-Object { $_.Name -ne "MaintenanceToolkit.exe" }
    )

    if ($UnexpectedRootFiles.Count -gt 0) {
        throw (
            "Release validation failed: unexpected file(s) in distribution root: {0}" -f
            (($UnexpectedRootFiles | ForEach-Object Name) -join ", ")
        )
    }

    if (Test-Path -LiteralPath $ZipPath) {
        Remove-Item -LiteralPath $ZipPath -Force
    }

    if (Test-Path -LiteralPath $ChecksumPath) {
        Remove-Item -LiteralPath $ChecksumPath -Force
    }

    Compress-Archive `
        -Path $PackageRoot `
        -DestinationPath $ZipPath `
        -CompressionLevel Optimal

    # Validate the actual ZIP, not only the staging directory.
    Test-ZipForExcludedDirectories `
        -ArchivePath $ZipPath `
        -ExcludedDirectoryNames $ExcludedReleaseDirectories

    $Hash = (
        Get-FileHash `
            -LiteralPath $ZipPath `
            -Algorithm SHA256
    ).Hash.ToLowerInvariant()

    ("{0}  {1}" -f @(
        $Hash,
        (Split-Path -Leaf $ZipPath)
    )) |
        Set-Content `
            -LiteralPath $ChecksumPath `
            -Encoding ASCII

    Write-Host ""
    Write-Host "Release package validated." -ForegroundColor Green
    Write-Host ("Package : {0}" -f $ZipPath)
    Write-Host ("SHA-256: {0}" -f $Hash)
    Write-Host ""
    Write-Host "Excluded from public release:" -ForegroundColor Cyan

    foreach ($ExcludedName in $ExcludedReleaseDirectories) {
        Write-Host ("  - {0}\" -f $ExcludedName)
    }
}
finally {
    if (
        -not [string]::IsNullOrWhiteSpace([string]$BuildRoot) -and
        (Test-Path -LiteralPath $BuildRoot)
    ) {
        Remove-Item `
            -LiteralPath $BuildRoot `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}
