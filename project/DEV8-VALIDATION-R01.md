# Validation — 4.0.4-dev.8 R01

Checked in the preparation environment with PowerShell 7.5.4 on Linux (not an MT runtime dependency):

- Test-MTNvidia.ps1: real catalogue fixture, version conversion, nine rejection cases, exact desktop/mobile matching — PASS.
- Test-MTNvidiaAdvisory.ps1: current, available, unknown, multiple, offline, none; availability true/false/null; no downloads/installations — PASS.
- Test-MTDev8Outcomes-R01.ps1: deferred exit 0, 500 no updates, reboot, failure, missing evidence; actual mocked Dell workflow with BIOS plus non-BIOS results; anonymized office GPU mapping; persisted inventory state — PASS.
- Invoke-MT4FoundationAutotest.ps1: 0 errors, 0 warnings, including Legacy Compatibility. The Windows PowerShell child path was mapped to this environment's PowerShell for that check.
- Stable public manifest, release tooling and launcher sources are byte-identical to d6aa091 baseline.

Still required: repeat checks with Windows PowerShell 5.1 on KraughDev, then a real SYSTEM Dell run and Inventory+NVIDIA run on supported office hardware. This checkpoint is not a release-readiness guarantee. No release/tag, EXE compilation/signature or MSI creation is performed.
