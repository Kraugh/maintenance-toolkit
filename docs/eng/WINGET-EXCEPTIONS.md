# Machine-local Winget exceptions — 4.0.6

Fixed path: `C:\ProgramData\Kraugh\MaintenanceToolkit\exceptions\winget-exception.json`.

Keep company policy files out of the repository and public packages. Use docs/examples/winget-exception.example.json as a template: schemaVersion 1.0, exact local computerName without domain, mode exclude_packages or block_module, and excludedPackageIds as an array of exact IDs. Empty exclusion lists, duplicates, wildcards, unsupported schema or a wrong computer stop the Winget module before installation.

File and folder must be owned by Administrators or SYSTEM and writable only by these principals, with no reparse points. The current MSI scripts do not install or remove this external directory; preservation during upgrade still requires pilot validation.

Without the file, normal Winget processing is preserved. With exclusions, MT validates a Winget JSON export, filters the exact IDs case-insensitively and upgrades permitted packages individually using --id/--exact/--skip-dependencies. No persistent pins are added or removed. Invalid/failed export blocks installation. Packages missing from the export are not upgraded. The selective pass has one overall time budget. Successful commands are recorded as processed, not individually verified installations.

This controls only direct Winget targets and Winget-managed dependencies. Installer-internal prerequisites, self-updating applications, Microsoft Update and OEM tools remain outside the guarantee. block_module disables the complete Winget module. Future exception files for other modules are not implemented.

Exceptions are reported as WARN and partial maintenance coverage, with structured evidence in maintenance.data.wingetExceptions.
