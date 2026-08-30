# Inventory Schema 1.0 — Windows source matrix

This matrix is the implementation baseline for MT 5.0 Inventory.

| Contract area | Windows source demonstrated / intended | Reliability | Observed cost | Privilege | Production rule |
|---|---|---|---:|---|---|
| Device identity | `Win32_ComputerSystem`, `Win32_ComputerSystemProduct`, `Win32_BIOS`, `Win32_SystemEnclosure`, `Win32_BaseBoard` | High / OEM-dependent | ~43 ms latest run | normal | Trim whitespace-only identifiers to null |
| OS | `Win32_OperatingSystem` + targeted `CurrentVersion` registry | High | within ~204 ms OS/firmware section | normal | OS name from CIM Caption; registry ProductName is not canonical |
| Firmware type | Windows firmware-type API/source validated by probe | High | low | normal | Normalize to `bios/uefi/unknown` |
| Secure Boot | `Confirm-SecureBootUEFI` | High when query succeeds | low | elevation required in tested environment | Query error → null/error, never false |
| CPU | `Win32_Processor` | High | CPU+memory section ~1.09 s | normal | Emit socket array |
| Memory | `Win32_PhysicalMemory`, `Win32_ComputerSystem.TotalPhysicalMemory` | High | CPU+memory section ~1.09 s | normal | Sum DIMMs for installed bytes; keep system-visible separately |
| Physical disks | `Get-PhysicalDisk` + targeted `Win32_DiskDrive` enrichment | High/medium | ~85 ms–4.35 s observed | normal | Correlate into one record; no duplicate source objects |
| Volumes | `Get-Volume` | High | ~66 ms latest run | normal | Include useful no-letter fixed volumes; omit free/used telemetry |
| Volume encryption | `Get-BitLockerVolume` | High when accessible | ~0.4–0.9 s elevated observed | elevated | Publish only true/false/null; no protectors/recovery/method |
| GPU | `Win32_VideoController` | High/medium | ~35 ms | normal | AdapterRAM excluded |
| Network config | `Get-NetAdapter`, `Get-NetIPConfiguration`, related NetTCPIP/DNS sources | High | ~1.33 s latest run | normal | Multiple IPv4/IPv6; gateway/DNS; no DHCP provenance/link speed |
| Network driver | targeted adapter/driver source | Needs production validation | not isolated | normal | Null until a reliable per-adapter mapping is validated |
| Domain/workgroup | `Win32_ComputerSystem` | High | join section ~56 ms | normal | Preserve observed fact |
| Entra/enterprise/workplace | targeted `dsregcmd /status` whitelist | High/medium | join section ~56 ms | normal | Never export raw dsregcmd output |
| TPM | `root\CIMV2\Security\MicrosoftTpm:Win32_Tpm` | High when accessible | ~840 ms | elevated in tested environment | Query failure ≠ no TPM |
| Win32 software | uninstall registry HKLM64/HKLM32/HKCU | High | ~0.5–0.7 s | normal | Never `Win32_Product`; do not export uninstall commands/paths |
| AppX/MSIX | `Get-AppxPackage -AllUsers` | High when elevated | ~0.24 s | elevated for complete machine view | No per-user SID associations |
| Last-known user | target source to be validated; probe demonstrated current `Win32_ComputerSystem.UserName` | Medium | small | normal | Null if broader last-known semantic cannot be supported reliably |
| Windows Update outcome | reuse existing MT Microsoft Update module result | High when based on actual operation | MT4 scan ~10 s; full module ~64 s | MT elevated | Never perform duplicate scan solely for Inventory |
| General drivers | `Win32_PnPSignedDriver` | High but noisy | ~1.5 s / 255 records | normal | OUT 1.0 |
| Winget | `winget list` | Variable/localized | ~1.4–3.4 s | normal | Non-canonical only |
| Services | `Win32_Service` | High but noisy | ~0.3 s / 335 records | normal | OUT 1.0 |
| SMART/storage health | controller/device dependent | Not sufficiently validated | TBD | varies | OUT 1.0; future candidate |

## Benchmark rule

Collection cost is retained now because it determines whether a field/source is worth collecting. Per-section `durationMs` remains in the snapshot for collector diagnostics, but DMT should ignore it for ordinary inventory queries and asset-change detection.

Final MT 5 benchmarking must include cold and repeated warm runs and report min/mean/max for collection, serialization, local write, optional remote copy, JSON size, memory where practical, and complete MT duration.
