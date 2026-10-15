# MT 4.1 local development and test guide

Sources identify as 4.1.0-dev.3, not a released version. Stable manifest and public 4.0.6 packages are unchanged. No new signed binaries are provided by this increment. Do not run the full maintenance suite merely to test scheduling or updating.

## Menu and scheduling

G configures explicit standalone ownership and protected opt-in. Machine policy overrides local preferences and packaged JSON defaults. Unknown ownership detects updates only; domain membership does not determine ownership. P offers maintenance (recommended: all configured enabled modules), analysis (Connectivity, Inventory, NetworkReport, DiskHealth, NVIDIA advisory), or update detection only. It accepts daily/multiple times, selected weekdays or computer startup. Creation requires elevation, a protected local installation, a preview and confirmation. Existing tasks targeting a different installation and GPO tasks are not overwritten. Task triggers use the computer's local timezone. Missed runs use StartWhenAvailable; overlap uses IgnoreNew; execution limit is four hours. Specific calendar dates are not supported in this increment.

The optional JSON destination must be an absolute local path or UNC, outside the runtime. A mapped user drive is not a reliable SYSTEM destination. SYSTEM needs its own access, typically the computer account on a domain share. All JSON produced within the session, including maintenance-summary.json, is copied through temporary files and rename; local reports remain intact on publication failure. Update-only sessions produce update-check.json and never install, even with opt-in enabled.

Protected local preferences and transactions live under `%ProgramData%\Kraugh\MaintenanceToolkit\self-update\<installation-id>`; they are not MSI-owned. Packaged `config/settings.json` may contain `SelfUpdate.Management` (unknown/standalone/gpo) and boolean `AutomaticInstallEnabled`. Machine policy uses `HKLM\Software\Policies\Kraugh\Maintenance Toolkit\SelfUpdate`, Management REG_SZ and AutomaticInstallEnabled DWORD 0/1. A present policy is complete; missing values default to unknown/false without inheriting consent. Invalid, unreadable or contradictory policy blocks installation. Local opt-in needs protected ACLs. The UI never modifies policy.

## Update workflow

V requires confirmation before downloading and again before application. Opt-in automatic updates run before scheduled maintenance/analysis, with no permanent updater task. All mutation is coordinated with a global installation lock. The helper waits for runtime/launcher exit. Failed preparation yields WARN and permits current maintenance; uncertain application state blocks it. A verified update resumes once through a protected consumed handoff and skips updating on that resumed run. No automatic reboot. Old releases without the lock require a controlled first upgrade.

The new endpoint proposed for application is update-v1.json plus signed update-v1.cat; current version.json remains the detection endpoint. The manifest catalog authenticates exact JSON bytes; SHA-256, signature, timestamp, pinned certificate and online revocation verification precede execution. ZIP requires its external signed payload catalog covering all scripts and resources, rejects unsafe paths, preserves settings/INI and logs/reports, and restores the previous directory if postverification fails. Config/version.json comes from the new payload. MSI requires matching product/version/UpgradeCode/x64 and an embedded signature; it uses Windows Installer with CREATE_TASK=0 and restart suppression, retains InventoryShare, backs up mutable data and restores only the MSI-owned task for this installation. GPO tasks and ProgramData exceptions are not modified. MSI errors/restart-pending require recovery review; no blind downgrade or automatic maintenance continuation.

Consent survives upgrades; custom executable modules or altered languages/themes/rules are not silently merged into the authenticated payload. The old ZIP directory is available during rollback; successful cleanup removes it. Failure keeps transaction evidence and mutable backup for administrator review. Fresh maintenance is blocked by incomplete transactions; a consumed resume cannot be replayed. If a crash occurs before the handoff starts, inspect the protected transaction; exactly-once means no duplicate maintenance, not guaranteed execution after every crash.

U and R are removed from the user menu. V checks availability first and offers installation only for explicitly standalone management. Recovery remains an internal transaction safeguard, never a menu choice. An uncertain installation requires a verified reinstall and administrator verification of the protected transaction state before maintenance; reinstalling files alone does not blindly clear an incomplete transaction.

H (Languages) selects English, Italian, French, Spanish, German, Simplified Chinese or Japanese and saves settings.json. Unsupported system languages and missing translations use English. New resources translate the main menu and 4.1 workflows; historical diagnostics are not yet fully translated. Swedish is retained for compatibility outside the seven-language menu.

## Safe tests and remaining live gate

Run Windows PowerShell 5.1 `-NoProfile -ExecutionPolicy Bypass -File app/tools/Test-MT41.ps1` from the repository. Bypass is process-local, not a machine execution-policy change. Tests create uniquely named fictitious files under launcher/build and clean them; task, signature/application and MSI process boundaries are mocked where indicated. They do not install MSI or create tasks. Real catalog signing was a separate authorized test; no new packages are signed here.

Before pilot use: compile and sign a distinct development candidate without replacing published artifacts; validate the new launcher argument quoting, task creation under SYSTEM, share failure, MSI rollback/custom actions, opt-in preservation, exception hashes, task XML and resume failures. Preparing release catalogs extends existing dist outputs through tools/New-MTUpdateMetadata.ps1: PayloadCatalog mode creates an unsigned v2 catalog; after explicit signing, Metadata mode verifies signed packages/catalog and creates versioned JSON plus an unsigned metadata catalog under dist/updates. It never signs or publishes. The development version cannot be built as a public MSI; numeric version finalization is a separate release step.

## Signed local candidate — R02

Local signing and verification are complete; earlier requests to compile/sign describe the previous checkpoint. Runtime 4.1.0-dev.3 uses private MSI ProductVersion 4.0.9003 and is not a stable release.

Artifacts: `dist/MaintenanceToolkit-LocalSigned-20261014-150201-e963186c-R02`. See [local validation](../../project/MT-4.1-LOCAL-VALIDATION.md). 72 isolated tests passed; real install/upgrade and unattended SYSTEM/UNC validation remain pending. New documentation edits are not retroactively included in these signed packages. See the [issue review](../../project/ISSUE-REVIEW-20261014.md).

## 15 October increment — next candidate required

P now provides create/update, inspection with last/next run and result, and confirmed removal. Choose missed-run recovery (default on), battery execution (default off), and required network availability (default off). Network availability does not establish UNC share authorization. Operations are recorded in protected schedule-events.jsonl; GPO tasks remain untouched.

112 isolated checks passed; scheduled resume host arguments and consumed-payload cleanup corrected. These changes are not included in R02 packages. The [VM pilot](../../project/MT-4.1-PILOT.md) remains pending; simulated tests do not prove real upgrade or SYSTEM execution.

## Private candidate R04 — 4.0.9006

117 checks passed. Real MSI, locked-file ZIP recovery/replacement, helper with one diagnostic-only resume, SYSTEM task and JSON publication through a local UNC path passed. An unavailable share returned WARN while retaining local data. A real HTTPS transfer was aborted and its partial file removed. ZIP transitions now use atomic Directory.Move because Move-Item could partially relocate a directory.

R04 is the current verified candidate; R02/R03 are historical. MSI remains installed on the VM at 4.0.9006, with no restart or maintenance execution. The MSI-busy experiment did not reproduce rejection; MSI rollback/interruption and corporate-share identity testing remain separate gates. See [full evidence](../../project/MT-4.1-VM-PILOT-20261015.md). No publication or stable-manifest change.

## Final MSI result and first 4.1 bootstrap

Controlled MSI rollback after InstallFiles passed: native 1603, previous version/application hashes/product registration restored, configuration and task preserved. No restart or maintenance. Usable candidate remains R04/4.0.9006; 4.0.9007 is an intentionally failing fixture, never an installable/distributable candidate.

Stable 4.0.6 has no applying updater: the first public move to 4.1 will be a documented manual bootstrap, not retroactive automatic updating. Before upgrading, back up settings.json, MaintenanceToolkit.ini, logs/reports, ProgramData preferences/exceptions and task XML, preserving ownership/ACLs. After installation restore only necessary local settings and verify them; never restore the old config/version.json over the new version. GPO installations follow organizational deployment and preserve GPO-owned tasks; do not declare them standalone. Do not start maintenance until version, configuration and ownership are verified. Public packages/version/feed will be finalized in a separately authorized phase.

Current real pilot: Windows 11 Pro build 26200 / Windows PowerShell 5.1. It does not prove 4.1 upgrade on Windows 10 or access to a corporate share. See [evidence and limits](../../project/MT-4.1-VM-PILOT-20261015.md).

[Upgrade and first 4.1 bootstrap](UPGRADING-MT.md). Windows 10 test explicitly waived; no validation claim.
