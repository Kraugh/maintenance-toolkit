# Maintenance Toolkit 4.0 — Field Technician Guide

**Document version:** 2.0  
**Compatible with:** Maintenance Toolkit `4.0.0-rc.1`  
**Updated:** 8 August 2026

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
5. Run `Avvia_Manutenzione.bat`.
6. Accept administrative elevation.

Do not run individual scripts under `app/modules` directly unless you are
developing or deliberately troubleshooting the Toolkit.

### Smart App Control / Mark of the Web

Do not disable Smart App Control globally just to run Maintenance Toolkit.

After verifying that the archive is the official project release, the ZIP can
be unblocked before extraction:

```powershell
Unblock-File .\Maintenance-Toolkit-4.0.0-rc.1.zip
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
and session.

Review logs and reports before sharing them publicly.

## Long-running operations

Winget, Microsoft Update, DISM and SFC can take a long time, especially on
systems that are significantly behind on updates.

MT displays periodic status messages while long operations are running.

### RC1 power-management limitation

RC1 does not yet inhibit Windows sleep. For long maintenance sessions,
temporarily configure the PC so that it does not enter sleep. The display may
still turn off normally.

## RC1 validation

The candidate has been exercised on:

- physical Windows 11;
- Windows 10 22H2 with Windows PowerShell 5.1;
- a Windows 11 Hyper-V guest;
- Ethernet and Wi-Fi;
- systems with no active VPN;
- Quick Diagnosis and Technical Report workflows.

A real connected-VPN test remains desirable before final 4.0.0 promotion.

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
