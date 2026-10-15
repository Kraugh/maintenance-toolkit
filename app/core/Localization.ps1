function Resolve-MTLanguage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ProjectRoot,
        [Parameter(Mandatory)] [object]$Settings
    )

    $requested = [string]$Settings.Language
    $defaultLanguage = 'en-US'

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
        # Simplified Chinese is explicit; do not map Traditional Chinese to it.
        $neutralMatch = if ($requested -match '^(?i:zh-(TW|HK|MO|Hant)(-|$))') { $null } else {
            Get-ChildItem -LiteralPath $languageRoot -Filter ($neutral + '-*.json') -File -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -First 1
        }
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
    $englishPath = Join-Path $ProjectRoot 'languages/en-US.json'
    $data = Get-Content -LiteralPath $englishPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $fallbackKeys=@()
    if($resolution.Language -ne 'en-US') {
        try {
            $selected=Get-Content -LiteralPath $resolution.Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            foreach($property in @($data.PSObject.Properties)) {
                $translation=$selected.PSObject.Properties[$property.Name]
                if($translation -and $translation.Value -is [string] -and -not [string]::IsNullOrWhiteSpace($translation.Value)) {
                    $data.PSObject.Properties[$property.Name].Value=$translation.Value
                } else {$fallbackKeys+=$property.Name}
            }
        }catch{
            $resolution.Language='en-US';$resolution.Path=$englishPath;$resolution.FallbackUsed=$true
        }
    }
    $resolution | Add-Member -NotePropertyName EnglishFallbackKeys -NotePropertyValue @($fallbackKeys)
    [pscustomobject]@{ Data = $data; Resolution = $resolution }
}

function Set-MTLanguagePreference {
    param([Parameter(Mandatory)][string]$ProjectRoot,[Parameter(Mandatory)][string]$Language)
    if($Language -notin @('auto','en-US','it-IT','fr-FR','es-ES','de-DE','zh-CN','ja-JP','sv-SE')){throw 'MT41_LANGUAGE_INVALID'}
    if($Language -ne 'auto' -and -not (Test-Path -LiteralPath (Join-Path $ProjectRoot ('languages/'+$Language+'.json')))){throw 'MT41_LANGUAGE_INVALID'}
    $Path=Join-Path $ProjectRoot 'config/settings.json'
    $Settings=Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    $Settings.Language=$Language
    Save-MTUpdateJson -Path $Path -Data $Settings
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

