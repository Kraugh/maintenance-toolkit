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

    $Files = @(
        "Avvia_Manutenzione.bat",
        "MaintenanceToolkit.ps1",
        "MaintenanceToolkit.ini",
        "ABOUT.txt",
        "LICENSE"
    )

    foreach ($File in $Files) {
        Copy-Item `
            -LiteralPath (Join-Path $RepositoryRoot $File) `
            -Destination $PackageRoot `
            -Force
    }

    foreach ($Directory in @("modules", "tools", "docs", "Images")) {
        $Source = Join-Path $RepositoryRoot $Directory

        if (Test-Path -LiteralPath $Source) {
            Copy-Item `
                -LiteralPath $Source `
                -Destination $PackageRoot `
                -Recurse `
                -Force
        }
    }

    $Readme = Get-Content -LiteralPath (Join-Path $RepositoryRoot "README.md") -Raw
    $Changelog = Get-Content -LiteralPath (Join-Path $RepositoryRoot "CHANGELOG.md") -Raw

    Convert-MarkdownToPlainText $Readme |
        Set-Content -LiteralPath (Join-Path $PackageRoot "README.txt") -Encoding UTF8

    Convert-MarkdownToPlainText $Changelog |
        Set-Content -LiteralPath (Join-Path $PackageRoot "CHANGELOG.txt") -Encoding UTF8

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
