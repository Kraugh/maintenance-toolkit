# DMT handoff — Maintenance Toolkit Inventory Schema 1.0

**Date:** 2026-08-30  
**Producer:** Maintenance Toolkit 5.0  
**Consumer:** Dashboard Maintenance Toolkit  
**Contract status:** functional scope frozen; production collector not yet implemented.

## Boundary

> MT observes machine → Inventory JSON → DMT interprets/stores/manages.

DMT owns tenant/site/department/assignee/contracts/warranty and its AssetId reconciliation. MT does not generate DMT AssetId.

## DMT can design against these guarantees

- `schemaVersion = "1.0"` independently from MT version;
- new GUID `snapshotId` every collection;
- ISO 8601 `collectedAt` with timezone;
- one complete new snapshot per Inventory execution;
- stable, language-independent field names/status/error codes;
- no primary-IP assumption;
- true/false/null distinction for volume encryption;
- explicit section status/error diagnostics;
- secrets intentionally outside the contract.

## DMT should ignore collector timing for inventory logic

`collection.durationMs` and per-section `durationMs` are deliberately retained to benchmark and diagnose the collector.

DMT MAY store them, but SHOULD exclude them from:

- normal asset queries;
- inventory equality/change detection;
- hardware/software comparisons;
- user-facing asset state unless explicitly exposing collector diagnostics.

## Null semantics

- null = schema field exists but MT could not determine the value;
- [] = successful collection found no elements;
- missing field = not part of that schema structure/version.

DMT must never turn null into false.

## Security boundary

DMT must not expect passwords, credentials, authentication tokens, SSO/WAM material, Wi-Fi/VPN secrets, BitLocker recovery material/protectors, private keys, TPM cryptographic material, local administrator enumeration, local account catalogue or user-profile catalogue.

## Selected semantics

- multiple SMBIOS identities are reconciliation signals, not AssetId;
- no CPU/RAM/network/disk telemetry;
- volume capacity is inventory, free/used space is not;
- `encrypted` is only true/false/null;
- multiple IPv4/IPv6 addresses per NIC;
- gateway and DNS retained;
- DHCP provenance/current link speed excluded;
- classic software comes from uninstall registry, never `Win32_Product`;
- AppX/MSIX is machine package inventory, not user association inventory;
- only `lastKnownUser` is exposed;
- global drivers/services/SMART are outside 1.0.

## Windows Update

Inventory does not provide a patch-history database. It reuses the result of MT maintenance work actually performed.

Stable codes:

- `update_scan_failed`
- `update_download_failed`
- `update_install_failed`

`update_install_failed` is emitted only when installation was actually attempted and Windows reported a verifiable failure.

## Snapshot delivery planned for MT

Production implementation will always write the local JSON first. Optional remote publishing will be best-effort and must not make MT maintenance dependent on DMT/share availability.

Remote publishing is planned as temporary write followed by rename (`.json.tmp` → `.json`). DMT must ignore `.tmp`.

Filename is indicative only; DMT identity/deduplication must use payload fields, especially `snapshotId`.

## Files defining the contract

- `docs/INVENTORY-SCHEMA-1.0.md`
- `docs/inventory-schema-1.0.json`
- `docs/inventory-example-1.0.json`
- `project/INVENTORY-SOURCE-MATRIX.md`
- `project/INVENTORY-SCHEMA-VALIDATION.md`

These are the DMT integration reference for Schema 1.0.

## Production readiness caveat

DMT can implement its parser/importer against this contract now, but MT production snapshots are not final until the MT 5 collector, writer, benchmark and representative-environment tests are completed.
