# MT 4.1.1 — hosting User-Agent patch

15 October 2026. User explicitly authorized the 4.1.1 correction, real hosting verification, signed packages, conditional GitHub publication and a complete updated web ZIP. Published 4.1.0 assets must remain unchanged. Publication windows still apply. Scope is issue #28's transport compatibility, without changing trust, installation, GPO, consent or scheduling contracts.

## Correction and verified preparation

New-MTUpdateWebRequest adds `User-Agent: MaintenanceToolkit/4.1` on every request, including redirects. Product identity only; no host, domain, user or credentials. HTTPS/origin restrictions, size limits, signature/catalog/publisher/revocation and artifact-hash checks remain unchanged.

Using the corrected production factory/downloader under Windows PowerShell 5.1, all three API files downloaded from the actual hosting with matching bytes. Signed metadata authentication passed; GitHub MSI/ZIP/payload catalog downloads, hashes, MSI identity/signature and ZIP file-catalog checks passed. Hosting still advertises 4.1.0 during preparation; this verifies corrected transport against the deployed 4.1.0 feed, not deployment of the new 4.1.1 feed. No install or maintenance occurred.

118 regression checks (with the existing real MSI identity fixture) and Foundation zero errors/warnings passed before packaging. Final MSI identity, ZIP/source comparison, signatures/timestamps, catalogs and SelfTest are recorded with the final verification artifact. Existing Windows 10 waiver and private-pilot/corporate-SMB limits remain; no new environment claims.

The unchanged native launcher source/bin is reused with its existing valid Certum signature. New MSI uses canonical Build-MSI.ps1, new ZIP uses create-release.ps1 with UseExistingLauncher. No dependency acquisition. New signed catalogs/metadata use sequence 5, greater than 4.1.0 sequence 4, and 30-day validity; refresh requires an incremented sequence and explicit signing. 4.1.0 packages and dist/updates/4.1.0 remain immutable.

Affected 4.1.0 installations must manually install verified 4.1.1 MSI/ZIP because their old downloader can fail before retrieving this correction. Preserve settings, exceptions, InventoryShare, logs/reports and task ownership. GPO deployment remains organization-owned. No reboot is automatic.

## Inputs, outputs and temporary evidence

- Prior hosting content/signature inspection: [4.1.0 deployment report](MT-4.1-HOSTING-VERIFICATION.md). The user-uploaded full software tree remains the website base; all eighteen changed HTML pages and three API files were byte-verified against it after upload.
- Preparation root: `launcher/build/MaintenanceToolkit-411-Preparation-20261015-205219`; includes old-release asset/hash snapshots, regression/Foundation logs and hosting-result.json. Hosting download fixture is its `hosting` subdirectory, retained as evidence.
- Generator `launcher/build/Test-411Hosting.ps1`; pointer `launcher/build/current-411.json`. Regression-created temporary fixtures report their exact names/removal in the retained logs. No new tasks.
- Final MSI: `packaging/msi/out/MaintenanceToolkit-4_1_1.msi`; ZIP/catalog/checksums: `dist/MaintenanceToolkit-4_1_1*`; authenticated metadata: `dist/updates/4.1.1`. Web bundle remains a unique project/version/Rome-time ZIP in dist, containing complete software/ and api/maintenance-toolkit/.

GitHub assets are verified after upload before the draft is made public, then checked again through their public URLs. The 4.1.1 website/API upload remains with the user; do not claim deployed feed verification until that upload occurs. Keep proof of existing 4.1.0 local and remote hashes unchanged.

## Final pre-publication results

- MSI and both new catalogs signed/timestamped with the expected Certum certificate B5228D5E9A1CB84C10838146C10CA6C490C1A571; SignTool and Get-AuthenticodeSignature valid with timestamps, production publisher/trust assertions passed. Initial signing attempt failed while SimplySign was disconnected; after explicit user reactivation, all three new signatures succeeded. No credentials requested or recorded.
- Final real MSI identity regression: 118 passed. All 81 runtime/configuration/resource source files byte-match the extracted final ZIP; no missing package documentation targets. SelfTest exit 20: zero errors and one expected non-elevation warning.
- The updater loaded from the exact extracted signed 4.1.1 ZIP independently downloaded all three API files from actual hosting and authenticated the catalog/manifest. No curl or factory mock in this final transport test. Hosting still serves 4.1.0 sequence 4 until the user's next upload.
- MSI SHA-256 ADDD2A615336B3722B4426DBDAE802C597E1AE8C33159A90CAA40ACFA86F0CC9; ZIP SHA-256 86F12D9CEF59036A3A9C7EF5448DBBFBF03E5F26CEB40B9AD27449C8A9E791E8.
- All eight existing 4.1.0 GitHub asset digests/sizes and five local package/catalog/metadata hashes unchanged before publication. No asset overwrite, replacement or deletion.
- Complete web ZIP: `dist/MaintenanceToolkit-4.1.1-Web-20261015-211305-web.zip`, SHA-256 3270EA17CC4C2499B400301D9A382CAFC8AFFBE1063FA1AD649AC065C3E77770. Eighteen MT/overview pages updated, other projects unchanged, zero missing relative HTML targets, all 83 ZIP files checked against staging. API files match final signed originals. New metadata sequence 5 expires 14 November 2026 at 19:12:35 UTC (20:12:35 Rome).

Retained final evidence/generators: `launcher/build/FinalReleaseVerification-411`, `launcher/build/Verify-411Release.ps1`, `launcher/build/Test-411PackagedHosting.ps1`, preparation-root `packaged-hosting` and `packaged-hosting-result.json`, `launcher/build/Prepare-411Website.ps1`, `launcher/build/current-411-web.json`, and `dist/staging/MaintenanceToolkit-4.1.1-Web-20261015-211305`. Keep for review; metadata builder's disposable extraction stages and regression fixtures cleaned by their canonical scripts. No new install, task or reboot during this patch phase. No new browser rendering test is claimed; the validated 4.1.0 website layout/CSS is retained with changed text/links/hashes.
