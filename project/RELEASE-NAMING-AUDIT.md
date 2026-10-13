# 4.0.6 filename and reference audit

All available repository filenames were reviewed. Four runnable test files now use stable project names. Active references in documentation and JSON manifests were updated. The discarded 4.0.5 R01 test is retired. Historical checkpoint documents keep their filenames and are not included in public packages.

Both canonical build scripts reject dated/revision test filenames in app/tools before packaging. Output locations remain packaging/msi/out and dist. ZIP documentation now includes docs/examples because the exception guides refer to that template.

The Repair-MTTestNames.ps1 tool verifies canonical copies before moving obsolete files into launcher/build inside the project. It does not change the signed launcher, MSI or ZIP. Existing 4.0.6 packages still contain previous filenames: archive and regenerate MSI/ZIP, then sign the new MSI. Windows tests and final package-name checks must be repeated after applying this ZIP.

No company exception file, hostname or downloaded payload is shipped. winget-exception.example.json is an intentionally named documentation template, not the active policy. The canonical policy path remains unchanged.
