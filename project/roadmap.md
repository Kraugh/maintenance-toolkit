# Development process / Processo di sviluppo

Maintenance Toolkit is developed in focused development cycles. Bug reports, feature requests and user feedback are collected continuously; open issues and approved roadmap goals are reviewed before each implementation cycle.

Maintenance Toolkit viene sviluppato tramite cicli di sviluppo mirati. Bug report, richieste di funzionalità e feedback vengono raccolti continuamente; le issue aperte e gli obiettivi approvati della roadmap vengono riesaminati prima di ogni ciclo di implementazione.

Release dates are intentionally not fixed. Quality, reliability and documentation consistency take priority over speed.

Le date di rilascio non sono prefissate. Qualità, affidabilità e coerenza della documentazione hanno priorità sulla velocità.

---

# Roadmap

> The roadmap contains approved project goals. GitHub Issues are the operational work items used to implement them. The order of sections is not necessarily chronological.
>
> La roadmap contiene obiettivi approvati del progetto. Le GitHub Issue sono le unità operative usate per realizzarli. L'ordine delle sezioni non rappresenta necessariamente l'ordine cronologico di implementazione.

## Current stable baseline / Stato stabile attuale

- [x] Maintenance Toolkit **4.0.0** stable release
- [x] Native `MaintenanceToolkit.exe` launcher
- [x] Authenticode-signed and timestamped launcher
- [x] Windows 10 and Windows 11 validation
- [x] Interactive and non-interactive execution
- [x] `-RunAll`, `-Only`, `-SelfTest`, `-CheckUpdates`
- [x] Windows Task Scheduler documentation and validation
- [x] JSON-based EN/IT runtime localization with English fallback
- [x] Network Diagnostics integrated into MT
- [x] Network technical reports and correlated JSON artifacts
- [x] Initial deterministic Network Diagnostics Rules Engine
- [x] Initial VPN detection, routing and split/full-tunnel analysis
- [x] Optional Ookla Speedtest integration
- [x] Per-computer and per-session logging
- [x] Public GitHub release package and checksum workflow
- [x] Public Maintenance Toolkit documentation on kraugh.it
- [x] Mandatory pre-release documentation gate

---

## Maintenance Toolkit 5.0.0 — Inventory and DMT interoperability

The next major architectural objective is a structured machine inventory that remains useful to MT itself while exposing a stable, versioned interchange contract for **Dashboard Maintenance Toolkit (DMT)**.

The architectural boundary is:

```text
MT observes the machine -> Inventory JSON -> DMT interprets, stores and manages
```

MT must remain independently usable and must not become an RMM agent. DMT-specific concepts such as tenant, site, department, assignee, contract or warranty ownership remain outside MT.

The approved work for this release is grouped in the GitHub milestone **5.0.0**. The operational issues are:

- **#14** — Define Inventory Schema 1.0.
- **#15** — Implement Windows inventory data collector.
- **#16** — Implement inventory snapshot writer and optional remote publishing.
- **#17** — Define inventory reliability, status and error model.
- **#18** — Profile and benchmark Inventory performance.
- **#19** — Validate Inventory across representative Windows environments.
- **#20** — Expand JSON localization to six official languages.
- **#21** — Align documentation, schema examples and public release material.

Existing enhancement issues **#5**, **#9**, **#11** and **#12** remain valid future work but are intentionally outside the 5.0.0 milestone unless a later planning decision explicitly changes the release scope.

### Inventory Schema 1.0 — #14

- [ ] Define and document a stable **Inventory Schema 1.0**, versioned independently from the MT application version.
- [ ] Include collector metadata, `snapshotId`, timezone-aware `collectedAt` and overall collection status.
- [ ] Define required, optional, unavailable and partial-data semantics.
- [ ] Keep schema field names and machine-to-machine identifiers stable and language-independent.
- [ ] Produce at least one anonymized real-world example JSON before the contract is considered stable.

### Inventory collection — #15

- [ ] Collect multiple device identifiers: hostname, SMBIOS UUID, BIOS serial, manufacturer/model, asset tag and other reliable chassis/baseboard identifiers where available.
- [ ] Collect OS, build/UBR, architecture, locale, boot/uptime and other reliable operating-system metadata.
- [ ] Collect BIOS/UEFI, Secure Boot and TPM/security-hardware information where supported.
- [ ] Collect CPU information with multi-socket support.
- [ ] Collect total RAM and DIMM details.
- [ ] Collect physical storage, volumes and filesystems.
- [ ] Collect GPU information.
- [ ] Collect network adapters, addressing, gateways, DNS, DHCP, MAC, link speed, adapter type and physical/virtual classification without collecting secrets.
- [ ] Collect installed Win32 software from uninstall registry sources; do **not** use `Win32_Product`.
- [ ] Keep Winget as an additional source rather than the only canonical software source.
- [ ] Evaluate AppX/MSIX collection and system-component noise.
- [ ] Collect detected local users/profiles and domain/workgroup/Entra/hybrid-join facts without treating them as DMT assignment data.
- [ ] Evaluate Windows Update state, BitLocker state, relevant drivers and additional firmware data as later inventory increments where sustainable.

### Reliability and status model — #17

- [ ] Give each major inventory section an explicit `ok`, `partial`, `unavailable`, `error` or `not_supported` status.
- [ ] Reserve overall `ERROR` for an unusable snapshot; partial category failures must not invalidate otherwise useful inventory.

### Performance profiling and benchmark — #18

- [ ] Record collection timing and duration metadata.
- [ ] Profile individual inventory sections so expensive collectors can be measured rather than excluded on theoretical performance concerns.
- [ ] Benchmark MT 4.0 versus MT 5.0 on the same hardware: collection time, serialization, local write, optional remote copy, JSON size, memory and total MT duration.

### Snapshot output and optional publication — #16

- [ ] Every inventory execution creates a new snapshot; do not suppress output merely because the machine appears unchanged.
- [ ] Always save a complete inventory JSON locally.
- [ ] Define the final CLI/configuration contract for an optional remote inventory destination.
- [ ] Make remote publication best-effort: remote failure is logged as a warning and does not destroy the valid local snapshot.
- [ ] Use an atomic remote-write strategy such as temporary file plus final rename so consumers never import incomplete JSON.
- [ ] Use sanitized descriptive filenames without treating the filename itself as device identity.

### Validation — #19

- [ ] Test Inventory Schema and collection on representative Windows 10/11 systems and differing hardware configurations.
- [ ] Test standalone, domain-connected and other supported identity/join conditions where available.
- [ ] Test optional remote publication with share available, unavailable, permission denied and slow/interrupted conditions.
- [ ] Verify unique `snapshotId` generation and atomic-write behaviour.
- [ ] Validate partial/unavailable/error handling with deliberately missing or unsupported data sources.

---

## Internationalization / Internazionalizzazione — MT 5.0.0 / #20

Internationalization is a project-wide architectural requirement, not an optional UI enhancement.

- [x] External JSON localization architecture exists in MT 4.0.
- [x] Automatic system-language detection exists for the currently supported languages.
- [x] English fallback exists.
- [x] Explicit language override exists.
- [ ] Make the official MT language set: **Italian, English, German, French, Japanese and Simplified Chinese**.
- [ ] Ensure all MT-generated user-facing UI text is loaded from external language JSON resources; no user-facing string may be hard-coded in application logic.
- [ ] Allow a supported language to be added by adding a language JSON resource without changing application logic.
- [ ] Define validation for missing keys, invalid language files and fallback behaviour.
- [ ] Keep technical identifiers, schema field names, exit codes and machine-to-machine contracts language-independent.
- [ ] Review documentation language coverage as each public release requires it.

See `docs/LOCALIZATION.md` for the project-wide localization contract.

---

## MT 5.0.0 documentation and release alignment — #21

- [ ] Publish and validate Inventory Schema 1.0 documentation and anonymized examples.
- [ ] Keep current repository documentation aligned with the implemented release behaviour.
- [ ] Keep localization documentation aligned with the language resources actually shipped.
- [ ] Review the current source archive of the public `kraugh.it/software/` pages before release rather than relying on cached/crawled content.
- [ ] Treat obsolete, missing or contradictory public documentation as a release issue unless explicitly accepted.
- [ ] Preserve historical sprint/release documents as historical records rather than rewriting them to match current behaviour.

---

## Network Diagnostics evolution

The MT 4.0 Network Diagnostics foundation is released. Future work is tracked as independent enhancements rather than as unfinished MT 4.0 scope.

- [ ] Expand deterministic Network Diagnostics rule coverage and remediation guidance — GitHub **#12**.
- [ ] Expand Advanced VPN Diagnostics — GitHub **#11**.
- [ ] Preserve evidence-based interpretation and avoid treating normal virtual/VPN configurations as faults.
- [ ] Keep optional external tools supplementary rather than required by the core diagnostics engine.

---

## Support and diagnostic package

- [ ] Create an on-demand Support Package ZIP for troubleshooting — GitHub **#9**.
- [ ] Define which MT logs, reports and selected Windows diagnostic evidence belong in the package.
- [ ] Evaluate selective Windows Event Log export and other useful troubleshooting evidence.
- [ ] Define privacy, sensitive-data, archive-size and retention rules before implementation.
- [ ] Keep the Support Package distinct from the Inventory Schema/DMT snapshot contract.

---

## Long-running native tool output

- [ ] Evaluate native DISM/SFC progress output and an optional verbose mode — GitHub **#5**.
- [ ] Preserve MT's rule of never inventing progress percentages or remaining-time estimates.
- [ ] Keep native Windows tool output native; only MT-generated surrounding UI is localized by MT.

---

## Automated and centralized execution

- [x] Non-interactive `-RunAll` execution.
- [x] Targeted `-Only <Key>` execution.
- [x] `-SelfTest` and `-CheckUpdates` command-line modes.
- [x] Windows Task Scheduler guidance and validated background execution.
- [x] Exit-code propagation documented and validated for scheduled execution.
- [ ] Validate execution as `SYSTEM` where useful.
- [ ] Validate Winget behaviour in `SYSTEM` context.
- [ ] Evaluate additional SMB-share and removable-media execution scenarios where they provide real operational value.
- [ ] Consider `-Debug` / more verbose diagnostic logging only when a concrete troubleshooting requirement justifies it.

---

## Toolkit updates and distribution

- [x] Single application version source and remote stable manifest.
- [x] Manual update check from MT.
- [x] GitHub release ZIP and SHA-256 workflow.
- [x] Signed native launcher.
- [x] Public Maintenance Toolkit pages and documentation on kraugh.it.
- [ ] Evaluate opening the official download page directly from MT.
- [ ] Consider automatic self-update only after the manual update workflow remains proven and the trust/security model is explicitly designed.
- [ ] Consider release-history and video material as documentation improvements, not release blockers unless explicitly selected for a release.

---

## OEM and advanced maintenance

Possible future improvements remain subject to issue selection and validation:

- [ ] Improve HP integration.
- [ ] Improve Dell integration.
- [ ] Add Lenovo support.
- [ ] Separate OEM application, driver and firmware update responsibilities more clearly.
- [ ] Evaluate Windows Update history analysis.
- [ ] Evaluate advanced SMART/storage diagnostics.
- [ ] Evaluate advanced HTML diagnostic reporting.
- [ ] Evaluate optional Sysinternals integration.

---

## DMT boundary

Dashboard Maintenance Toolkit is a separate project and repository.

MT may produce stable inventory/report artifacts that DMT consumes, but MT does not own:

- tenant/site/department modelling;
- asset assignment;
- contracts or warranty management;
- dashboard history and endpoint-state interpretation;
- DMT authentication, authorization or web UI.

DMT decides its own `AssetId` from the identifiers observed by MT. MT must not generate a DMT-specific asset identity.
