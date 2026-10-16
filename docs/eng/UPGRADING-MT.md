# Upgrading MT — 4.1

Instructions for MT 4.1.2 packages. Check GitHub Releases for public availability. The first upgrade from 4.0.6 requires manual installation with verified official packages. Private-version pilot evidence is documented separately.

## Historical private 4.1.2 R01 validation

On 16 October 2026, the final signed local 4.1.2 MSI/ZIP passed manual authenticated upgrades from public 4.0.6 and 4.1.1 on Windows 11 / Windows PowerShell 5.1, plus a fresh MSI installation. Native MSI and elevated installed SelfTest returned 0. Settings, logs/reports, protected consent, InventoryShare and task XML were preserved; locked-file ZIP recovery and modified-script rejection passed. No maintenance or reboot occurred. [Full results and limits](../../project/MT-4.1.2-LOCAL-CANDIDATE.md).

The 4.1.1 updater may stop before installation when an unrelated application's uninstall location is malformed; this was reproduced on the VM. That installation needs a verified manual upgrade once an authorized replacement is available. Do not edit unrelated registry entries or bypass trust checks. These results concern the superseded private R01; current package/publication status is recorded in GitHub Releases. Windows 10, real GPO/corporate SMB and preservation of a present corporate exception file were not verified here. These repository instructions were updated after testing; frozen package contents remain unchanged.

## First upgrade from 4.0.6

4.0.6 cannot apply the 4.1 updater. The initial bootstrap is manual, using verified official packages and administrator privileges. Wait for active maintenance to finish; do not terminate it forcibly.

Before installation, keep a protected backup of config/settings.json, config/MaintenanceToolkit.ini, logs/reports and ProgramData preferences/exceptions, preserving ACLs and ownership. Record InventoryShare from HKLM\Software\Kraugh\Maintenance Toolkit and export relevant task XML/arguments. Do not include organization identities in public reports.

MSI: verify checksums, timestamped signature and publisher. GPO deployment remains organization-owned, with CREATE_TASK=0 and unchanged GPO tasks. For manual installation use /norestart REBOOT=ReallySuppress and explicitly retain the previous INVENTORY_SHARE when configured; do not silently replace it with an empty value. CREATE_TASK=0 avoids adding another schedule. Retain native logs and exit code; do not start maintenance if installation result, version or state is uncertain.

ZIP: verify origin, checksum and signed file catalog before executing scripts or removing Mark of the Web. Extract to a fresh directory and retain the old tree until verification. Copy only required local settings/data. Do not mix core/modules from different versions.

After upgrading, verify the new version, settings, exceptions, inventory destination and tasks before maintenance. Restore only necessary settings.json/INI and local data; never restore the old config/version.json over the new version. Any requested restart is a separate manual decision, never automatic.

## Starting with 4.1

Local scheduling simplification after public 4.1.2 (not yet packaged): choosing P > Create/modify directly creates or updates the task owned by this installation after selecting mode and frequency. Enter selects full maintenance; times/weekdays are requested only when required. Missed-run recovery, execution/continuation on battery and network availability are enabled without further confirmation. A new task keeps reports local; an existing JSON report destination is preserved. Advanced destinations/conditions remain available through the existing scheduling API/CLI contracts. GPO/unknown and foreign-task protections remain; removing a task still requires confirmation. These changes do not alter published 4.1.2 packages.

In the same local change, G asks exactly once whether to enable automatic MT updates, showing the current setting; return to G to change it. Yes explicitly selects standalone ownership and protected opt-in; No disables automation and preserves existing ownership (unknown remains unknown). Invalid/empty answers leave settings unchanged, without another question. G and P are hidden for GPO-managed installations and typed hidden commands cannot invoke their wizards. Unknown installations show G but not P until standalone is explicitly enabled. Machine policy remains authoritative; an organization-owned standalone policy can permit P while G remains hidden. The menu uses declared management/policy, not MSI format or domain membership alone. No new release, package rebuild or version change is planned for this minor change; it waits for the next release.

V detects and offers a confirmed standalone update. G configures standalone management and protected opt-in; automatic installation defaults off and runs before opted-in scheduled executions only. GPO detects/reports; the organization owns installation. Unknown permits detection only until standalone is explicitly declared. Domain membership and MSI/ZIP format alone do not establish GPO management. No additional permanent updater task.

If installation state is uncertain, do not resume maintenance or delete journals/locks to bypass the block: retain logs and complete verified recovery/reinstallation with administrator review. Preparation failures before changes may instead WARN while the current version continues.

## Validation scope

117 regressions and real pilot on Windows 11 Pro build 26200 / Windows PowerShell 5.1. The user explicitly waived the Windows 10 test; it is not claimed validated. Local UNC publication passed; corporate-server authorization must be checked in the actual SYSTEM context. Public documentation is IT/EN only; additional runtime translations have partial coverage with English fallback.

## 4.1.1 HTTP transport patch

4.1.0 is withdrawn from public releases; new users should take 4.1.1 directly. The maintainer reports no end-user 4.1.0 adoption; technical verification downloads are not end-user installation evidence. The compatibility guidance below is retained for historical/test copies, not as a recommended intermediate upgrade step. [Current acceptance/issue status](../../project/ISSUE-REVIEW-20261015.md).

4.1.0 can receive HTTP 403 from hosting before retrieving metadata/payload because it sends no User-Agent. Manually upgrade to 4.1.1 with verified official MSI/ZIP, preserving settings, exceptions, logs/reports, InventoryShare and tasks as above. The patch sends product identity only, without machine/user names. Never delete journals/locks to bypass uncertain installation state. Published 4.1.0 packages remain unchanged.
