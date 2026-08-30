# Backlog

This document collects ideas and possible future developments that are **not yet committed roadmap work**.

Items listed here are not scheduled. Approved goals belong in `project/roadmap.md`; concrete implementation work belongs in GitHub Issues selected during planning.

Completed work must be removed from this backlog rather than left here as an apparently unfinished task.

---

## Configuration

- Configure selected modules directly from the menu.
- Restore default configuration.
- Export and import configuration.

## Diagnostics and maintenance

- Analyze `CBS.log` when a concrete diagnostic workflow is defined.
- Evaluate richer Windows Update history analysis beyond inventory requirements.
- Evaluate advanced SMART/storage diagnostics beyond the baseline inventory contract.
- Evaluate advanced HTML diagnostic reports.
- Evaluate optional Sysinternals integration.
- Evaluate SIW only if it provides a clear benefit that cannot be obtained reliably from native Windows sources.

## Deployment and administration

- Validate execution as `SYSTEM` where useful.
- Validate Winget behaviour in `SYSTEM` context.
- Evaluate additional execution scenarios from SMB shares and removable media.
- Evaluate centralized log collection separately from DMT Inventory snapshot publication.

## User experience

- Reorganize the final session summary further if real-world use shows a concrete readability problem.
- Evaluate a public-facing name for developer/self-test functions only if users encounter them directly.
- Consider an optional completion sound.

## Nice to have

- Optional ASCII theme inspired by 1990s interfaces.
- Optional `Classic311` theme.
- Additional coordinated project graphics where useful.
- System-administrator wisdom / Easter eggs in source or non-critical presentation areas.
- Optional hydration/break reminders only if they remain unobtrusive and fully localizable.
- Centralized/localizable `duck-messages` resource if mascot messages grow enough to justify a separate resource.

All user-facing additions remain subject to the localization contract in `docs/LOCALIZATION.md`.

---

## Parking lot — separate projects

### Sweep

Possible future standalone utility for controlled cleanup of directory trees:

- recursive directory scan;
- configurable extensions and filenames;
- `DryRun` mode;
- configurable exclusions;
- preventive ZIP archive;
- preservation of relative paths;
- manifest with original path, hash, size and date;
- log of archived original paths;
- deletion only after archive creation and verification;
- restore to the original location.

### Kraugh Open Source ecosystem

- shared conventions between repositories;
- common documentation structure;
- consistent README, changelog, roadmap and release style;
- coordinated visual identity;
- development process based on documented decisions and issues;
- shared localization principle: external resources, English fallback and no hard-coded user-facing UI strings.
