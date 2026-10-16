# MT 4.1.0 — release verification

Historical evidence: 4.1.0 was withdrawn to a non-public draft after 4.1.1 deployment; original assets/tag preserved. Public 4.1.0 release URLs below are historical, not current downloads. See [current issue/withdrawal review](ISSUE-REVIEW-20261015.md).

**Published:** [GitHub v4.1.0](https://github.com/Kraugh/maintenance-toolkit/releases/tag/v4.1.0), 15 October 2026 at 20:21:49 Europe/Rome, outside prohibited windows. Release/tag commit: 3b8d8e419c8fc7abd0aea3501057141e641acf01. Eight uploaded assets were downloaded from the draft and byte-matched before publication. After publication the production downloader fetched public metadata/catalog, MSI, ZIP and payload catalog; all production trust/hash/MSI-identity/ZIP-membership assertions passed. Website upload remains pending with the user. No issues closed by this publication.

Release date: 15 October 2026. The user authorized final packages, signing, final verification and GitHub publication only if checks pass. Website deployment remains manual by the user after GitHub assets are available. Check the Rome publication window immediately before remote mutations.

## Scope and evidence

Runtime/configuration finalized to 4.1.0 stable from 4.1.0-dev.3. Build paths remain canonical. Build-MSI now requires the already installed pinned WiX/Util 5.0.2 and refuses implicit dependency acquisition; no dependency installed. Launcher rebuilt by launcher/build-launcher.cmd, signed with Certum SHA-256/RFC 3161 and verified by SignTool. MSI uses Build-MSI.ps1, ZIP uses create-release.ps1 with the signed launcher.

The final verification output is retained separately under launcher/build and dist. Do not confuse a successful private pilot with an installation test of the final public bytes. The existing [private pilot report](MT-4.1-VM-PILOT-20261015.md) documents real MSI/ZIP application, locked-file recovery, controlled MSI rollback, helper/one-time resume, SYSTEM/loopback UNC and download interruption. The regression suite passed 117 checks again before finalization. Windows 10 real testing was explicitly waived. No corporate SMB or live selective Winget installation guarantee is made.

## Distribution contract

- GitHub: immutable MaintenanceToolkit-4_1_0.msi, .zip, distinct -msi.sha256/-zip.sha256 and signed -payload.cat. The ZIP catalog authenticates all packaged scripts/resources; the MSI has its embedded signature and product identity checks.
- Website: full software/ tree plus api/maintenance-toolkit/version.json, update-v1.json and update-v1.cat in a single project/date/time web archive. Only IT/EN public pages; seven UI choices with five partial translations/English fallback. Existing tutorial images remain labelled historical.
- version.json detects availability. update-v1.json is the authenticated application contract, signed by the detached update-v1.cat. Sequence 4 supersedes private sequence 3; validity 30 days. Expiry prevents installation until the maintainer explicitly refreshes publishedAt/expiresAt, increments sequence and re-signs/verifies the catalog. Never alter immutable package bytes to refresh metadata. Publish the paired JSON/catalog together, then verify both with production trust checks; mismatch/expiry fails closed. Detection and maintenance remain available according to the preparation-failure WARN contract.
- First 4.0.6 upgrade is manual. GPO/unknown installations never install through MT. Protected opt-in defaults off and no additional permanent updater task is created. No automatic reboot.

## Publication order

Verify/freeze source commit and signed assets first. Publish GitHub assets, verify remote release references/size/hash, then hand the complete website archive to the user. The website is not considered deployed until the user uploads it and the endpoints are checked. Issues requiring live-feed/enterprise evidence remain open.

## Retained working files

Canonical final packages: packaging/msi/out/MaintenanceToolkit-4_1_0.msi and dist/MaintenanceToolkit-4_1_0*. Final metadata: dist/updates/4.1.0. Validation/extraction staging remains under launcher/build or dist/staging and is recorded in the final machine-readable verification report. No test task or maintenance execution is required for package finalization.

## Final results before publication

- 117 regression checks against final MSI identity passed; Foundation passed with zero errors/warnings. Earlier Foundation failure exposed missing UTF-8 BOM in six new scripts and an outdated complete-translation assumption. BOM restored; language validation now requires all 4.1 keys, rejects unknown keys, and verifies that the complete runtime key set and every missing historical value resolve correctly through English fallback. No complete-translation claim added.
- Canonical launcher, final MSI and both catalogs verified by SignTool and Get-AuthenticodeSignature: valid, expected B5228D5E9A1CB84C10838146C10CA6C490C1A571 signer and timestamp. Production trust assertions verify pinned certificate identity, catalog membership, MSI identity, metadata sequence/expiry, sizes and hashes.
- Final ZIP extracted to launcher/build/FinalReleaseVerification-Final: all 81 runtime/config/language/rules/theme/local-manifest source files byte-matched. Zero missing local documentation targets; packaging routes references to excluded repository-only material to version-tagged GitHub sources. Final SelfTest: exit 20, zero errors, one expected non-elevation warning. No maintenance was executed.
- Final MSI SHA-256: C71846E036669903C24331A3F94CC1AA8B7611D58664DBA2C80CA98A639C1E96.
- Final ZIP SHA-256: F5A6B225254CC443CB1ABFF93282D5C5DD2E3E0FC8E656DED65696C190C2C25E.
- Final web archive: dist/MaintenanceToolkit-4.1.0-Web-20261015-201858-web.zip, SHA-256 9ABD063351B9E9086A5DA00C9FCD9872284706B86B9024974B6A68A83872B088. Complete software/ and api/maintenance-toolkit/; other projects unchanged, zero missing relative HTML targets. Earlier review archive ZIP contents matched staging; final archive/API bytes are checked again before delivery. Metadata sequence 4 expires 14 November 2026, 18:18:19 UTC (19:18:19 Rome).
- Browser preview was rejected by the browser security policy because file: is not allowed. No bypass/local-server workaround attempted. Website review is static; final visual rendering is not claimed. Historical screenshots remain labelled as such.

Retained generators: launcher/build/Verify-FinalRelease.ps1 and Prepare-FinalWebsite.ps1; pointer current-final-web.json. Initial extraction launcher/build/ReleaseVerification and launcher/build/FinalReleaseVerification remain diagnostic evidence. Superseded unsigned/finalization outputs were moved within the repository into dist/staging/MaintenanceToolkit-Prefinal-20261015-201600 and MaintenanceToolkit-Prefinal-20261015-201800; no public bytes overwritten. Superseded web archive/staging MaintenanceToolkit-4.1.0-Web-20261015-201618 retained, use only the 201858 bundle. Existing cleanup policy rejections remain documented; no bypass or new task.

Post-upload retained evidence: dist/staging/MaintenanceToolkit-RemoteVerification-20261015-202100 (eight downloaded draft assets), dist/staging/MaintenanceToolkit-PublicVerification-20261015-202200 (public transport/trust verification and extracted payload), launcher/build/Verify-PublicRelease.ps1 and launcher/build/published-release.json. These are review evidence; no scripts from downloaded packages were executed for this transport check. No maintenance, task creation, installation or reboot during finalization. The VM remains on its previously installed private pilot until explicitly upgraded.
