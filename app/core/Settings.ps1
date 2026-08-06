function Import-MTJsonFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw ('Configuration file not found: {0}' -f $Path) }
    Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Import-MTSettings {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ProjectRoot)
    Import-MTJsonFile -Path (Join-Path $ProjectRoot 'config/settings.json')
}
