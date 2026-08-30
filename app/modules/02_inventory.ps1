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

    $PublishParameters = @{
        Snapshot       = $Snapshot
        LocalDirectory = $ReportsPath
    }

    if (-not [string]::IsNullOrWhiteSpace($env:MT_INVENTORY_SHARE)) {
        $PublishParameters.InventoryShare = $env:MT_INVENTORY_SHARE
    }

    $PublishResult = Publish-MTInventorySnapshot @PublishParameters

    $ModuleStatus = switch ($Snapshot.collection.status) {
        "ok"      { "OK" }
        "partial" { "WARN" }
        default   { "ERROR" }
    }

    $Detail = "Inventory Schema {0}: {1}" -f `
        $Snapshot.schemaVersion,
        $PublishResult.fileName

    if ($PublishResult.remoteStatus -eq "warning") {
        Add-Log "WARN" $PublishResult.warningCode $Module
        $ModuleStatus = if ($ModuleStatus -eq "ERROR") { "ERROR" } else { "WARN" }
        $Detail = "{0} | {1}" -f $Detail, $PublishResult.warningCode
    }

    switch ($ModuleStatus) {
        "OK" {
            Write-Ok ("Inventory snapshot: {0}" -f $PublishResult.localPath) $Module
            Set-ModuleResult "Inventario hardware/software" "OK" $Detail
            exit 0
        }

        "WARN" {
            Add-Log "WARN" ("Inventory snapshot: {0}" -f $PublishResult.localPath) $Module
            Set-ModuleResult "Inventario hardware/software" "WARN" $Detail
            exit 20
        }

        default {
            Write-ErrorLog `
                ("Inventory snapshot unusable. Status: {0}" -f $Snapshot.collection.status) `
                $Module
            Set-ModuleResult "Inventario hardware/software" "ERROR" $Detail
            exit 1
        }
    }
}
catch {
    Write-ErrorLog $_.Exception.Message $Module
    Set-ModuleResult "Inventario hardware/software" "ERROR" $_.Exception.Message
    exit 1
}
