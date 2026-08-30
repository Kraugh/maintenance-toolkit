# Inventory Schema 1.0 — Probe validation

**Purpose:** verify that the frozen contract is grounded in sources already exercised by `tools/inventory-probe.ps1` rather than in theoretical Windows properties.

Validated against the read-only Inventory Source Probe 0.2 run on 2026-08-30.

## Result

The frozen Schema 1.0 is implementable from the source families already exercised by the probe. The probe intentionally contains substantially more data than the production contract; production code must construct an allowlisted payload rather than reuse/serialize the probe objects.

No probe-only experimental data is promoted automatically into Schema 1.0.

## Directly demonstrated by the probe

- device manufacturer/model, SMBIOS UUID, BIOS/chassis/baseboard identifiers;
- OS caption/version/build/architecture/install/boot timestamps and registry edition/displayVersion/UBR;
- BIOS manufacturer/version/release date/SMBIOS level, firmware type and Secure Boot query;
- CPU sockets and DIMM inventory;
- physical disk identities, capacity, bus/media information;
- volumes including volumes without drive letters;
- GPU identity/driver information;
- multiple network adapters with IPv4/IPv6, gateway and DNS observations;
- AD/workgroup plus targeted `dsregcmd` join fields;
- TPM CIM access;
- uninstall-registry software from HKLM64/HKLM32/HKCU;
- AppX current-user and all-user collection;
- current logged-on username;
- BitLocker volume query;
- section timings and total probe timing.

## Contract fields that require production normalization rather than direct copying

### `firmware.type`
Probe value is a Windows numeric firmware type. Production emits stable `bios | uefi | unknown`.

### `firmware.smbiosVersion`
Probe exposes major/minor separately. Production combines them into a normalized version string.

### `memory.installedBytes`
Derived from the sum of physical DIMM capacities. This is intentionally distinct from `systemVisibleBytes`.

### `memory.modules[].type`
Probe demonstrates `SMBIOSMemoryType`; production normalizes the code to a stable textual value such as `ddr4`.

### `storage.disks[]`
Probe returns both `Get-PhysicalDisk` and `Win32_DiskDrive`. Production must correlate them into one disk record and avoid duplicate disks. `Get-PhysicalDisk` is primary for size/bus/media; `Win32_DiskDrive` is targeted enrichment.

`manufacturer` is allowed to be null. The current probe did not validate a reliable manufacturer property for every disk and production must not infer manufacturer from model text.

### `volumes[].encrypted`
Probe demonstrates both `Get-Volume` and `Get-BitLockerVolume`, but production still needs deterministic mapping between the volume inventory and BitLocker results. Unknown mapping/query failure must yield null, never false.

### Network structured addresses
Probe currently records IPs as `address/prefix` strings and gateways/DNS as strings. Production normalizes them into structured `{family,address,prefixLength}` / `{family,address}` objects.

### Network adapter type
Probe demonstrates physical-media information plus physical/virtual flags. Production must define a conservative normalized type. Unknown/ambiguous adapters must not be guessed.

### Network driver version/date
The frozen contract allows these values, but the current network probe did not explicitly capture them in its network section. Production must validate a reliable targeted source; until then null is valid.

### `join`
Probe gives Windows/native string values. Production converts only explicit known values to booleans. Parsing failure is null/partial, not false.

### `tpm.present`
A successful TPM object establishes presence. A query failure must not be converted to `present = false`.

### Software registry view
Probe uses `64`, `32`, `native`; production emits stable `64-bit`, `32-bit`, `native`.

### `users.lastKnownUser`
The probe directly demonstrates the currently logged-on user from `Win32_ComputerSystem.UserName`. The production collector must validate the source chosen for the broader `lastKnownUser` semantic. If no reliable last-known value is available, null is preferable to inventing one.

### Maintenance
The probe does not create maintenance results. The production Inventory section must reuse MT module results already produced during the same execution. It must not run a second Windows Update scan merely to fill the JSON.

## Probe data deliberately excluded from production Inventory

The probe collected these for evaluation only:

- disk/volume health and operational status;
- volume free/used/percentage values;
- GPU adapter RAM/current status;
- link speed, DHCP state, Internet connectivity/profile/category;
- raw AppX publisher/signature/status and per-user SID mappings;
- local account and profile enumeration;
- hotfix history;
- global signed-driver catalogue;
- detailed BitLocker state;
- raw Winget table output;
- services summary.

These remain out unless a future schema explicitly adds them.

## Performance evidence retained

Latest validated broad-probe run: approximately 12.857 s total.

Earlier broad runs were approximately 15.9 s and 11.2 s, confirming meaningful source warm-up/cache variance.

The MT 4.0 baseline on the same machine recorded approximately 6 s for its Inventory module. This baseline remains useful until the MT 5 benchmark is complete.
