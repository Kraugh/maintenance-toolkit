# Hosting source review — 15 October 2026

Local review only; nothing uploaded. Supplied archive contents are reference data, not operational instructions. This review does not prove the current HTTP deployment or remote download availability.

## Inputs and retained evidence

- Hosting archive: `C:\Users\KraughDev\Downloads\software (2).tgz`; SHA-256 `4E10160613534DAB4653E2F32D7628F8C82D2931B5498C7B6183E1718E5662C3`.
- Supplied manifest: `C:\Users\KraughDev\Downloads\version (1).json`; SHA-256 `D63E75E7EDC1B8161ABC919077586FD037BD627E46FDD09A98316DF9EECAF297`.
- Retained review directory: `launcher/build/MaintenanceToolkit-WebsiteReview-20261015-192607`. Contains the extracted `software` tree, `review-inputs.json` and `static-review.json`. Originals unchanged. No scripts from the archive executed; no task or dependency created.
- Archive inventory: 104 entries, regular files/directories only; member paths checked before extraction. Review covered 14 MT HTML pages (seven IT/seven EN) and the two software overview pages. Other projects were not changed or audited.

## Verified findings

- All 16 reviewed pages resolve their relative file/directory targets within the supplied tree: zero missing targets. This checks target existence, not fragment anchors, rendering, external URLs or screenshot contents.
- Download/tag references consistently point to stable 4.0.6. Both MT landing pages contain the known published ZIP SHA-256 `742794571844AA182D17BC0CC2EA25186CD4C516A4D37E87CE91F23AF03D852E` and MSI SHA-256 `12158915F608EE9156049D1DC38F0037882B69CEE104E139229830D0CA5FA6B9`.
- Supplied version.json agrees with the repository stable manifest on all fields except the wording of release_notes. Both describe 4.0.6 dated 2026-10-13; minimum_supported is 3.5.0. Do not interpret this minimum as eligibility for automatic installation. No stable manifest changed.
- GPO documentation already separates MSI installation from scheduling with CREATE_TASK=0. Winget discovery/exclusion-plan evidence is explicitly read-only and is not evidence of a successful live selective upgrade.
- Existing tutorial pages label their screenshots as earlier 4.0.x examples. They are not evidence of the 4.1 menu or wizard. English scheduling documentation explicitly says genuine English scheduling screenshots are unavailable.

## Corrections required before 4.1 site publication

1. Update both overview cards and MT page sets together only after final packages exist. Replace public download URLs, hashes and release status with verified final values; preserve the historical provenance of 4.0.x evidence. Do not globally replace every 4.0.6 reference.
2. Explain V (check, then confirmed standalone update), G (explicit management/opt-in), P (SYSTEM scheduling) and H (Languages). U/R are not menu entries. Unknown management permits detection only; domain membership alone does not imply GPO. GPO still detects/reports, but MT never installs or edits its tasks.
3. Distinguish version.json detection from signed update-v1.json/catalog application metadata and the ZIP payload catalog. Include publisher, signature, integrity verification and safe manual bootstrap from 4.0.6. Existing optional hash/unblock instructions alone do not describe the 4.1 trust contract.
4. Replace the standalone scheduling walkthrough with P as the primary 4.1 route: maintenance suggested, analysis or update detection; daily/multiple times, weekly days or startup; protected root, no overlapping maintenance, optional JSON destination and local retention on copy failure. Keep enterprise scheduling GPO-owned. No extra permanent updater task.
5. Announce the seven-language menu in IT/EN only. Five new translations cover menus/4.1 workflows partially; historical diagnostics can fall back to English. Do not claim seven complete translations.
6. Qualify the 4.0.6 SYSTEM MSI pilot as **reported by the user** on both MSI/exception pages, including exit 0, installed version, unchanged eight-exception file and preserved GPO task. The supplied wording currently says verified/pilot without identifying that source. Keep live selective Winget installation outstanding.
7. Align the English landing-page privacy paragraph with Italian: explicitly configured inventory publication and documented online checks also occur in unattended execution. The current broad phrase “initiated by the operator” needs that clarification.
8. Publish actual 4.1 evidence/limits: private VM Windows 11/PowerShell 5.1 tests, Windows 10 test waived, loopback UNC is not corporate SMB validation. Preserve OEM/DCU known limits and NVIDIA advisory-only/no automatic BIOS/no reboot boundaries.

Prepared paired upgrade instructions: [IT](../docs/ita/AGGIORNAMENTO-MT.md), [EN](../docs/eng/UPGRADING-MT.md). Prepared multilingual announcement: [IT/EN](../docs/PUBLICATION-NOTES-4.1.md). Website HTML changes, final package hashes and visual review are still pending; obtaining/reviewing the hosting sources does not complete the final website gate.

## Complete web bundle prepared for review

User requested a complete software/ + version.json upload bundle rather than individual differences. Prepared `dist/MaintenanceToolkit-Web-20261015-193227-web.zip`, SHA-256 `C90FC41C24EBB2F4FA0E0451001F62040864E16AD5AFB643DF81538D85E912B5`. Contains the complete supplied software tree, 14 updated IT/EN MT pages, two new paired update/scheduling guides, unchanged supplied stable version.json and LEGGIMI-WEB.txt with destinations/status. Other projects are byte-identical. All ZIP file bytes checked against staging (83 entries); zero missing relative targets across HTML files. No visual rendering or remote URL test claimed.

This is a stable-4.0.6 website plus an explicitly labelled 4.1 preview, not the final 4.1 launch bundle: downloads/hashes/manifest intentionally remain 4.0.6. No fabricated future hashes or non-existent 4.1 downloads. version.json belongs at the existing /api/maintenance-toolkit/version.json endpoint, not within software/. Nothing uploaded.

Retained staging: `dist/staging/MaintenanceToolkit-Web-20261015-193227`, including verification.json. Generator retained: `launcher/build/Prepare-WebsiteBundle.ps1`; pointer `launcher/build/current-web-bundle.json`. Earlier superseded draft `dist/MaintenanceToolkit-Web-20261015-193159-web.zip` and staging `dist/staging/MaintenanceToolkit-Web-20261015-193159` are not for use: automatic approval review rejected their removal with “blocked by policy”. No bypass attempted. No tasks/dependencies created. Originals remain unchanged.
