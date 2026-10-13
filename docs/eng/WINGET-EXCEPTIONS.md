# Machine-local Winget exceptions — 4.0.6

Fixed path: `C:\ProgramData\Kraugh\MaintenanceToolkit\exceptions\winget-exception.json`.

Keep company policy files out of the repository and public packages. Use docs/examples/winget-exception.example.json as a template: schemaVersion 1.0, exact local computerName without domain, mode exclude_packages or block_module, and excludedPackageIds as an array of exact IDs. Empty exclusion lists, duplicates, wildcards, unsupported schema or a wrong computer stop the Winget module before installation.

File and folder must be owned by Administrators or SYSTEM and writable only by these principals, with no reparse points. The current MSI scripts do not install or remove this external directory. The user reported a remote MSI upgrade under SYSTEM completed with exit code 0: version 4.0.6 was verified, the eight-exception file was unchanged and GPO task configuration was preserved. This pilot evidence does not validate a live selective Winget pass, which remains unverified.

Without the file, normal Winget processing is preserved. With exclusions, MT validates a Winget JSON export, filters the exact IDs case-insensitively and upgrades permitted packages individually using --id/--exact/--skip-dependencies. No persistent pins are added or removed. Invalid/failed export blocks installation. Packages missing from the export are not upgraded. The selective pass has one overall time budget. Successful commands are recorded as processed, not individually verified installations.

This controls only direct Winget targets and Winget-managed dependencies. Installer-internal prerequisites, self-updating applications, Microsoft Update and OEM tools remain outside the guarantee. block_module disables the complete Winget module. Future exception files for other modules are not implemented.

Exceptions are reported as WARN and partial maintenance coverage, with structured evidence in maintenance.data.wingetExceptions.

## Complete example and deployment

```json
{
  "schemaVersion": "1.0",
  "computerName": "TARGET-PC",
  "mode": "exclude_packages",
  "excludedPackageIds": [
    "Vendor.ProtectedPackage"
  ]
}
```

1. On the target PC, use elevated PowerShell to place the file at the fixed path, not in the repository or beside the EXE.
2. Replace TARGET-PC with the exact local computer name and Vendor.ProtectedPackage with IDs identified by a read-only Winget export on that machine.
3. Set owner to Administrators (SID S-1-5-32-544), disable permission inheritance and grant FullControl only to Administrators and SYSTEM (S-1-5-18) on both file and directory. Verify access under SYSTEM.
4. exclude_packages requires a nonempty array. For block_module keep the schema, set mode to block_module and excludedPackageIds to an empty array.
5. Validate the read-only plan before enabling maintenance. MT 4.0.6 EXE, BAT and PS1 entry points share the policy; older versions ignore it.
6. Check logs and maintenance.data.wingetExceptions. Excluded does not mean updated. Allowed items are installed packages mapped by the export, not necessarily available upgrades.
7. An export with exit 0 can warn about unmatched applications; these applications are not in the plan. Preserve the policy during updates and reboots.

Back up the policy before editing and revalidate afterward. To intentionally remove all exceptions, archive the file outside the exceptions directory; do not leave an empty or invalid file. The next run uses the normal global flow.
