# Development test for MT 5.0 Inventory Schema 1.0 collector.
# Run from an elevated Windows PowerShell 5.1 session at repository root.

[CmdletBinding()]
param(
    [string]$CollectorVersion = "5.0.0-dev"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$CollectorPath = Join-Path $RepoRoot "app\modules\inventory\InventoryCollector.ps1"
$SchemaPath = Join-Path $RepoRoot "docs\inventory-schema-1.0.json"

if (-not (Test-Path -LiteralPath $CollectorPath)) {
    throw "Collector not found: $CollectorPath"
}

if (-not (Test-Path -LiteralPath $SchemaPath)) {
    throw "Schema not found: $SchemaPath"
}

. $CollectorPath

$watch = [Diagnostics.Stopwatch]::StartNew()
$snapshot = Get-MTInventorySnapshot -CollectorVersion $CollectorVersion
$json = $snapshot | ConvertTo-Json -Depth 16
$watch.Stop()

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path $RepoRoot "reports"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$outFile = Join-Path $outDir ("inventory-test_{0}_{1}.json" -f $env:COMPUTERNAME, $stamp)

# Windows PowerShell 5.1 UTF8 emits BOM. This is acceptable for this development test.
$json | Set-Content -LiteralPath $outFile -Encoding UTF8

Write-Host ""
Write-Host "Inventory collector test completed." -ForegroundColor Green
Write-Host ("Schema version : {0}" -f $snapshot.schemaVersion)
Write-Host ("Snapshot ID    : {0}" -f $snapshot.snapshotId)
Write-Host ("Status         : {0}" -f $snapshot.collection.status)
Write-Host ("Collector time : {0} ms" -f $snapshot.collection.durationMs)
Write-Host ("JSON total     : {0} ms" -f $watch.ElapsedMilliseconds)
Write-Host ("Output         : {0}" -f $outFile)
Write-Host ""
Write-Host "Section timings:"
foreach ($name in @("device","os","firmware","cpu","memory","storage","volumes","gpu","network","join","tpm","software","users","maintenance")) {
    $section = $snapshot.$name
    Write-Host ("{0,-14} {1,8} ms  {2}" -f $name, $section.durationMs, $section.status)
}

Set-Clipboard -Value $outFile
Write-Host ""
Write-Host "Output file path copied to clipboard."
