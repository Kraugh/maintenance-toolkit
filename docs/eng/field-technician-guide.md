# Maintenance Toolkit 4.0 — Field Technician Guide

**Document version:** 2.1
**Compatible with:** Maintenance Toolkit `4.0.0`
**Updated:** 29 August 2026

## Overview

Maintenance Toolkit is a portable PowerShell toolkit for Windows maintenance,
diagnostics and technical reporting. MT4 combines the established maintenance
modules with integrated Network Diagnostics.

## Requirements

- Windows 10 or Windows 11;
- Windows PowerShell 5.1 compatibility;
- Administrator privileges for operations that require elevation;
- Internet access for Winget, Microsoft Update, update checks and SpeedTest.

## Installation and first run

1. Download the release ZIP from the official GitHub Releases page.
2. Verify the published SHA-256 when required.
3. On Windows 11, if Windows marks the ZIP as downloaded from the Internet,
   verify its origin and use **Properties → Unblock** on the ZIP before
   extracting it.
4. Extract the complete archive.
5. Run `MaintenanceToolkit.exe` (or `Avvia_Manutenzione.bat` as a fallback).
6. Accept administrative elevation.

Do not run individual scripts under `app/modules` directly unless you are
developing or deliberately troubleshooting the Toolkit.

### Smart App Control / Mark of the Web

Do not disable Smart App Control globally just to run Maintenance Toolkit.

After verifying that the archive is the official project release, the ZIP can
be unblocked before extraction:

```powershell
Unblock-File .\Maintenance-Toolkit-4.0.0.zip
```

Extract the archive again afterwards.

## Maintenance modules

The main menu provides the established maintenance functions, including:

- connectivity and inventory;
- Winget;
- Microsoft Update;
- Microsoft Defender;
- restore point creation;
- DISM and SFC;
- disk health;
- optional cleanup actions.

Potentially invasive actions remain disabled by default.


## Command-line and unattended execution

The signed launcher forwards command-line arguments to the PowerShell runtime.

| Option | Purpose |
|---|---|
| `-RunAll` | Run the automatic modules enabled in `[Modules]` inside `config\MaintenanceToolkit.ini`, then exit. |
| `-Only <Key>` | Run only the specified module key, then exit. |
| `-SelfTest` | Run the built-in Toolkit self-test and exit. |
| `-CheckUpdates` | Check the public update manifest and exit. |
| `-Language auto|en-US|it-IT` | Override automatic language selection for this run. |

Examples:

```powershell
.\MaintenanceToolkit.exe -RunAll
.\MaintenanceToolkit.exe -Only Connectivity
.\MaintenanceToolkit.exe -SelfTest
.\MaintenanceToolkit.exe -CheckUpdates
.\MaintenanceToolkit.exe -Language en-US
```

`-RunAll` is the command-line equivalent of **[A] Run all automatic modules**.
It does not mean “run every module”: MT runs only the modules enabled under
`[Modules]` in `config\MaintenanceToolkit.ini`.

For `-RunAll`, `-Only` and `-SelfTest`, exit code `0` means no warnings/errors,
`20` means warnings without errors, and `1` means one or more errors.
`-CheckUpdates` returns `10` when an update is available, `0` when none is
available and `20` if the check cannot be completed normally.

### Scheduled background execution

For Windows Task Scheduler, create a full Task, enable **Run with highest
privileges**, select **Run whether user is logged on or not** for background
execution, set `MaintenanceToolkit.exe` as the program, `-RunAll` as the
arguments and the MT root directory as **Start in**.

A daily low-impact maintenance window is usually preferable to running at every
boot. If appropriate, recover missed runs, require power/network conditions and
choose **Do not start a new instance** when MT is already running.

Allow the real scheduled trigger to start MT at least once, then verify the
Last Run Result and the new session summary. Task Scheduler displays MT exit
code `20` as `0x14`: this means warnings without errors, not a scheduler
infrastructure failure.

For fleets, consider a random trigger delay to avoid simultaneous update
downloads. Execution as `SYSTEM`, Winget under `SYSTEM`, and direct SMB-share
execution remain scenarios to validate separately; see the
[System Administrator Guide](System-Administrator-Guide.md).

## Network Diagnostics

The MT4 network submenu provides:

- `N1` — Quick Diagnosis;
- `N2` — Technical Report;
- `N3` — Quick Diagnosis + SpeedTest;
- `N4` — Technical Report + SpeedTest.

Diagnostics can inspect:

- logical and physical interfaces;
- gateway and default routes;
- DNS and DNS resolution;
- DHCP and APIPA;
- MTU and interface metric;
- link speed;
- active VPN state;
- VPN routes and split/full-tunnel indicators;
- automatic health rules.

A gateway ICMP timeout is a warning, not proof that IP connectivity is broken;
some gateways intentionally filter echo requests.

## Optional SpeedTest

Ookla Speedtest CLI is optional.

Preferred location:

```text
external\speedtest.exe
```

The executable may also be available through `PATH`. Maintenance Toolkit does
not download or bundle SpeedTest.

## Reports

Network Diagnostics reports are written under `reports/`.

A Technical Report normally includes a human-readable TXT file plus correlated
Topology and Rules JSON artifacts. SpeedTest-enabled runs add a SpeedTest JSON
artifact.

## Logs

Operational maintenance logs are stored under `logs/` and separated by computer
and session. The final session summary is normally available at
`logs\COMPUTER-NAME\YYYYMMDD-HHMMSS_COMPUTER-NAME\riepilogo.txt`.

Read the summary first; use detailed logs and Network Diagnostics reports under
`reports/` when more context is needed. Review logs and reports before sharing
them publicly.

## Long-running operations

Winget, Microsoft Update, DISM and SFC can take a long time, especially on
systems that are significantly behind on updates.

MT displays periodic status messages while long operations are running.

### Power management

During a Maintenance Toolkit session, MT asks Windows to keep the system awake
without forcing the display to remain on. The request lasts for the MT process.

## 4.0.0 validation

The 4.0 series has been exercised on:

- physical Windows 11;
- Windows 10 22H2 with Windows PowerShell 5.1;
- a Windows 11 Hyper-V guest;
- Ethernet and Wi-Fi;
- systems with no active VPN;
- Quick Diagnosis and Technical Report workflows.


## Troubleshooting

### Toolkit does not start

Confirm the archive was completely extracted and use
`Avvia_Manutenzione.bat`. Check Smart App Control / Internet-origin blocking
before changing Windows security settings.

### A module reports an error

Review the final summary and session logs. Where possible, MT continues with
other modules so that useful diagnostic evidence is not lost.

### Network Diagnostics warns that the gateway does not answer

Test whether the gateway intentionally blocks ICMP. Working DNS and Internet
traffic can coexist with an ICMP timeout.

### Maintenance takes hours

This can be normal on machines with many pending updates. Check the periodic
status output and make sure the PC is not allowed to sleep.

## Support

When reporting a problem, provide:

- Maintenance Toolkit version;
- Windows version;
- reproduction steps;
- relevant logs/reports after reviewing them for sensitive information.

Repository: <https://github.com/Kraugh/maintenance-toolkit>
Website: <https://www.kraugh.it>
