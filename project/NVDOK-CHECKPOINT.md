# 4.0.4-dev.7-NVDOK — working-tree checkpoint

Public/downloadable stable version remains 4.0.3. No release/tag/MSI/EXE build,
no public manifest update, no GitHub release asset for this checkpoint.

Copy this ZIP directory tree over the development working tree. Keep logs:
old driver packages and FNV diagnostics are not modified by the NVIDIA module.
Run app/tools/Publish-MTNvdokWorkingTree.ps1 from elevated Windows PowerShell
on KRAUGHHQ to validate, create/reuse the NVIDIA issue, commit and push main.
The script refuses an unexpected remote/branch, unrelated staged files,
remote changes not integrated locally and failing validation. No force push.
It stages only the source paths listed in project/NVDOK-FILES.json; protected
public-distribution paths are excluded. The issue body is in NVIDIA-ISSUE.md.
Remote publication is complete only after the script reports a matching
local and origin/main commit hash. This ZIP itself is not evidence of a push.

Tomorrow: pull main on KraughDev, confirm config/version.json is
4.0.4-dev.7-NVDOK, continue Dell stabilization under #29 and use -Only NVIDIA
for engineering workstations. Do not use RunAll when the intended task is
read-only NVIDIA analysis: other maintenance modules can change the system.

Validation performed in the preparation environment (PowerShell 7.6.6/Linux):
- All PowerShell source files parse.
- Real NVIDIA fixture candidate and Windows-version conversions pass.
- Nine unsafe-candidate rejection cases pass.
- Desktop/mobile mapping, ambiguity and qualifier preservation pass.
- Advisory-only source contracts pass.
- Six mocked runtime scenarios pass, no driver download/install/reboot.
- MT4 Legacy Compatibility passes.
Windows PowerShell 5.1 / Foundation autotest / live NVDOK scan run on KRAUGHHQ
as publication prerequisites. Additional real GPU models remain unvalidated.
