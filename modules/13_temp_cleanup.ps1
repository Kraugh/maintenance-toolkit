
###############################################################################
# Maintenance Toolkit 3.0.6.2 - Modulo Pulizia TEMP
###############################################################################

. "$PSScriptRoot\00_common.ps1"

$Config = Read-IniFile $env:MT_INI
$Module = "TEMP"

try {
    $MinimumAgeDays = [int](Get-IniValue $Config "Cleanup" "MinimumAgeDays" 2)
    $LimitDate = (Get-Date).AddDays(-$MinimumAgeDays)

    $Targets = [System.Collections.Generic.List[string]]::new()

    if (Get-IniBool $Config "Cleanup" "UserTemp" $true) {
        if (-not [string]::IsNullOrWhiteSpace($env:TEMP)) {
            $Targets.Add($env:TEMP)
        }
    }

    if (Get-IniBool $Config "Cleanup" "WindowsTemp" $true) {
        $Targets.Add((Join-Path $env:SystemRoot "Temp"))
    }

    $Deleted = 0
    $NotDeleted = [System.Collections.Generic.List[object]]::new()
    $DetailPath = Join-Path $env:MT_SESSION_DIR "temp_non_eliminati.txt"

    foreach ($Target in ($Targets | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $Target)) {
            Write-WarnLog "Cartella TEMP non trovata: $Target" $Module
            continue
        }

        Get-ChildItem -LiteralPath $Target -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $LimitDate } |
            ForEach-Object {
                try {
                    Remove-Item `
                        -LiteralPath $_.FullName `
                        -Recurse `
                        -Force `
                        -ErrorAction Stop

                    $Deleted++
                }
                catch {
                    $NotDeleted.Add([pscustomobject]@{
                        Path = $_.FullName
                        Error = $_.Exception.Message
                    })
                }
            }
    }

    if ($NotDeleted.Count -gt 0) {
        $DetailLines = [System.Collections.Generic.List[string]]::new()

        $DetailLines.Add("ELEMENTI TEMP NON ELIMINATI")
        $DetailLines.Add("==========================")
        $DetailLines.Add("")
        $DetailLines.Add("Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        $DetailLines.Add("Computer: $env:COMPUTERNAME")
        $DetailLines.Add("Età minima: $MinimumAgeDays giorni")
        $DetailLines.Add("")

        foreach ($Item in $NotDeleted) {
            $DetailLines.Add("Percorso: $($Item.Path)")
            $DetailLines.Add("Errore:   $($Item.Error)")
            $DetailLines.Add("")
        }

        $DetailContent = $DetailLines -join [Environment]::NewLine

        $Written = Write-TextLineRobust `
            -Path $DetailPath `
            -Line $DetailContent `
            -Retries 8 `
            -DelayMilliseconds 250

        if (-not $Written) {
            Write-WarnLog `
                "Impossibile scrivere il dettaglio degli elementi TEMP non eliminati: $DetailPath" `
                $Module
        }

        $Summary = "Eliminati $Deleted elementi; non eliminati $($NotDeleted.Count)."

        Write-WarnLog `
            "$Summary Dettagli: $DetailPath" `
            $Module

        Set-ModuleResult `
            "Pulizia TEMP" `
            "WARN" `
            $Summary

        exit 20
    }

    $Summary = "Eliminati $Deleted elementi."

    Write-Ok "Pulizia TEMP completata. $Summary" $Module
    Set-ModuleResult "Pulizia TEMP" "OK" $Summary
    exit 0
}
catch {
    Write-ErrorLog $_.Exception.Message $Module
    Write-ErrorLog $_.InvocationInfo.PositionMessage $Module
    Set-ModuleResult "Pulizia TEMP" "ERROR" $_.Exception.Message
    exit 1
}
