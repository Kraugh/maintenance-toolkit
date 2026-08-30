# Maintenance Toolkit — Inventory Schema 1.0

**Status:** frozen functional contract for the initial MT 5.0 implementation.

## Purpose

Maintenance Toolkit (MT) observes a Windows machine and produces an Inventory JSON snapshot. Dashboard Maintenance Toolkit (DMT) consumes that stable contract.

> MT observes machine → Inventory JSON → DMT interprets, stores and manages.

`schemaVersion` is independent from the MT application version.

## Snapshot contract

Every Inventory execution creates a new snapshot. There is no change pre-check before collection.

Required root metadata:

- `schemaVersion`: `1.0`;
- `snapshotId`: new GUID on every collection;
- `collectedAt`: ISO 8601 including timezone;
- `collector.name`: `Maintenance Toolkit`;
- `collector.version`: actual MT version;
- `collection.status`: `ok`, `partial`, `error`;
- `collection.durationMs`: collector diagnostic timing.

The filename is never machine identity.

## Section wrapper

Major sections use the same wrapper:

```json
{
  "status": "ok",
  "durationMs": 123,
  "errors": [],
  "data": {}
}
```

Section states are:

- `ok`: collection succeeded;
- `partial`: useful data exists, but part of the section could not be collected;
- `unavailable`: the source should be usable but could not be queried in this execution;
- `error`: collection failed;
- `not_supported`: the platform/configuration does not support the collection.

Root `collection.status = error` is reserved for an unusable snapshot.

### Diagnostic timing

`durationMs` is intentionally retained in Schema 1.0 because it is useful while benchmarking MT 5 and when investigating collector regressions.

It is **not inventory state**. DMT SHOULD exclude it from ordinary asset queries, comparisons and change detection.

## Null, empty and absent

- `null`: the field belongs to the schema but MT could not determine its value;
- `[]`: collection succeeded and found no elements;
- absent field: the field is not part of that structure/schema version.

Therefore `encrypted: false` means verified not encrypted; `encrypted: null` means not determined.

## Error objects

Inventory contains only stable machine-readable collection error information:

```json
{
  "code": "access_denied",
  "source": "secure_boot"
}
```

Raw localized Windows/PowerShell error text belongs in MT logs, not in Inventory.

A negative observed fact is not a collection error: Secure Boot disabled, BitLocker disabled, no gateway, or no AppX packages are valid data states.

## Security and minimization

Inventory is constructed from an explicit **allowlist** of fields.

Source CIM/PowerShell objects and raw command output MUST NOT be serialized directly and then filtered.

Inventory MUST NOT intentionally publish credentials, passwords, tokens, SSO/WAM material, BitLocker recovery keys or protectors, Wi-Fi/VPN secrets, private keys, TPM cryptographic material, session tokens or equivalent authentication secrets.

Local-account enumeration, local administrator/group membership and user-profile enumeration are outside Schema 1.0.

## Inventory, not partial telemetry

Schema 1.0 describes what the machine is/contains and selected last-known configuration facts.

It does not collect CPU load, free RAM, volume free/used space, current link speed, network latency, throughput, packet loss, current Internet reachability, temperatures, traffic counters, process lists or other transient performance data.

## Sections

### Device
Hostname, manufacturer/model, SMBIOS UUID, BIOS serial, asset tag, chassis identity/types and baseboard identity.

Multiple independent identity signals are intentional. MT never generates the DMT AssetId.

### OS
Windows caption/name, edition, display version, version/build/UBR, architecture, install date when reliable, last boot timestamp and locale.

The registry `ProductName` is not canonical for the OS name; `Win32_OperatingSystem.Caption` is preferred.

### Firmware
BIOS/UEFI type, manufacturer, version, release date, SMBIOS version and Secure Boot state.

`secureBootEnabled = null` means not determinable, not disabled.

### CPU / memory
CPU is an array of sockets. Memory contains installed bytes, system-visible bytes and DIMM inventory.

No CPU-load or free-memory telemetry is present.

### Physical storage
Disk identity/model/serial/capacity, bus and media type.

General operational/health state and SMART are outside Schema 1.0.

### Volumes
All relevant fixed volumes, including volumes without drive letters, with label/filesystem/capacity and:

- `encrypted: true` = verified encrypted;
- `encrypted: false` = verified unencrypted;
- `encrypted: null` = not determined.

No recovery keys, protectors, method, percentage or other BitLocker detail is published.

### GPU
Adapter identity and relevant driver version/date.

### Network
Adapters are retained, including useful virtual adapters. Each adapter may contain zero, one or many IPv4/IPv6 addresses.

Schema 1.0 contains last-known IP/prefix, gateways and DNS servers.

No primary-IP assumption is made. DHCP/address provenance, link speed, SSID, connection profile, Internet state, latency and throughput are outside Schema 1.0.

### Join
Computer domain/workgroup fact plus AD/Entra/Enterprise/Workplace join booleans.

Only approved `dsregcmd` fields may be parsed; raw `dsregcmd /status` output must never be exported.

### TPM
Minimal hardware/security summary: presence, specification version, manufacturer, enabled, activated and owned state.

No TPM keys, attestation material or cryptographic blobs.

### Software
Classic Win32 inventory comes from uninstall registry keys under HKLM 64-bit, HKLM WOW6432Node and HKCU.

`Win32_Product` MUST NOT be used.

AppX/MSIX is machine package inventory; per-user package associations/SIDs are excluded.

Winget is supplementary/non-canonical only.

### Users
Only `lastKnownUser` is permitted in Schema 1.0. No local account/profile/admin inventory.

### Maintenance
Inventory may carry the result of MT maintenance work already performed. It must not trigger duplicate expensive scans merely to populate Inventory.

For Windows Update the stable failure codes are:

- `update_scan_failed`;
- `update_download_failed`;
- `update_install_failed`.

`update_install_failed` may be emitted only after an actual installation attempt with a verifiable Windows failure.

## Explicitly outside Schema 1.0

- global driver inventory;
- services inventory;
- Windows patch-history catalogue;
- complete PnP catalogue;
- network telemetry;
- disk/SMART health;
- security secrets;
- user/account reconnaissance.

## Future candidate — storage health / SMART

Storage health remains a future-release candidate. It may enter a later schema only after real validation across NVMe, SATA, USB bridges and different controllers.

MT must never report `healthy` when the actual state is merely unknown.
