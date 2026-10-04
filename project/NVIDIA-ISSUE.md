## Problem

OEM utilities propose vendor-qualified drivers but may leave NVIDIA professional graphics drivers behind the NVIDIA catalogue. Engineering workstations need visibility without automatic installation or package download.

## Scope: 4.0.4-dev.7-NVDOK working-tree checkpoint

- Collect installed NVIDIA GPU models and Windows/NVIDIA driver versions with inbox Windows tools.
- Search the current professional NVIDIA catalogue with exact model and desktop/mobile matching.
- Report available compatible Windows 11 x64 WHQL Enterprise Production candidates as WARN, including installed/available versions and an official details link.
- Preserve per-GPU JSON and original catalogue replies. Unknown/ambiguous models and failed checks remain verification_incomplete, never up to date.
- Remove all experimental NVIDIA download/install paths and CLI switches from this checkpoint.
- Keep EN/IT/SV localization. No unapproved external dependencies.

## Evidence and limits

KRAUGHHQ / Quadro P620: installed 528.89 was correctly compared with catalogue candidate 582.78. An experimental FNV installation reached 582.78 after restart, although NVIDIA returned exit code 0 and MT initially missed the restart requirement. That experimental installer is excluded from NVDOK and is not validated for production workstations.

## Remaining validation

- [ ] Validate NVDOK syntax/regressions and a live read-only scan on the updated P620.
- [ ] Inventory engineering-department workstations read-only and record models/current/candidate versions.
- [ ] Validate additional desktop/mobile Quadro and RTX catalogue mappings on representative hardware.
- [ ] Confirm correct behavior for multiple GPUs, ambiguous models, unavailable catalogue, newer installed versions and no NVIDIA devices.
- [ ] Evaluate CAD/ISV requirements before recommending or distributing driver changes.

## Future, separate scope

Explicit administrator-controlled updates, reliable restart evidence even with exit 0, post-restart verification, rollback and payload cleanup require a separate approved workflow. AMD/Intel/GeForce support requires approved scope and test hardware.

## Release policy

Commit/push development sources only. Keep the public/downloadable release and stable update manifest at **4.0.3**. Do not create a 4.0.4 GitHub Release, tag or asset. Dell stabilization continues separately under #29.
