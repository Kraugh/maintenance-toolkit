###############################################################################
# Maintenance Toolkit 5.0 - Inventory module
###############################################################################

. "$PSScriptRoot\00_common.ps1"

$CollectorPath = Join-Path $PSScriptRoot "inventory\InventoryCollector.ps1"
$WriterPath = Join-Path $PSScriptRoot "inventory\InventorySnapshotWriter.ps1"

. $CollectorPath
. $WriterPath

$Module = "INVENTORY"

try {
    $ReportsPath = Join-Path $MTCompatibilityRoot "reports"

    $Snapshot = Get-MTInventorySnapshot -CollectorVersion "5.0.0-dev"

    $PublishResult = Publish-MTInventorySnapshot `
        -Snapshot $Snapshot `
        -LocalDirectory $ReportsPath

    switch ($Snapshot.collection.status) {
        "ok" {
            Write-Ok ("Inventory snapshot: {0}" -f $PublishResult.localPath) $Module
            Set-ModuleResult `
                "Inventario hardware/software" `
                "OK" `
                ("Inventory Schema {0}: {1}" -f $Snapshot.schemaVersion, $PublishResult.fileName)
            exit 0
        }

        "partial" {
            Write-Warn ("Inventory snapshot partial: {0}" -f $PublishResult.localPath) $Module
            Set-ModuleResult `
                "Inventario hardware/software" `
                "WARN" `
                ("Inventory Schema {0} partial: {1}" -f $Snapshot.schemaVersion, $PublishResult.fileName)
            exit 20
        }

        default {
            Write-ErrorLog `
                ("Inventory snapshot unusable. Status: {0}" -f $Snapshot.collection.status) `
                $Module

            Set-ModuleResult `
                "Inventario hardware/software" `
                "ERROR" `
                ("Inventory Schema {0} unusable: {1}" -f $Snapshot.schemaVersion, $PublishResult.fileName)
            exit 1
        }
    }
}
catch {
    Write-ErrorLog $_.Exception.Message $Module
    Set-ModuleResult "Inventario hardware/software" "ERROR" $_.Exception.Message
    exit 1
}
