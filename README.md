# Maintenance Toolkit 4.0

Maintenance Toolkit is a free and open-source PowerShell toolkit for Windows
maintenance, diagnostics and technical reporting.

**Current pre-release:** `4.0.0-rc.1`  
**Current stable release:** `3.7.2`

The 4.0 line introduces a bilingual application core, integrated Network
Diagnostics, automatic health rules, Advanced VPN Diagnostics and technical
network reports while retaining the validated maintenance modules from the
3.7.x line.

## Main features

- connectivity checks;
- hardware and software inventory;
- application updates through Winget;
- Microsoft Update;
- Microsoft Defender updates;
- restore point creation;
- DISM and SFC diagnostic/repair actions;
- disk health information;
- optional TEMP and Windows component cleanup;
- Network Diagnostics with topology, route, gateway, DNS, DHCP, APIPA, MTU,
  interface metric and link-speed analysis;
- automatic network-health rules with severity summaries;
- Advanced VPN Diagnostics for active tunnel addresses, DNS, routes,
  split/full-tunnel classification and common VPN technologies;
- TXT technical network reports with correlated JSON topology and rule data;
- optional Ookla Speedtest CLI integration;
- per-computer session logs and summaries;
- bilingual interface resources (Italian and English).

## Download

Use the GitHub **Releases** page.

- Choose `3.7.2` for the current stable version.
- Choose `4.0.0-rc.1` only if you want to test the Maintenance Toolkit 4
  Release Candidate.

Release packages contain the runtime only. Development files, generated logs,
reports and optional third-party executables are not bundled.

## First run

1. Download the release ZIP from the official GitHub repository.
2. Verify the SHA-256 file published with the release when appropriate.
3. If Windows marks the downloaded ZIP as coming from the Internet, verify that
   it came from the official project release and use **Properties → Unblock**
   on the ZIP before extracting it.
4. Extract the complete archive.
5. Run `Avvia_Manutenzione.bat`.
6. Accept the administrative elevation request.

> Do not launch individual scripts from `app/modules` directly.

### Windows Smart App Control / Mark of the Web

On some Windows 11 systems, files extracted from an Internet-downloaded ZIP may
be blocked by Smart App Control or Windows security controls.

Do **not** disable Smart App Control globally. If you downloaded the archive
from the official project release and have verified its origin, unblock the ZIP
before extracting it. From PowerShell you may also use:

```powershell
Unblock-File .\Maintenance-Toolkit-4.0.0-rc.1.zip
```

Then extract the archive again.

## Conservative defaults

Potentially invasive operations remain disabled by default, including:

- automatic restore point creation;
- DISM RestoreHealth;
- SFC Scannow;
- driver installation through Microsoft Update;
- TEMP cleanup;
- Windows component cleanup.

No module intentionally reboots the computer automatically.

## Network Diagnostics

From the MT4 network submenu:

- `N1` — Quick Diagnosis;
- `N2` — Technical Report;
- `N3` — Quick Diagnosis + optional SpeedTest;
- `N4` — Technical Report + optional SpeedTest.

Reports are written under `reports/`. SpeedTest support is optional: place the
Ookla CLI executable at `external\speedtest.exe` or make it available in
`PATH`. Maintenance Toolkit does not download or bundle SpeedTest.

## Logs

Operational logs are kept under:

```text
logs/
└── COMPUTER-NAME/
    └── YYYYMMDD-HHMMSS_COMPUTER-NAME/
```

Generated Network Diagnostics reports are intentionally separated under
`reports/`.

## RC1 validation status

`4.0.0-rc.1` has been exercised on:

- Windows 11 physical hardware;
- Windows 10 22H2 with Windows PowerShell 5.1;
- a Windows 11 Hyper-V guest;
- physical Ethernet and Wi-Fi interfaces;
- systems with no active VPN;
- Network Quick Diagnosis and Technical Report workflows.

A real connected-VPN validation is still desirable before the final 4.0.0
promotion.

### Known RC1 operational note

Very long maintenance operations can last hours on systems with many pending
updates. Until power-management inhibition is implemented, configure Windows so
that the computer does not enter sleep while a long maintenance operation is in
progress. The display may still turn off.

## Self-test and update check

The main menu provides Toolkit self-test and update-check functions.

Development/Foundation validation can be run with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
    -File .\app\tools\Invoke-MT4FoundationAutotest.ps1
```

The public update endpoint continues to advertise the stable release channel;
pre-releases remain opt-in through GitHub Releases.

## Documentation

- [Italian documentation](docs/ita/README.md)
- [Italian technical guide](docs/ita/manuale-tecnico.md)
- [English field technician guide](docs/eng/field-technician-guide.md)
- [Changelog](docs/CHANGELOG.md)
- [About](docs/ABOUT.txt)
- [Contributing](CONTRIBUTING.md)

Development history and architecture notes are under `project/`.

## License

Maintenance Toolkit is distributed under the **MIT License**.

See [LICENSE](LICENSE).

The software is provided as-is, without warranty. Test it before using it on
critical or centrally managed systems and follow your organization's policies.

## Author

**Luca Miselli**  
<https://www.kraugh.it>

Developed with the indispensable help of a very patient Rubber Duck.
