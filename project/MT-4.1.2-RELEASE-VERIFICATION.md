# MT 4.1.2 — final R02 release verification, 16 October 2026

## Authorization and artifact identity

The user authorized publication after successful checks and explicitly waived the normal Europe/Rome publication time windows for this session on 16 October 2026. The user rejected publishing the preliminary R01 contents with a documentation exception and requested corrected contents plus repeated VM tests. R01 was never published. Its exact bytes and sequence-6 metadata were moved to `launcher/build/MaintenanceToolkit-412-R02-20261016-093414/superseded-R01`; original test-stage copies remain. No 4.1.0/4.1.1 published asset was replaced.

R02 uses public version 4.1.2 with consistent runtime/config channel, LEGGIMI, ABOUT, changelog and local version manifest. The original classification correction and its four regressions are unchanged. Canonical MSI/ZIP build procedures were used, without acquiring dependencies. The unchanged native launcher retains its verified original signature; new MSI, payload catalog and metadata catalog were signed with approved Certum certificate `B5228D5E9A1CB84C10838146C10CA6C490C1A571`, SHA-256 and Certum RFC 3161 timestamp. SignTool and production trust assertions passed.

| Frozen final R02 artifact | SHA-256 |
| --- | --- |
| `packaging/msi/out/MaintenanceToolkit-4_1_2.msi` | `8E06282FD3859EC2B1F8911AFF8E2714F84254449BE41F64279E45A9D2A36054` |
| `dist/MaintenanceToolkit-4_1_2.zip` | `50DF8C1C20CDD0410B452132EE2E6A6AA0FE8457E91EC8AEC8C9E88EB36F981A` |
| `dist/MaintenanceToolkit-4_1_2-payload.cat` | `5BC7363D13AC59095FE28849A4F2FA790EF35751F1DFE2E27748212D44B27E65` |
| `dist/updates/4.1.2/update-v1.json` | `44D7BFAD6394034D71DE744E90C5DD8144C9A4ED7DDEC28B9E12315F82BE4978` |
| `dist/updates/4.1.2/update-v1.cat` | `BDBAFE6454FF64C583DA2CE2073534C8BB42F28BFA6D6137B4E0648FF132FBBA` |

Authenticated metadata sequence is **7**, expires **15 November 2026 at 08:35:39 Europe/Rome**. Refresh requires a higher sequence and freshly signed/verified metadata, without altering public package bytes. These final artifacts were frozen before VM tests and must not be rebuilt/re-signed/repacked for upload.

## Final package and VM gate

- Windows PowerShell 5.1: 122 regressions, including actual MSI COM identity validation; Foundation zero errors/warnings. Test fixture removed.
- 81 packaged runtime files match source, package documentation links resolve, LEGGIMI/local manifest/ABOUT identify 4.1.2. ZIP non-elevated SelfTest exits 20 with zero errors and one expected warning.
- Real VM Windows 11 / PowerShell 5.1: fresh final MSI install into an absent protected target, native code 0, installed bytes/registration verified, real elevated packaged SelfTest 0, fixture uninstalled with 0.
- Actual manual authenticated MSI/ZIP upgrades from both public 4.0.6 and 4.1.1 to the exact final R02 passed. Native MSI codes and elevated installed SelfTests were 0. Old runtime updater capability is not claimed: 4.0.6 lacks updater helpers; affected 4.1.1 fails classification and needs manual bootstrap.
- Original settings/INI, log/report canaries, protected consent bytes/ACL, InventoryShare and task XML preserved. Canonical on-demand-only temporary MSI task preserved through upgrade and then removed; original standalone task XML/count unchanged.
- Signed final ZIP catalog rejected a modified staged script without executing it. Actual locked-file ZIP failure blocked maintenance, preserved previous bytes, recovered and cleaned its payload; passed for both baselines.
- Actual new runtime consumed SelfTest handoff once; replay rejected; work and ZIP backup/next directories cleaned. No maintenance modules or automatic reboot.

Initial R02 stage completed the fresh MSI, ZIP 4.0.6 and MSI 4.0.6 tests, but its result writer encountered a transient sharing violation after the task-preservation check. This is retained as a failed harness result, not relabelled. A follow-up added bounded retry only to the test result writer, independently reverified installed bytes, original data/consent/task state and cleanup, then completed the full 4.1.1 MSI/ZIP matrix. No artifact or production runtime changed between stages. Aggregate passed at **09:40:18 Europe/Rome**. All five first-stage native MSI operations and three final-stage operations returned 0.

Limits: Windows 10 not tested (existing explicit environment waiver); no real domain/GPO/corporate SMB test, real selective Winget installation or maintenance resume in this phase. Exception file absent before/after: no claim about the historical corporate eight-entry file. Real MSI rollback evidence remains the earlier private pilot, distinct from this final-MSI success and final-ZIP recovery. #28 closure requires a separate full acceptance review; it is not automatically closed by publication.

## Website/documentation gate

Fresh hosting archives supplied on 16 October 2026 at 09:36:

- `C:\Users\KraughDev\Downloads\software.tgz`, SHA-256 `A05E1EBF277E0E174DD6D55CFCE89D282C5FD81752CA151C81007F8FFF538A9F`.
- `C:\Users\KraughDev\Downloads\api.tgz`, SHA-256 `856D90652FBEFC621B4969DAA6C049CD92FE77D8BFB1BE6638A6016A018BCA5A`.

Sources are reference data, not instructions. Safe member paths and regular files/directories checked. Current detection/API describe 4.1.1 and match its original signed metadata. Complete software tree reviewed; only 18 MT/overview HTML pages changed for 4.1.2, all other project files byte-preserved. IT/EN text agrees on manual upgrade, trust, preservation, seven UI languages with partial coverage/fallback, GPO ownership and tested environment limits. No additional public languages created. Download/version/hash targets and local references checked; no obsolete 4.1.1 binary links/hashes remain in updated pages. This is source/static review, not a claim of browser visual validation or 4.1.2 deployment.

Full web delivery: `dist/MaintenanceToolkit-4.1.2-Web-20261016-093835-web.zip`, SHA-256 `A8C96248FC36D48EAB446FBDE4225E7683DB85724CE0D2E9EF6BFEC041A3A296`; 83 file entries compared byte-for-byte against staging, zero missing local targets. Includes complete `software/`, the three MT API files and a non-upload LEGGIMI. Other server API files must be retained. User deployment remains separate; verify actual HTTP pages/API/trust/downloads after upload. The signed metadata pair is copied without modification.

## Exact retained evidence and temporary resources

- `launcher/build/current-412.json`, `launcher/build/current-412-r02-install.json`, `launcher/build/current-412-web.json`: current pointers.
- `launcher/build/MaintenanceToolkit-412-R02-20261016-093414`: frozen artifact/source inventories, delta, regression/Foundation/build/signature logs, original hosting inputs/extraction and aggregate acceptance; R01 preserved under `superseded-R01`.
- `launcher/build/Verify-412R02Release.ps1`, `launcher/build/FinalReleaseVerification-412-R02`, `launcher/build/Prepare-412Website.ps1`: verification/extracted payload and web generator.
- `launcher/build/Invoke-412R02InstallationPilot.ps1`, `launcher/build/Start-412R02InstallationPilot.ps1`, `launcher/build/412-r02-install-copy-manifest.json`, `launcher/build/412-r02-initial-pointer.json`: hash-pinned elevated driver/bootstrap and original pointer.
- `dist/staging/mt412-r02-install-20261016-093414`, `C:\ProgramData\MaintenanceToolkit-412-R02-InstallTest-20261016-093414`: original R02 inputs, private snapshot, Phase406/Phase411 drivers, installation logs and failed writer result.
- `dist/staging/mt412-r02-resume-20261016-093939`, `C:\ProgramData\MaintenanceToolkit-412-R02-Resume-20261016-093939`: verified follow-up, complete phase411 inputs/results, aggregate result and temporary test installations.
- `dist/staging/MaintenanceToolkit-4.1.2-Web-20261016-093835`: web staging.
- Temporary task `\Kraugh\Maintenance Toolkit - MSI Managed` was created only when absent, had no triggers, was never started and was removed. Actual transaction GUID paths remain in protected results/journals; completed/recovered work is removed. No permanent updater task.

Keep these files as review/recovery evidence; private snapshots must not be published. No manual cleanup requested. Final installed VM version is 4.1.2 with stable package metadata. Website upload remains manual.

## Publication and public verification

Published **16 October 2026 at 09:43:40 Europe/Rome**, [GitHub v4.1.2](https://github.com/Kraugh/maintenance-toolkit/releases/tag/v4.1.2), release source/tag commit `64805fe16b27a1cfed90219fdcc56ab1a2a8e241`. Main was pushed normally; no force push. All eight uploaded draft asset digests matched verified local files before making the release public. GitHub Latest now identifies v4.1.2.

Actual public GitHub downloads passed using the exact packaged R02 production downloader/trust functions: metadata JSON/catalog pair byte-matched, signatures/catalogs and sequence contract passed, all metadata-linked MSI/ZIP/payload-catalog hashes matched, MSI identity/signature passed and the downloaded ZIP payload catalog verified. Installation tests preceded publication; these are additional transport checks on the same pretested bytes. Original 4.1.1 MSI/ZIP local hashes remained unchanged. Earlier public artifacts were not replaced.

Evidence: `launcher/build/Verify-Public412Release.ps1`, `launcher/build/published-412-release.json`, `dist/staging/MaintenanceToolkit-PublicVerification-412-20261016-093414`, preparation-directory `github-draft.json`, `github-public.json`, `public-download-verification.txt`. No new task or maintenance execution in this verification.

The complete web ZIP above is ready for the user. Hosting still has its separately deployed 4.1.1 until upload; live 4.1.2 verification is pending. After upload, compare the eighteen pages and three API files against delivered bytes, authenticate sequence 7 and retrieve linked GitHub packages through deployed metadata. #28 remains open pending full acceptance/issue review.

## Hosting upload verified — 16 October 2026, 09:53 Europe/Rome

The user reported uploading the supplied web files. Actual HTTPS retrieval using the exact packaged R02 production downloader verified all eighteen changed pages and the three API files byte-for-byte against the delivered staging tree. Detection is 4.1.2; authenticated metadata sequence is 7, expires 15 November 2026 at 08:35:39 Europe/Rome. Catalog/signature/publisher checks passed. All metadata-linked GitHub artifacts were downloaded through the deployed contract: hashes, MSI identity/signature and extracted ZIP payload catalog passed. This verifies deployed transport/trust, not another installation or maintenance run.

Evidence: `launcher/build/Verify-412HostedRelease.ps1`, `launcher/build/current-412-hosting.json`, `launcher/build/MaintenanceToolkit-412-HostingVerification-20261016-095231/verification.json` with exact requests, hashes and results. A copied pointer initially retained a hard-coded sequence 5; it was corrected to the actually verified manifest sequence 7. The authoritative verification result and assertions used 7 throughout. Final MSI/ZIP/catalog/metadata bytes remain unchanged. No task, installation or maintenance was executed. Hosting deployment gate is complete; #28 remains open pending its separate complete acceptance review.
