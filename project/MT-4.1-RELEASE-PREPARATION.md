# MT 4.1 — release preparation

Status: the user subsequently authorized final 4.1.0 preparation and GitHub publication if checks pass. The checklist below preserves the preceding preparation gate; current results are in [release verification](MT-4.1-RELEASE-VERIFICATION.md). Website deployment remains manual and separate. User waived the Windows 10 test on 15 October 2026; disclose actual Windows 11/PowerShell 5.1 evidence without extending it.

## Verified locally

- R04 / private 4.0.9006: 117 regressions and real MSI/ZIP, locked-file recovery, controlled MSI rollback, helper/single resume, SYSTEM/loopback UNC and aborted HTTPS tests.
- Existing user task unchanged; temporary tasks and successful/verified recovered transaction payloads removed. Installed VM pilot remains 4.0.9006.
- 4.0.9007 INTENTIONAL-FAILURE is exclusively rollback-test evidence, never a candidate.
- Production sources exclude the failure custom action. Stable 4.0.6 files remain immutable.

## Remaining preparation gates

1. Hosting archive and manifest received/reviewed on 15 October: [findings and exact retained inputs](WEBSITE-REVIEW-20261015.md). Sixteen HTML pages have no missing relative targets; stable references remain 4.0.6. Apply the listed paired IT/EN corrections to a review copy, then verify final downloads/hashes and rendering against the final candidate. Source review is complete; website alignment/publication is not.
2. Review the paired [English upgrade instructions](../docs/eng/UPGRADING-MT.md) / [Italian instructions](../docs/ita/AGGIORNAMENTO-MT.md), initial manual bootstrap from 4.0.6 and GPO ownership. Runtime is multilingual; public material only IT/EN, with partial translation scope stated honestly.
3. After documentation alignment, finalize the real 4.1.0 version consistently, freeze sources, rebuild via canonical tools, sign/verify EXE and MSI, package ZIP and authenticate its scripts/resources with the signed payload catalog. Existing private/public packages are not overwritten.
4. Generate final authenticated update-v1 metadata/catalog after final bytes/checksums. Choose a monotonic sequence compatible with existing state (the VM pilot has sequence 3), explicit expiry/refresh procedure and correct official URLs. No stable-feed deployment occurs during preparation. version.json remains detection; update-v1.json/.cat is the applying contract.
5. Verify final archives, signatures/timestamps/publisher, package-to-source contents, documentation links, final SelfTest and expected exit codes. Prepare IT/EN release/site text and list the Windows 10 waiver, actual UNC test scope and limits.
6. Publication is a later explicit action with the normal Rome time-window check. Verify uploaded assets/feed only when authorized; close issues only against complete acceptance/release evidence.

## Retained files and cleanup

No manual cleanup is currently required from the user. Keep signed R04, raw evidence and the installed pilot for review/final validation. Preserve failed partial-move trees and the intentional-failure fixture as clearly marked diagnostic evidence. Temporary SYSTEM tasks and completed/recovered transaction payloads are already removed; no permanent updater task was created.

Automatic approval review rejected deletion of launcher/build/MaintenanceToolkit-ZipLockProbe-20261015-184414, including a safer item-by-item attempt, with "blocked by policy". The harmless fixture remains recorded; do not bypass the rejection or ask the user to rediscover its name. Historical retained staging is listed in [validation](MT-4.1-LOCAL-VALIDATION.md) and [pilot evidence](MT-4.1-VM-PILOT-20261015.md).
