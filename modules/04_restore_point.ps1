. "$PSScriptRoot\00_common.ps1";$M="RESTORE"
try{
 Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
 Checkpoint-Computer -Description "Maintenance Toolkit $env:MT_SESSION" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
 Write-Ok "Punto di ripristino creato." $M
 Set-ModuleResult "Crea punto di ripristino" "OK" "Creato punto di ripristino";exit 0
}catch{
 Write-WarnLog "Punto di ripristino non creato: $($_.Exception.Message)" $M
 Set-ModuleResult "Crea punto di ripristino" "WARN" $_.Exception.Message;exit 20
}
