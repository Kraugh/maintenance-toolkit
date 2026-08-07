[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$Destination = (Join-Path $PSScriptRoot "..\dist")
)

$ErrorActionPreference = "Stop"
$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BuildRoot = Join-Path $env:TEMP ("MaintenanceToolkit-{0}-{1}" -f $Version, [guid]::NewGuid().ToString("N"))
$PackageRoot = Join-Path $BuildRoot ("Maintenance-Toolkit-{0}" -f $Version)
$ZipPath = Join-Path $Destination ("Maintenance-Toolkit-{0}.zip" -f $Version)
$ChecksumPath = "$ZipPath.sha256"

function Convert-MarkdownToPlainText {
    param([string]$Markdown)

    $Text = $Markdown
    $Text = [regex]::Replace($Text, '(?m)^#{1,6}\s*', '')
    $Text = [regex]::Replace($Text, '\[([^\]]+)\]\([^)]+\)', '$1')
    $Text = $Text.Replace('**', '').Replace('__', '').Replace('`', '')
    $Text = [regex]::Replace($Text, '(?m)^\s*[-*]\s+', '- ')
    return $Text.Trim() + [Environment]::NewLine
}

try {
    New-Item -ItemType Directory -Path $PackageRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    # User-facing package: the root contains only the launcher.
    Copy-Item `
        -LiteralPath (Join-Path $RepositoryRoot "Avvia_Manutenzione.bat") `
        -Destination $PackageRoot `
        -Force

    foreach ($Directory in @(
        "app",
        "config",
        "languages",
        "external",
        "rules",
        "themes"
    )) {
        $Source = Join-Path $RepositoryRoot $Directory
        if (Test-Path -LiteralPath $Source) {
            Copy-Item `
                -LiteralPath $Source `
                -Destination $PackageRoot `
                -Recurse `
                -Force
        }
    }

    # Runtime documentation is kept under docs; developer-only project material,
    # .github, release tooling and repository metadata are intentionally excluded.
    $PackageDocs = Join-Path $PackageRoot "docs"
    New-Item -ItemType Directory -Path $PackageDocs -Force | Out-Null

    foreach ($DocFile in @(
        "README.md",
        "CONTRIBUTING.md",
        "LICENSE"
    )) {
        Copy-Item `
            -LiteralPath (Join-Path $RepositoryRoot $DocFile) `
            -Destination $PackageDocs `
            -Force
    }

    foreach ($DocFile in @(
        "ABOUT.txt",
        "CHANGELOG.md"
    )) {
        Copy-Item `
            -LiteralPath (Join-Path $RepositoryRoot "docs\$DocFile") `
            -Destination $PackageDocs `
            -Force
    }

    foreach ($DocLanguage in @("eng", "ita")) {
        $Source = Join-Path $RepositoryRoot "docs\$DocLanguage"
        if (Test-Path -LiteralPath $Source) {
            Copy-Item `
                -LiteralPath $Source `
                -Destination $PackageDocs `
                -Recurse `
                -Force
        }
    }

    if (Test-Path -LiteralPath $ZipPath) {
        Remove-Item -LiteralPath $ZipPath -Force
    }

    Compress-Archive `
        -Path $PackageRoot `
        -DestinationPath $ZipPath `
        -CompressionLevel Optimal

    $Hash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    "$Hash  $(Split-Path -Leaf $ZipPath)" |
        Set-Content -LiteralPath $ChecksumPath -Encoding ASCII

    Write-Host "Package created: $ZipPath" -ForegroundColor Green
    Write-Host "SHA-256: $Hash"
}
finally {
    Remove-Item -LiteralPath $BuildRoot -Recurse -Force -ErrorAction SilentlyContinue
}
