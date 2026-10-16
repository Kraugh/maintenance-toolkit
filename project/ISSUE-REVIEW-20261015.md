# GitHub issue review — after 4.1.1 deployment, 15 October 2026

Review started 15 October; final publication/withdrawal checks completed 16 October 2026, Europe/Rome. Issue #27 closed on 15 October at 21:35:51 Rome; remaining count verified as sixteen.

User authorized review/closure of actually resolved issues and documentation alignment. Sources: live issue bodies for all 17 open issues, implementation/tests, [private VM pilot](MT-4.1-VM-PILOT-20261015.md), [4.1.1 package/deployment evidence](MT-4.1.1-RELEASE-VERIFICATION.md). No runtime, package, version or signed metadata changed. The [14 October review](ISSUE-REVIEW-20261014.md) remains historical.

## Completed action

**[#27 — standalone scheduled-task configuration](https://github.com/Kraugh/maintenance-toolkit/issues/27) closed as completed**, with [evidence comment](https://github.com/Kraugh/maintenance-toolkit/issues/27#issuecomment-6200662453).

| Acceptance area | Evidence and scope |
|---|---|
| Create/inspect/update/remove | P implements all operations; 118 regressions include wizard interaction and Windows task API boundaries. Task API mutations are mocked in isolated tests. |
| Triggers, modules and consent | Daily/multiple times, weekdays and startup; enabled maintenance modules shown before consent, explicit replacement/removal confirmation. Source Scheduling.ps1 and regression wizard coverage. |
| SYSTEM/highest, no overlap | Real VM task update/removal and SYSTEM detection run returned native result 0; IgnoreNew. Launcher handles interactive elevation; headless execution remains non-interactive. |
| Missed runs, power/network and task status | Configurable conditions and last/next/result inspection; regression assertions and diagnostic schedule-events.jsonl. |
| Ownership and localization | Foreign/GPO task mutation rejected, machine policy rechecked at mutation, protected paths required. Pre-existing user task XML unchanged in real pilot. UI strings in JSON, public IT/EN instructions and deployed website guide. |

Windows 10 test was waived; Windows 11/PowerShell 5.1 pilot evidence and loopback UNC are not corporate SMB or additional platform guarantees. No automatic reboot or extra permanent updater task.

## Remaining issues — 16 open

| Issue | Decision / residual work |
|---|---|
| [#28](https://github.com/Kraugh/maintenance-toolkit/issues/28) secure one-click updates | Keep open. Implementation, private MSI/ZIP application/recovery, 118 regressions, signatures and real deployed transport/trust pass. Exact final public 4.1.1 installation from the supported previous stable baseline, with post-install version/settings/exceptions/InventoryShare/task checks, remains unperformed. Public download verification is not installation evidence. [Progress comment](https://github.com/Kraugh/maintenance-toolkit/issues/28#issuecomment-6200663476). First 4.0.6 -> 4.1.1 bootstrap is manual. |
| [#26](https://github.com/Kraugh/maintenance-toolkit/issues/26) complete MSI/GPO guide | Keep open: paired source/site alignment passed, but complete real GUI screenshots, clean-pilot procedure-only reproduction and both initial GPO assignment/upgrade are not established. |
| [#20](https://github.com/Kraugh/maintenance-toolkit/issues/20) seven-language localization | Keep open: H/selection/persistence/fallback and seven targets ship, but five translations are partial; full historical/UI and representative non-Latin validation remain. Updated issue scope to approved Spanish; Swedish is legacy compatibility. |
| [#21](https://github.com/Kraugh/maintenance-toolkit/issues/21) MT 5.0 documentation/schema | Keep open: 4.1.1 website gate is complete; broader MT 5.0 schema/source/reliability/example scope is not. |
| [#29](https://github.com/Kraugh/maintenance-toolkit/issues/29) Dell outcomes/restore | Keep open: representative live SYSTEM/deferred/restart and user-session comparison/timeout evidence remain incomplete. |
| [#25](https://github.com/Kraugh/maintenance-toolkit/issues/25) OEM provider architecture | Keep open: existing Dell/HP foundation does not establish all provider service/restart/post-check recovery requirements. |
| [#30](https://github.com/Kraugh/maintenance-toolkit/issues/30) NVIDIA professional validation | Keep open: representative desktop/mobile/multi-GPU/ambiguous/offline/CAD-ISV validation remains; advisory-only boundary unchanged. Its old checkpoint release restrictions are historical. |
| [#24](https://github.com/Kraugh/maintenance-toolkit/issues/24) three presentation modes | Keep open: future GUI/shared presentation architecture is not complete. |
| [#23](https://github.com/Kraugh/maintenance-toolkit/issues/23) Port & Service Analyzer | Keep open: feature not implemented. |
| [#19](https://github.com/Kraugh/maintenance-toolkit/issues/19) inventory environment matrix | Keep open: representative hardware/join/source/remote failure matrix incomplete. |
| [#18](https://github.com/Kraugh/maintenance-toolkit/issues/18) inventory performance | Keep open: repeatable MT4/MT5 baseline timings and memory/size/remote-cost measurements missing. |
| [#17](https://github.com/Kraugh/maintenance-toolkit/issues/17) inventory reliability model | Keep open: complete section/overall semantics and fault matrix not validated. |
| [#12](https://github.com/Kraugh/maintenance-toolkit/issues/12) expanded rules engine | Keep open: foundation shipped, complete planned rules/remediation coverage not delivered. |
| [#11](https://github.com/Kraugh/maintenance-toolkit/issues/11) advanced VPN engine | Keep open: full provider/routing/DNS/MTU/before-after scope not complete. |
| [#9](https://github.com/Kraugh/maintenance-toolkit/issues/9) support ZIP | Keep open: release packaging is not a runtime per-computer support ZIP generator. |
| [#5](https://github.com/Kraugh/maintenance-toolkit/issues/5) DISM/SFC native progress | Keep open: elapsed time/spinner is not native tool percentage/output support. |

No acceptance criterion removed to force a closure. Existing closed foundation issues remain closed. No new maintenance, installation, task or hardware test performed for this audit.

## 4.1.0 withdrawal

The maintainer reports no end-user downloads/adoption of 4.1.0 and that users will take 4.1.1. GitHub download counters are nonzero and include our documented verification downloads; they cannot establish or exclude external users. Do not turn that report into a measured zero-download assertion.

At 21:34 Europe/Rome, **4.1.0 was moved to a non-public draft**, a reversible withdrawal. All eight original assets retain their sizes/digests; tag v4.1.0 and its source commit remain. No package overwritten, release/tag deleted or Git history rewritten. 4.1.1 remains the public Latest release, and current site/API links already point to 4.1.1. Historical 4.1.0 URLs/evidence remain labelled as such; do not distribute the withdrawn release. Normal user path is 4.0.6 -> verified 4.1.1 bootstrap; technical old-client compatibility notes remain historical.

Unauthenticated checks on 16 October: old-release GitHub API returns 404, old MSI/ZIP download URLs return 404. The tag-related HTML page may still return 200, with no old binary download links; source-tag visibility is intentional. Authenticated API confirms draft=true with eight preserved assets. 4.1.1 release remains public and hosting detection advertises 4.1.1. Existing website binary/feed links require no new upload for this withdrawal.

## Retained evidence and limits

`launcher/build/MaintenanceToolkit-IssueReview-20261015-212500` stores original issue/release snapshots, updated issue body/comment files, release-withdrawal state and asset comparison. These are temporary review evidence, intentionally retained; raw old issue bodies are not copied into public documentation. No new dependencies/tasks or binary artifacts. Documentation changes do not alter already published 4.1.1 package bytes.
