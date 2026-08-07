# Maintenance Toolkit 4.0

Maintenance Toolkit is a free and open-source utility for maintaining,
diagnosing and collecting information from Microsoft Windows systems.

It automates common maintenance tasks, generates inventories and reports, and
stores detailed logs to support troubleshooting and document technical work.

## Author

**Luca Miselli**  
<https://www.kraugh.it>

Developed with the indispensable help of a very patient Rubber Duck.

## Main features

- connectivity checks;
- hardware and software inventory;
- network configuration reports;
- restore point creation;
- application updates through Winget;
- visible status messages during long-running Winget operations;
- Microsoft Update;
- Microsoft Defender signature updates;
- optional integration with installed OEM tools;
- DISM and SFC diagnostic checks;
- disk health information;
- optional TEMP cleanup;
- optional Windows component cleanup;
- TXT, CSV and HTML logs for each session.

## Getting started

1. Extract the complete Toolkit folder.
2. Run `Avvia_Manutenzione.bat`.
3. Accept the administrative elevation request.
4. Select one or more modules from the menu.

> Do not run individual files from the `app/modules` directory directly.

## Conservative defaults

The following operations are disabled by default:

- automatic restore point creation;
- DISM RestoreHealth;
- SFC Scannow;
- driver installation through Microsoft Update;
- TEMP cleanup;
- Windows component cleanup.

No module restarts the computer automatically.

## Logs

Logs are separated by computer so the Toolkit can run from USB storage,
Dropbox or a network share without mixing results from different systems.

```text
logs/
└── COMPUTER-NAME/
    ├── aggiornamenti_script.log
    ├── errori_script.log
    └── YYYYMMDD-HHMMSS_COMPUTER-NAME/
        ├── sessione.log
        ├── riepilogo.txt
        ├── riepilogo.csv
        ├── riepilogo.html
        └── detailed tool output
```

Each operation started from the menu creates a separate session.

## Self-test and update check

The main menu provides:

- **T — Toolkit self-test**, which checks required files, PowerShell syntax,
  configuration and update-manifest availability;
- **U — Check for updates**, which compares the installed version with the
  stable version published on kraugh.it.

Command-line examples:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\app\MaintenanceToolkit.ps1 -SelfTest
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\app\MaintenanceToolkit.ps1 -CheckUpdates
```

The update check is optional: network errors do not prevent Toolkit use.

## Documentation

User documentation is organized by language:

- [Italian documentation](docs/ita/)
- [English documentation](docs/eng/)

Project documentation:

- [Roadmap](project/roadmap.md)
- [Backlog](project/backlog.md)
- [Architectural decisions](project/decisions.md)
- [Sprint history](project/sprints/)
- [Changelog](CHANGELOG.md)

## Repository structure

The repository layout is optimized for maintainability. Release packages are
generated independently and keep the launcher in the package root for immediate
use by Windows technicians.

## License

Maintenance Toolkit is distributed under the **MIT License**.

See [LICENSE](LICENSE).

The software is provided as-is, without warranty. Test it before using it on
critical or centrally managed systems and follow your organization's policies.


## MT4 development

Maintenance Toolkit 4.0 is in release-convergence testing. The bilingual core,
Network Diagnostics, health rules, VPN diagnostics and reporting are integrated
while compatibility with the validated 3.7.2 maintenance modules is retained.

Release Candidate promotion is controlled by `project/RC1-CHECKLIST.md`.
