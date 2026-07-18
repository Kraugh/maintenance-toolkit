###############################################################################
# Maintenance Toolkit 3.7.0 - Modulo SFC
###############################################################################

. "$PSScriptRoot\00_common.ps1"
$Module = "SFC"
$Run = Invoke-LoggedProcessWithHeartbeat `
    -FilePath "$env:SystemRoot\System32\sfc.exe" `
    -ArgumentList @("/scannow") -Label "SFC Scannow" -Module $Module `
    -SuccessCodes @(0) -HeartbeatSeconds 15 -OutputEncoding "Unicode"

if ($Run.ExitCode -ne 0) {
    Set-ModuleResult "SFC Scannow" "ERROR" "Exit code $($Run.ExitCode)"
    exit 1
}

$Output = (Read-ProcessOutput -Path $Run.OutputPath -Encoding "Unicode") -join "`n"
if ($Output -match "nessuna violazione di integrit") {
    Set-ModuleResult "SFC Scannow" "OK" "Nessuna violazione di integrità trovata; durata $($Run.Duration)"
    exit 0
}
if ($Output -match "file danneggiati trovati e ripristinati" -or $Output -match "successfully repaired") {
    Write-WarnLog "SFC ha trovato e riparato file di sistema danneggiati." $Module
    Set-ModuleResult "SFC Scannow" "WARN" "File danneggiati trovati e ripristinati; durata $($Run.Duration)"
    exit 20
}
if ($Output -match "impossibile ripristinare" -or $Output -match "unable to fix") {
    Write-ErrorLog "SFC ha trovato file danneggiati che non è riuscito a ripristinare." $Module
    Set-ModuleResult "SFC Scannow" "ERROR" "File danneggiati non ripristinati"
    exit 1
}
Write-WarnLog "SFC completato, ma l'esito testuale non è stato riconosciuto." $Module
Set-ModuleResult "SFC Scannow" "WARN" "Completato con esito non riconosciuto; durata $($Run.Duration)"
exit 20
