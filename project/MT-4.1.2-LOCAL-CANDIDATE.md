# MT 4.1.2 — local candidate, 16 October 2026

> Historical R01: superseded without publication by corrected R02 at the user's request. R01 canonical package/metadata files were moved intact to `launcher/build/MaintenanceToolkit-412-R02-20261016-093414/superseded-R01`; test-stage copies remain unchanged. The paths/hashes below describe the original R01 checkpoint, not current output bytes. See [final R02 verification](MT-4.1.2-RELEASE-VERIFICATION.md).

## Scope and frozen inputs

User authorized local candidate preparation, signing and VM MSI/ZIP tests only. No push, tag, release, stable-feed deployment or issue closure is authorized. Public stable remains 4.1.1. Its failed preflight is retained in [the separate report](MT-4.1.1-INSTALLATION-20261016.md).

Fix: ignore malformed unrelated uninstall locations on Windows PowerShell 5.1; malformed MT registrations remain fail-closed. Runtime/config identify this local candidate as 4.1.2 (candidate channel). The packaged legacy detection manifest still describes public 4.1.1. Local authenticated applying metadata uses sequence 6 and the existing stable contract; its official future URLs are not deployed. The harness substitutes local artifact transport only, retaining production catalog, signature, publisher, hash, MSI identity and installation verification.

Source baseline: `f6f7b7b8c7f3efedca0b467c6225fcbd18935dea` plus recorded local delta. Frozen source inventory/delta, build/signature logs and artifact inventory: `launcher/build/MaintenanceToolkit-412-Candidate-20261016-090238`. This is an uncommitted source snapshot, not a release tag. The unchanged native launcher is reused with its verified existing signature; new MSI and both new catalogs are signed/timestamped with SHA-256 using the approved Certum certificate. Canonical build procedures/output paths are unchanged. No dependencies acquired.

## Completed preparation checks

- 122 Windows PowerShell 5.1 regressions, including real MSI COM identity checks; temporary fixture removed.
- Foundation: zero errors, zero warnings.
- 81 packaged runtime files match source; no missing packaged documentation link targets.
- Final ZIP packaged SelfTest: exit 20, zero errors and one expected non-elevation warning. This is not elevated installation evidence.
- Production trust assertions and SignTool verification passed for launcher, MSI and catalogs, including timestamp and pinned publisher identity.

| Artifact | SHA-256 |
| --- | --- |
| `packaging/msi/out/MaintenanceToolkit-4_1_2.msi` | `24F489AED4F8CFCE594588E2E6D11539BF90E5FE7D551A9EE7A385A230E96260` |
| `dist/MaintenanceToolkit-4_1_2.zip` | `FC1F180F4D1C7F8747967073396A165E1FAF395C118D24AD757456F9230DBF73` |
| `dist/MaintenanceToolkit-4_1_2-payload.cat` | `300EDFCEB65BC6099699B75CAA1204057B58606A10A887F83291F83614D71962` |
| `dist/updates/4.1.2/update-v1.json` | `6FD2C1C17FE3CEA51725D787B9E05A539F3B8F2C073FC568ADBF858A0FDF0B2D` |
| `dist/updates/4.1.2/update-v1.cat` | `02B96583582E060F44B6B018E5469C30ED8F73A73DABCF46640BB3DEFB8D92D9` |

## VM gate — sequence and intermediate results

Authorized VM uses Windows 11 / Windows PowerShell 5.1 and the previously user-confirmed Hyper-V checkpoint. Windows 10 is not tested. Do not infer successful installation from preparation checks.

Sequence: snapshot original mutable data, protected consent, exception file and MT task XML; exercise signed-script tamper rejection and actual locked-file ZIP recovery; bootstrap public ZIP 4.0.6 to exact candidate; remove only known private MSI 4.0.9006, install exact candidate MSI in an absent protected test target, verify installed bytes/registration and elevated SelfTest, remove this fresh fixture; install original public MSI 4.0.6, restore original mutable data, upgrade using authenticated manual staging and the production application engine; verify preservation, single SelfTest resume, cleanup and unchanged boot time. Both 4.0.6 bootstraps are harness/manual paths: this version lacks updater helpers and cannot be represented as using its own updater UI/preparation. No maintenance modules are requested.

Initial stage passed actual signed ZIP tamper rejection, locked-file recovery/cleanup and 4.0.6 -> 4.1.2 ZIP application, real new-runtime SelfTest exit 0 and single-consumption/replay rejection, data and consent preservation. Four native MSI operations returned 0: known private pilot removal, fresh final MSI installation, fresh fixture removal, and public 4.0.6 baseline installation. Fresh final MSI installed bytes/registration verified and actual runtime SelfTest exited 0. The driver then failed in its Task Scheduler COM folder lookup (trailing separator caused an existing folder to be recreated). No runtime/package change was needed.

A second stage corrected only the harness folder lookup, verified original task XML/data/consent and unchanged boot, created and removed its on-demand temporary MSI task, then stopped before MSI application because the harness incorrectly called new-version preparation against a 4.0.6 tree without updater helpers. Its expected protected-helper check rejected the absent files (`MT41_ROOT_UNPROTECTED`). This is a test-driver/bootstrap error, not a new candidate fix. The third stage used explicit authenticated manual staging for the original 4.0.6 MSI bootstrap and passed. Intermediate failures are retained rather than relabelled as passes.

## Final local installation results

Completed at 09:12:59 Europe/Rome on 16 October 2026. Final installed MSI is **4.1.2 candidate**, at `C:\Program Files\Kraugh\Maintenance Toolkit`. Final installation matrix passed using the unchanged frozen artifacts above; no publication or issue closure occurred.

| Real VM test | Result |
| --- | --- |
| Fresh final MSI in an initially absent protected target | Native MSI 0; installed payload and registration verified; actual packaged SelfTest 0; fixture uninstalled with 0 |
| Public ZIP 4.0.6 -> 4.1.2 | Verified installed bytes; actual packaged SelfTest 0 |
| Public MSI 4.0.6 -> 4.1.2 | Native MSI 0; installed bytes/registration verified; actual packaged SelfTest 0 |
| Current public ZIP 4.1.1 -> 4.1.2 | Verified installed bytes; actual packaged SelfTest 0 |
| Current public MSI 4.1.1 -> 4.1.2 | Native MSI 0; one final registration/version verified; actual packaged SelfTest 0 |
| Final signed ZIP script modified in isolated staged copy | Catalog rejected it without execution; original bytes restored and revalidated |
| Real locked-file ZIP apply/recovery, both baselines | Maintenance blocked; previous installed bytes intact; recovery verified; recovered payload cleaned |
| Resume after successful application, both formats/baselines | Actual new runtime consumed SelfTest handoff once; replay rejected; payload/helper work removed |
| Preservation | Original settings/INI/logs/reports, protected consent bytes/ACL and InventoryShare preserved; canonical MSI task XML preserved; original standalone task XML/count unchanged |
| Cleanup and reboot | Every created on-demand MSI task removed; completed transaction work and ZIP sibling backup/next directories removed; boot unchanged since initial sequence |

The current-public-stable baseline test used the original 4.1.1 hashes recorded in the prior release evidence. Affected 4.1.1 cannot use its own updater on this malformed registry entry; its transition is explicitly a manual authenticated bootstrap. The final fourth stage removed only the known installed candidate to install original 4.1.1, restored the original mutable data, then applied the unchanged final 4.1.2 MSI. All three native MSI operations returned 0. The original unrelated registry entry was left unchanged.

Limits: Windows 11 / Windows PowerShell 5.1 only; no real Windows 10/GPO/domain/corporate SMB validation in this phase. The machine exception file was **absent before and after**: this does not prove preservation of the eight-entry corporate file from the historical user-reported pilot. No maintenance or selective Winget installation was executed. The resumed operation was SelfTest, not a real maintenance run. Controlled real MSI rollback remains evidence from the earlier private pilot, not a new final-MSI rollback test; current regression failure-path coverage and actual final-ZIP recovery are distinct. No 4.1.2 hosting deployment/download check was performed because publication is forbidden for this phase. A future release still needs its publication/documentation/hosting gates and a committed source revision corresponding to this recorded snapshot.

Machine-readable aggregate, original stage results and frozen artifacts are recorded in `launcher/build/MaintenanceToolkit-412-Candidate-20261016-090238/vm-acceptance.json`. Final artifact hashes, frozen tracked-source inventory and original 4.1.1 MSI/ZIP/metadata hashes were rechecked unchanged after the VM tests. Test evidence is outside the packaged runtime; packages have not been rebuilt/re-signed/repacked after passing.

## Repository documentation checkpoint after testing

The user subsequently authorized a local checkpoint of the correction, its tests/version and documentation. Roadmap, plan, README, changelog and paired IT/EN upgrade instructions now describe the verified results and limits. This documentation update does not rebuild or alter the tested MSI/ZIP/catalogs/metadata. Their embedded documentation still describes preparation-time status; the current repository report supplies the later results. A future decision to embed revised documentation would require new candidate artifacts and renewed VM validation. The frozen runtime/config/test files are compared to the recorded source inventory before checkpoint; documentation-only differences are listed separately. The checkpoint does not authorize push, publication or #28 closure.

### Retained evidence

- `launcher/build/current-412.json` and `launcher/build/current-412-install.json`: preparation/test pointers.
- `launcher/build/Invoke-412InstallationPilot.ps1`, `launcher/build/Start-412InstallationPilot.ps1`, `launcher/build/412-install-copy-manifest.json`: local driver/bootstrap and hash-pinned elevated-copy inventory.
- `launcher/build/Verify-412Release.ps1`, `launcher/build/FinalReleaseVerification-412`: package verification and extracted final candidate.
- `dist/staging/mt412-install-20261016-090238`: local authenticated inputs and driver copy.
- `C:\ProgramData\MaintenanceToolkit-412-InstallTest-20261016-090238`: protected elevated test stage, private before-state snapshot and result/log files. Do not publish private registry/config/task contents.
- `launcher/build/Invoke-412InstallationPilot-Initial.ps1`, `launcher/build/Invoke-412InstallationPilot-Resume1.ps1`, `launcher/build/412-install-initial.json`, `launcher/build/412-install-resume1.json`: preserved earlier harnesses and pointers.
- `dist/staging/mt412-install-20261016-090829-resume`, `C:\ProgramData\MaintenanceToolkit-412-InstallTest-20261016-090829-resume`: second-stage inputs/results.
- `dist/staging/mt412-install-20261016-090927-bootstrap`, `C:\ProgramData\MaintenanceToolkit-412-InstallTest-20261016-090927-bootstrap`: final manual-bootstrap inputs/results.
- `launcher/build/Invoke-412InstallationPilot-Bootstrap.ps1`, `launcher/build/412-install-bootstrap.json`: third-stage driver/pointer preserved before current-public-baseline verification.
- `dist/staging/mt412-install-20261016-091131-from411`, `C:\ProgramData\MaintenanceToolkit-412-InstallTest-20261016-091131-from411`: current-public 4.1.1 MSI/ZIP baseline inputs, isolated ZIP, private snapshot, logs and passing final result.
- Potential temporary task: `\Kraugh\Maintenance Toolkit - MSI Managed`, only if absent; on-demand, no triggers, never started, removed by driver finally. Existing task XML is captured/preserved instead of replacing foreign/GPO tasks.
- Runtime transaction GUID paths and actual created/removed tasks are recorded by the protected result/journals. Completed/recovered payloads are cleaned by verified runtime paths; evidence and isolated test installations remain until results are reviewed.

No manual cleanup requested. Retain frozen candidates, test drivers, isolated ZIP installations and private before-state snapshots as review/recovery evidence; the fresh MSI fixture is uninstalled and temporary tasks/transaction payloads have already been cleaned. A failed or incomplete VM gate blocks publication. Future publication requires the same frozen bytes and separate authorization; changing any candidate artifact invalidates its gate.
