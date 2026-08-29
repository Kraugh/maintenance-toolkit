# Maintenance Toolkit 4.0 — System Administrator Guide

**Document version:** 1.0
**Compatible with:** Maintenance Toolkit `4.0.0`
**Updated:** 29 August 2026

## Purpose

This guide covers unattended and centrally managed Maintenance Toolkit
execution for Windows administrators. It complements the Field Technician Guide
and focuses on `-RunAll`, Windows Task Scheduler and Active Directory / Group
Policy scenarios.

## Non-interactive `-RunAll` mode

Run the signed launcher with:

```powershell
.\MaintenanceToolkit.exe -RunAll
```

`-RunAll` is the non-interactive equivalent of selecting **[A] Run all automatic
modules** from the main menu. It does **not** mean “run every module”. MT selects
the modules enabled under `[Modules]` in `config\MaintenanceToolkit.ini`, runs
them as one session, writes the normal logs and exits without returning to the
interactive menu.

The current runtime returns:

- `0` when the session completes without warnings or errors;
- `20` when one or more modules report warnings and no errors are present;
- `1` when one or more modules report errors.

The launcher manifest requests Administrator privileges. An interactive launch
therefore requests UAC elevation; an unattended scheduled deployment should be
configured with an already elevated execution context instead of depending on a
user to approve UAC.

## Windows Task Scheduler

For a workstation that should receive regular maintenance, a daily task during
a low-impact period is usually preferable to a task at every boot. Suitable
examples include lunch time, the end of the working day or an established
maintenance window. Running at every boot is possible, but can cause Winget,
Microsoft Update and the other automatic checks to run repeatedly after
restarts.

Recommended task configuration:

1. Create a task, not only a basic task, so all security options are available.
2. Select **Run with highest privileges**.
3. Choose the account/context appropriate for the environment.
4. Create a daily trigger at the chosen maintenance time.
5. Set **Program/script** to the full path of `MaintenanceToolkit.exe`.
6. Set **Add arguments** to `-RunAll`.
7. Set **Start in** to the Maintenance Toolkit root directory.
8. If appropriate, enable running the task as soon as possible after a missed
   scheduled start.
9. Run the task manually once and review the MT summary, exit result and logs.

Do not configure an external forced reboot merely to complete maintenance. MT
uses `NeverReboot=1` by default so that reboot decisions remain under
administrative control.

## Active Directory / Group Policy

A practical domain deployment model is to distribute a Scheduled Task through
Group Policy Preferences:

```text
Computer Configuration / GPO
  -> Scheduled Task
     -> MaintenanceToolkit.exe -RunAll
```

The exact Group Policy layout, security filtering and maintenance schedule
should follow the organisation's existing administration model. Pilot the GPO
on a small group of computers before broad deployment.

### Local copy versus SMB share

Two common models are possible.

**Local copy on each workstation**

The GPO or another software-distribution mechanism places a controlled MT
release on the endpoint and the scheduled task executes that local copy. This
avoids depending on network availability during the maintenance run and makes
log permissions straightforward.

**Execution from a central SMB share**

A scheduled task may point to a centrally maintained copy, for example:

```text
\\server\software\MaintenanceToolkit\MaintenanceToolkit.exe -RunAll
```

Treat this as an environment-specific deployment scenario rather than an
unconditional recommendation. MT writes session logs below its root `logs`
directory, so direct execution from a read-only share requires an explicit log
strategy or appropriate write permissions. Network availability also becomes a
runtime dependency.

### Running as `SYSTEM`

When a domain-joined computer accesses network resources while running as local
`SYSTEM`, remote access normally uses the computer's domain identity
(`DOMAIN\COMPUTER$`). If MT is launched from an SMB share, configure both share
and NTFS permissions accordingly, preferably through a dedicated AD computer
group rather than broad write access.

Do not assume that every MT module behaves identically under `SYSTEM`. In
particular, validate Winget and any component that depends on user context on
the Windows builds used by the organisation. Test the exact account, share, GPO
and module configuration before production rollout.

## Suggested central deployment controls

- Publish a known Maintenance Toolkit version and replace it through a controlled
  administrative process.
- Keep the client-facing program directory read-only wherever practical.
- Protect `config\MaintenanceToolkit.ini`; `-RunAll` follows the module flags in
  this file.
- Keep `NeverReboot=1` unless a separate, deliberate reboot policy exists.
- Review disk usage and retention of `logs\` when MT is run frequently.
- Start with a pilot OU or security group and inspect several completed sessions
  before expanding deployment.
- Treat SMB execution and `SYSTEM` execution as validation items for the target
  environment, not as assumptions.

## Related documentation

- [Field Technician Guide](field-technician-guide.md)
- Italian: [Manuale tecnico](../ita/manuale-tecnico.md)
- Repository: <https://github.com/Kraugh/maintenance-toolkit>
- Website: <https://www.kraugh.it>
