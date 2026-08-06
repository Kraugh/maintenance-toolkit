# Resolve the project root from app/core/Bootstrap.ps1.
$script:MT4ProjectRoot = Split-Path -Parent (
    Split-Path -Parent $PSScriptRoot
)

$script:MT4CoreFiles = @(
    'Settings.ps1',
    'Localization.ps1',
    'Formatters.ps1',
    'Logging.ps1',
    'Renderer.ps1',
    'LegacyIni.ps1',
    'Results.ps1',
    'ProcessRunner.ps1'
)

# Load the core services in the caller's dot-sourcing scope.
#
# Important for Windows PowerShell 5.1:
# dot-sourcing these files inside Initialize-MT4Foundation would make their
# functions local to that function invocation. Loading them here keeps the
# commands available after initialization.
foreach ($CoreFile in $script:MT4CoreFiles) {
    $CorePath = Join-Path $PSScriptRoot $CoreFile

    if (-not (Test-Path -LiteralPath $CorePath)) {
        throw "MT4 core component not found: $CoreFile"
    }

    . $CorePath
}

function Initialize-MT4Foundation {
    [CmdletBinding()]
    param(
        [string]$ProjectRoot = $script:MT4ProjectRoot,
        [object]$Settings = $null
    )

    if ($null -eq $Settings) {
        $Settings = Import-MTSettings -ProjectRoot $ProjectRoot
    }

    $Language = Import-MTLanguage -ProjectRoot $ProjectRoot -Settings $Settings
    $Theme = Import-MTJsonFile -Path (
        Join-Path $ProjectRoot 'themes/default.json'
    )

    [pscustomobject]@{
        ProjectRoot = $ProjectRoot
        Settings = $Settings
        Language = $Language.Data
        LanguageResolution = $Language.Resolution
        Theme = $Theme
        CoreFiles = @($script:MT4CoreFiles)
    }
}
