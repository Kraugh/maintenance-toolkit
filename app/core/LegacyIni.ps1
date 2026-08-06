# Compatibility parser for MaintenanceToolkit.ini.
# JSON settings are the MT4 target, but the INI remains supported throughout
# the migration so the 3.7.2 runtime does not regress.

function Read-IniFile {
    param([string]$Path)

    $Data = @{}
    $Section = "General"
    $Data[$Section] = @{}

    foreach ($Raw in Get-Content -LiteralPath $Path) {
        $Line = $Raw.Trim()

        if (-not $Line -or $Line.StartsWith(";") -or $Line.StartsWith("#")) {
            continue
        }

        if ($Line -match '^\[(.+)\]$') {
            $Section = $matches[1]

            if (-not $Data.ContainsKey($Section)) {
                $Data[$Section] = @{}
            }

            continue
        }

        if ($Line -match '^([^=]+)=(.*)$') {
            $Data[$Section][$matches[1].Trim()] = $matches[2].Trim()
        }
    }

    return $Data
}
function Get-IniValue {
    param($Config, [string]$Section, [string]$Key, $Default = $null)

    if ($Config.ContainsKey($Section) -and $Config[$Section].ContainsKey($Key)) {
        return $Config[$Section][$Key]
    }

    return $Default
}
function Get-IniBool {
    param($Config, [string]$Section, [string]$Key, [bool]$Default = $false)

    $Value = Get-IniValue $Config $Section $Key $null

    if ($null -eq $Value) {
        return $Default
    }

    return $Value -match '^(1|true|yes|si|on)$'
}
