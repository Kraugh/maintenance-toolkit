###############################################################################
# Maintenance Toolkit 4.0 compatibility loader
#
# Existing MT 3.7.2 modules dot-source this file. The implementation has been
# extracted into focused app/core services. Keep this loader until every
# maintenance module imports MT4 services through the application bootstrap.
###############################################################################

$ProjectRoot = Split-Path -Parent $PSScriptRoot

$CoreFiles = @(
    "app/core/Logging.ps1",
    "app/core/Renderer.ps1",
    "app/core/LegacyIni.ps1",
    "app/core/Results.ps1",
    "app/core/ProcessRunner.ps1"
)

foreach ($RelativePath in $CoreFiles) {
    $Path = Join-Path $ProjectRoot $RelativePath

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "MT4 core component not found: $RelativePath"
    }

    . $Path
}
