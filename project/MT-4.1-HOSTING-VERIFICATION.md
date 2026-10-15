# MT 4.1.0 — hosting verification after user upload

15 October 2026, Europe/Rome. User reported the website bundle uploaded. No hosting changes, runtime changes, install, task, commit or publication performed during this verification.

## Verified

- All three API files and eighteen HTML pages are byte-identical to the delivered final bundle. Production signature/catalog/manifest assertions passed on downloaded metadata. Version 4.1.0, sequence 4, expiry 14 November 2026 at 18:18:19 UTC.
- MSI, ZIP and payload catalog URLs from the hosted authenticated manifest were downloaded and their sizes/hashes verified. The Italian public landing page was also inspected in the browser and shows 4.1.0 links and final hashes.
- These hosting-content checks used curl's normal User-Agent after the production request failed. They must not be reported as successful unmodified production updater transport.

## Deployment incompatibility found

The unmodified MT 4.1.0 production downloader receives HTTP 403 from the hosting endpoint because New-MTUpdateWebRequest creates an HttpWebRequest with no User-Agent. Reproduced with Windows PowerShell 5.1 and independently with curl's empty User-Agent. Requests identifying the product as MaintenanceToolkit/4.1.0 return HTTP 200 through both clients. This is an observed server/client compatibility difference, not evidence of bad uploaded files or invalid signatures.

The existing published MSI/ZIP bytes remain immutable. Do not silently replace 4.1.0 packages/catalogs. A client correction should be a subsequent identified distribution (e.g. 4.1.1), adding a non-sensitive product User-Agent, exercising the actual hosting transport and rerunning trust/regression/package checks. Alternatively the hosting owner can explicitly permit the current requests, if appropriate to its configuration; no security-setting change was attempted. Until resolved, automatic application cannot be claimed operational against this hosting. Preparation failures remain fail-safe; no installation was attempted.

## Retained files

- `launcher/build/Verify-HostedRelease.ps1`: content-inspection script; explicitly records the curl transport distinction.
- `launcher/build/MaintenanceToolkit-HostingVerification-20261015-204641`: initial production request fixture; HTTP 403 before any file verification.
- `launcher/build/MaintenanceToolkit-HostingVerification-20261015-204754`: downloaded API files, eighteen pages, GitHub artifacts and verification.json, retained as diagnostic evidence.

No new dependencies or tasks. At the end of this inspection the report was local/uncommitted and public release/metadata unchanged. The user subsequently authorized the [4.1.1 correction](MT-4.1.1-RELEASE-VERIFICATION.md); this dated inspection is preserved as the defect evidence.
