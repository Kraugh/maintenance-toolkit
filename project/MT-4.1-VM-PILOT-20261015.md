# MT 4.1 — VM pilot evidence, 15 October 2026

**Latest verified private candidate: R04 / 4.0.9006.** See the R04 follow-up below; earlier R03 statements are historical. No public release.

User confirmed a Hyper-V checkpoint, authorized real local installation/task tests and activated SimplySign. No publication, automatic restart or maintenance-module execution.

## MSI and SYSTEM — verified

- Published 4.0.6 MSI installed with exit 0, CREATE_TASK=0 and restart suppression. No prior MT MSI installation was overwritten.
- Private 4.0.9004 application passed installed-byte verification, but the pilot exposed two COM null outputs in Assert-MTMsiIdentity. Fixed Execute/Close output suppression in the source and verified against a real Windows Installer database.
- New immutable private candidate **4.0.9005/R03** built, signed and applied through Invoke-MTPreparedApplication to the pilot MSI installation. Result: Verified. This tests the application engine, not an updater command in the old 4.0.6 runtime.
- Settings/INI bytes and protected opt-in hashes preserved. InventoryShare retained; MSI-owned task XML restored exactly. Local logs/reports fixture files preserved.
- Real transaction consumed once, replay rejected, payload removed.
- Real MSI-owned task updated in place, principal SYSTEM/highest, IgnoreNew. Started only scheduled update detection: native last result **0**. Pilot MSI task removed afterward.
- Pre-existing user standalone task XML remained unchanged. No GPO task touched and no reboot occurred.
- Signatures, timestamp, initial producer certificate pin, online revocation, signed metadata/catalogs and artifact hashes checked by production verification code. Private test metadata was staged locally; no public feed was modified. The first release still requires a documented bootstrap because stable 4.0.6 has no applying updater.

## Outputs and retained state

- Current signed candidate: `C:\Projects\Open-Source\maintenance-toolkit\dist\MaintenanceToolkit-Pilot-20261015-180705-9fde84c3-R03`. MSI duplicate: `C:\Projects\Open-Source\maintenance-toolkit\packaging\msi\out\MaintenanceToolkit-Pilot-20261015-180705-9fde84c3-R03`. Frozen source: `C:\Projects\Open-Source\maintenance-toolkit\dist\staging\mt-21af-r03`.
- Protected pilot evidence: `C:\ProgramData\MaintenanceToolkit-Pilot-20261015-180705-9fde84c3-R03` (`pilot-result.json`, verbose MSI log and driver).
- Installed private pilot: `C:\Program Files\Kraugh\Maintenance Toolkit`, runtime/MSI 4.0.9005. Retained for further testing, not a public release.
- Earlier candidate and failed/diagnostic runs retained at `C:\Projects\Open-Source\maintenance-toolkit\dist\MaintenanceToolkit-Pilot-20261015-175925-21af8173` and `C:\ProgramData\MaintenanceToolkit-Pilot-20261015-175925-21af8173-R02`; original pre-install refusal evidence at the same prior stage without the -R02 suffix.
- Private version mapping exists only in frozen copies. Working-tree version 4.1.0-dev.3 and public 4.0.6 artifacts remain unchanged.

## Test status and remaining gates

112 frozen-candidate isolated tests passed. Current source additionally passes two optional real-MSI COM tests (114 total). Real ZIP replacement/locked-directory recovery is pending elevation. A separate SYSTEM/UNC probe and complete helper-to-runtime resume remain pending. In-memory download interruptions do not prove a real network interruption; MSI rollback/interruption has not been validated. New test scripts and local evidence under launcher/build and dist are retained, not shipped or committed. Full website-source review still requires current hosting sources.

This is narrower than closing #27/#28: no issue was modified/closed. Full acceptance and release gates remain open.

ZIP pilot launch returned the native Windows error "Operazione annullata dall’utente" at UAC. No ZIP test started and no ZIP installation directory was created. Await explicit retry before showing elevation again. MSI pilot remains Passed.

## R04 follow-up — verified results

The initial directory-handle probe did not block renaming, so it was not evidence of recovery. The corrected file-handle probe reproduced a real failure and exposed a production defect: PowerShell Move-Item could partially move directory contents before failing. ZIP apply/recovery now use System.IO.Directory.Move for atomic same-volume sibling renames. Earlier partial trees remain diagnostic evidence, not recovered installations.

| Check | Verified result |
|---|---|
| Locked-file ZIP replacement | RecoveryRequired, CanResume=false; no partial backup after the fix |
| ZIP recovery | Previous application hashes verified; Recovered |
| Subsequent ZIP upgrade | Verified; settings/INI/opt-in and log/report fixtures preserved |
| ZIP cleanup/replay | Backup/next/payload removed; consumed handoff cannot replay |
| Separate helper | Real old-to-new ZIP application, parent-exit coordination and one resumed diagnostic session |
| Resumed analysis | Connectivity, Inventory, NetworkReport and DiskHealth OK; NVIDIA SKIP (no matching GPU); no install/cleanup modules executed |
| Signatures | Real damaged signed catalog and unsigned script rejected |
| SYSTEM identity | Actual probe SID S-1-5-18 |
| SYSTEM UNC | JSON copied through the local loopback administrative share with identical SHA-256 |
| Unavailable UNC | WARN; local JSON retained |
| Task isolation | Temporary probe task removed, user standalone XML unchanged |
| Real HTTPS interruption | Published 4.0.6 ZIP connection aborted after 32 bytes; production downloader rejected it and removed partial/final payload |
| R04 regression | 117 checks passed, including real MSI COM and locked-file filesystem cases |
| R04 MSI | Native exit 0; installed payload verified; settings/INI/disabled opt-in and user task preserved; transaction consumed and payload removed |

The VM reported a discharging battery. The harmless probe initially did not start because its default task settings blocked battery execution. Battery execution was enabled only for that temporary probe. User tasks and product defaults were not changed. Loopback UNC success does not establish permission to a corporate SMB server under a computer account.

An extra attempt to produce ERROR_INSTALL_ALREADY_RUNNING using a bounded mutex-holder process was inconclusive: Windows Installer instead completed the real R04 upgrade with exit 0. Do not count this as tested MSI error 1618, rollback or mid-install interruption. The blocker process was terminated; no permanent mutex/task/service was added. Reference for the attempted scenario: [Microsoft Windows Installer mutex documentation](https://learn.microsoft.com/en-us/windows/win32/msi/-msiexecute-mutex).

Current outputs: `C:\Projects\Open-Source\maintenance-toolkit\dist\MaintenanceToolkit-Pilot-20261015-185059-cf9a6d0b-R04`; MSI duplicate: `C:\Projects\Open-Source\maintenance-toolkit\packaging\msi\out\MaintenanceToolkit-Pilot-20261015-185059-cf9a6d0b-R04`; frozen source `C:\Projects\Open-Source\maintenance-toolkit\dist\staging\mt-zip-r04`. Protected raw evidence: `C:\ProgramData\MaintenanceToolkit-Pilot-20261015-185059-cf9a6d0b-R04` (`grouped-result.json`, `zip-recovery-result.json`, `system-unc-result.json` inside the group directory, `msi-r04-verification.json`, `successful-r04-msi.log`). Raw diagnostic output can contain machine identity and stays outside versioned documentation.

Installed VM pilot remains at `C:\Program Files\Kraugh\Maintenance Toolkit`, now version **4.0.9006**. The working tree still identifies development 4.1.0-dev.3. Private signed manifests expire after two days and were never uploaded; do not reuse expired test metadata as a public release.

The real HTTPS test is retained in `tools/Test-MTUpdateNetworkInterruption.ps1`; its fixture `launcher/build/MaintenanceToolkit-NetworkInterruption-20261015-185929-3b10decc` was removed. The small preliminary fixture `launcher/build/MaintenanceToolkit-ZipLockProbe-20261015-184414` remains: automatic approval review rejected both recursive and item-by-item cleanup with "blocked by policy". Do not bypass that rejection. Other failed private pilot trees and their journals/backups are retained for review. Normal successful transaction payloads/backups and temporary SYSTEM tasks were removed and verified.

## Remaining release gates

- Controlled real MSI failure/rollback after file changes is now verified below. Abrupt VM power loss or service termination was not simulated and is not covered by this result.
- End-to-end production endpoint retrieval and stable-version bootstrap/release documentation remain to finalize. Staging signed local metadata validates application/trust, not a deployed update feed.
- A corporate UNC destination under the actual organization/computer identity remains an enterprise pilot, separate from this loopback test.
- Website documentation review still requires current hosting sources. Seven-language resources have partial historical coverage, as documented; public documentation remains IT/EN.
- No issue closure, commit/push, tag, public manifest change or release occurred.

## Controlled real MSI rollback — passed

A separate **4.0.9007 INTENTIONAL-FAILURE fixture**, not a candidate, added a deferred WixQuietExec action after InstallFiles that exits 42. Only the frozen test Product.wxs changed. Production MSI source, R04 and the public release were unchanged. The fixture, payload catalog and metadata were signed and authenticated normally; no trust check was disabled.

The real native MSI result was **1603**. Verbose logs record actual file-copy operations, the forced deferred failure and rollback. The updater returned RecoveryRequired/CanResume=false and blocked a fresh maintenance execution. Windows Installer restored runtime **4.0.9006**, all pre-upgrade application hashes and the single original MSI product registration; failed 4.0.9007 was absent. Settings/INI bytes, protected opt-in, InventoryShare and the user task XML were preserved. Explicit recovery verified the old installation, cleared the block without resuming maintenance, and removed the failed payload. Metadata sequence remained unchanged. No reboot occurred. All 18 rollback checks passed.

This supersedes the earlier unverified controlled-rollback gate, but does not turn the inconclusive mutex experiment into a successful 1618 test and does not certify abrupt power loss. Usable installed pilot remains **4.0.9006**; never install/distribute the 4.0.9007 failure fixture.

Evidence: R04 protected stage `intentional-rollback/rollback-result.json` and `intentional-failure-msi.log`. Fixture output: `dist/MaintenanceToolkit-RollbackTest-20261015-190844-b207bf39-INTENTIONAL-FAILURE`; MSI duplicate under packaging/msi/out with the same directory name, frozen source `dist/staging/mt-rollback`, driver/manifest under launcher/build with the same unique name. These are retained as failure-test evidence and clearly marked, not release artifacts.

Final verification: 81 runtime/config/language files in R04 match current working-tree sources after only private version normalization; 68 PowerShell scripts parse without errors; all local file targets in 54 documentation files resolve; git diff --check passes. Published 4.0.6 EXE/MSI/ZIP hashes remain unchanged.

## Windows 10 test waiver — user approved

15 October 2026: the user explicitly waived the Windows 10 test for this 4.1 phase. It is no longer a blocking test in this phase, but Windows 10 must not be described as validated by this pilot. Actual environment: Windows 11 Pro build 26200 / Windows PowerShell 5.1. Other release gates remain in force. See [release preparation](MT-4.1-RELEASE-PREPARATION.md).
