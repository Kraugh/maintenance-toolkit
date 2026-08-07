###############################################################################
# Maintenance Toolkit 4.0 compatibility loader
#
# Existing MT 3.7.2 modules dot-source this file. The implementation has been
# extracted into focused app/core services. Keep this loader until every
# maintenance module imports MT4 services through the application bootstrap.
###############################################################################

# This file is dot-sourced by both the main application and legacy modules.
# Use compatibility-specific variable names so we never overwrite a caller's
# $ProjectRoot variable.
$MTCompatibilityRoot = Split-Path -Parent (
    Split-Path -Parent $PSScriptRoot
)

$MTCompatibilityCoreFiles = @(
    "app/core/Localization.ps1",
    "app/core/Logging.ps1",
    "app/core/Renderer.ps1",
    "app/core/LegacyIni.ps1",
    "app/core/Results.ps1",
    "app/core/ProcessRunner.ps1"
)

foreach ($MTCompatibilityRelativePath in $MTCompatibilityCoreFiles) {
    $MTCompatibilityPath = Join-Path `
        $MTCompatibilityRoot `
        $MTCompatibilityRelativePath

    if (-not (Test-Path -LiteralPath $MTCompatibilityPath)) {
        throw "MT4 core component not found: $MTCompatibilityRelativePath"
    }

    . $MTCompatibilityPath
}

# Migrated maintenance modules resolve all UI text through the common runtime
# language selected by the MT4 shell.
Initialize-MTRuntimeLocalization `
    -ProjectRoot $MTCompatibilityRoot `
    -Language $env:MT_LANGUAGE |
    Out-Null
