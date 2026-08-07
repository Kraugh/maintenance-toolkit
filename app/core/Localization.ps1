function Resolve-MTLanguage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ProjectRoot,
        [Parameter(Mandatory)] [object]$Settings
    )

    $requested = [string]$Settings.Language
    $defaultLanguage = [string]$Settings.DefaultLanguage
    if ([string]::IsNullOrWhiteSpace($defaultLanguage)) { $defaultLanguage = 'en-US' }

    $detectedCulture = $null
    $fallbackUsed = $false

    if ([string]::IsNullOrWhiteSpace($requested) -or $requested -eq 'auto') {
        $detectedCulture = (Get-UICulture).Name
        $requested = $detectedCulture
    }

    $languageRoot = Join-Path $ProjectRoot 'languages'
    $candidatePath = Join-Path $languageRoot ($requested + '.json')

    if (-not (Test-Path -LiteralPath $candidatePath)) {
        $neutral = ($requested -split '-')[0]
        $neutralMatch = Get-ChildItem -LiteralPath $languageRoot -Filter ($neutral + '-*.json') -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($neutralMatch) {
            $candidatePath = $neutralMatch.FullName
            $requested = [System.IO.Path]::GetFileNameWithoutExtension($neutralMatch.Name)
        } else {
            $requested = $defaultLanguage
            $candidatePath = Join-Path $languageRoot ($requested + '.json')
            $fallbackUsed = $true
        }
    }

    if (-not (Test-Path -LiteralPath $candidatePath)) {
        throw ('Default language file not found: {0}' -f $candidatePath)
    }

    [pscustomobject]@{
        Language = $requested
        Path = $candidatePath
        FallbackUsed = $fallbackUsed
        DetectedCulture = $detectedCulture
    }
}

function Import-MTLanguage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ProjectRoot,
        [Parameter(Mandatory)] [object]$Settings
    )

    $resolution = Resolve-MTLanguage -ProjectRoot $ProjectRoot -Settings $Settings
    $data = Get-Content -LiteralPath $resolution.Path -Raw -Encoding UTF8 | ConvertFrom-Json
    [pscustomobject]@{ Data = $data; Resolution = $resolution }
}

function Get-MTText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$LanguageData,
        [Parameter(Mandatory)] [string]$Key,
        [object[]]$Arguments = @(),
        [string]$Fallback = $null
    )

    $property = $LanguageData.PSObject.Properties[$Key]
    $text = if ($property) { [string]$property.Value } elseif ($null -ne $Fallback) { $Fallback } else { '[{0}]' -f $Key }
    if ($Arguments.Count -gt 0) { return ($text -f $Arguments) }
    return $text
}

###############################################################################
# Runtime localization context for migrated MT4 modules
###############################################################################

$script:MTRuntimeLanguageData = $null
$script:MTRuntimeLanguageResolution = $null
$script:MTRuntimeLanguageProjectRoot = $null

function Initialize-MTRuntimeLocalization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [string]$Language = $env:MT_LANGUAGE,
        [string]$DefaultLanguage = 'en-US'
    )

    if ([string]::IsNullOrWhiteSpace($Language)) {
        $Language = 'auto'
    }

    $Settings = [pscustomobject]@{
        Language = $Language
        DefaultLanguage = $DefaultLanguage
    }

    $Imported = Import-MTLanguage `
        -ProjectRoot $ProjectRoot `
        -Settings $Settings

    $script:MTRuntimeLanguageData = $Imported.Data
    $script:MTRuntimeLanguageResolution = $Imported.Resolution
    $script:MTRuntimeLanguageProjectRoot = $ProjectRoot

    return $Imported.Resolution
}

function Get-MTRuntimeText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Key,
        [object[]]$Arguments = @(),
        [string]$Fallback = $null
    )

    if ($null -eq $script:MTRuntimeLanguageData) {
        throw 'MT runtime localization has not been initialized.'
    }

    return Get-MTText `
        -LanguageData $script:MTRuntimeLanguageData `
        -Key $Key `
        -Arguments $Arguments `
        -Fallback $Fallback
}

