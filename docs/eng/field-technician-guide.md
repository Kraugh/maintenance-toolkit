# Field Technician Guide

**Document version:** 1.0

**Compatible with:** Maintenance Toolkit 3.7.1

**Last updated:** 18/07/2026

---

## Contents

1. Introduction
2. Requirements
3. Installation
4. First-time use
5. Running the modules
6. Interpreting the final summary
7. Where to find the logs
8. Troubleshooting
9. Frequently asked questions

---

## Introduction

Maintenance Toolkit is a tool developed to automate key maintenance, diagnostic and verification tasks for Microsoft Windows systems.

It has been designed for use by both field technicians and system administrators, reducing the time required to carry out repetitive tasks and ensuring a standardised procedure.

The Toolkit consists of independent modules: each function can be run individually or as part of a comprehensive maintenance routine.

At the end of each run, a folder containing the intervention logs is automatically generated, which is useful both for documenting the activities carried out and for analysing any anomalies.

The aim of the project is not to replace the technician’s expertise, but to provide a reliable tool that reduces manual tasks and makes each intervention faster, more repeatable and easier to document.

---

## Requirements

Before running the Maintenance Toolkit, check that:

- the computer is switched on and functioning correctly;
- the user has Administrator privileges;
- the system is not currently running any Windows updates;
- an internet connection is available if you wish to use modules that require network access;
- any security software does not prevent PowerShell scripts from running.

To get the most out of the Toolkit, it is advisable to close any unnecessary applications before starting maintenance.

---

## Installation

The Maintenance Toolkit does not require an installation procedure.

To use it, simply:

1. download the latest version of the Toolkit;
2. extract the entire contents of the ZIP archive to a local folder, a USB stick or a shared network folder;
3. run `Avvia_Manutenzione.bat`.

> **Warning**
>
> Do not run the individual PowerShell scripts contained in the `modules` folder.
>
> The `Avvia_Manutenzione.bat` launcher automatically performs all necessary preliminary checks and launches the Toolkit with the required privileges.

> **Tip**
>
> If you use the Maintenance Toolkit frequently, keep an up-to-date copy on a USB stick or in a shared network folder. Thanks to separate log management for each computer, you can use the same copy of the Toolkit on multiple workstations without mixing up the results.

---

## First-time use

When first launched, the Maintenance Toolkit displays an interactive menu containing all the available modules.

> **Screenshot**
>
> Insert the Toolkit’s main screen here.

Each module is identified by a sequential number.

To run a single check, simply type the corresponding number and press **ENTER**.

You can select multiple modules at the same time by separating the numbers with a comma or a space, as indicated in the menu.

To carry out a full maintenance check, use option **A**, which runs all currently enabled modules.

Whilst running, the Toolkit displays the progress of the operations and alerts the technician when a check is taking longer than expected, as is the case with DISM or SFC.

Once the process is complete, a summary is displayed and you can choose to:

- return to the main menu;
- run other modules;
- exit the programme.

> **Tip**
>
> If you are not yet familiar with the Toolkit, it is advisable to start by running just a few modules at a time. Once you have become familiar with how it works, you can use the full maintenance function.

---

## Running the modules

Maintenance Toolkit allows you to run one or more modules depending on the requirements of the task.

For a quick check, you can run a single check, whilst for a comprehensive analysis, you can run all enabled modules.

During processing, the Toolkit keeps the technician constantly informed of the status of operations. Some checks, such as Microsoft Update, DISM RestoreHealth, SFC Scannow or OEM updates, may take several minutes.

During Winget updates, the Toolkit may appear to pause while individual installers are working. On computers that have not been updated for some time, this may take several minutes and installer windows may appear. This is normal.

When an operation takes a particularly long time, progress messages are displayed, preventing the computer from appearing to be frozen.

> **Note**
>
> The duration of the maintenance depends on the computer’s performance, the number of updates available and whether there are any operating system errors.

At the end of each module, the result is automatically recorded in the session logs.

If a module generates an error, the Toolkit continues with the subsequent modules where possible, allowing the technician to gather as much information as possible about the system’s status.

---

## Interpreting the final summary

Once the process has completed, the Maintenance Toolkit generates a summary of the operations carried out.

The purpose of the summary is not to replace the detailed logs, but to provide the technician with an immediate overview of the computer’s general status and the action performed.

The summary shows:

- the modules that were run;
- the modules that were not run;
- any errors detected;
- the path to the folder containing the session logs.

> **Screenshot**
>
> Insert the final summary displayed by the Toolkit here.

> **Note**
>
> The presence of one or more errors in the summary does not necessarily mean that the computer is faulty. Some modules may report anomalies due to specific configurations, privilege restrictions or services that are temporarily unavailable.

For a thorough analysis, it is always advisable to consult the log files generated during the session.

> **Tip**
>
> Before handing the computer back to the customer, taking a few seconds to read the final summary allows you to quickly identify any checks that warrant further investigation.

---

## Where to find the logs

At the end of each run, Maintenance Toolkit automatically creates a new folder dedicated to the current session.

The logs are organised by computer and by date, so as to keep operations carried out on different machines separate.

The structure is similar to the following:

```text
logs/
└── PC-NAME/
    ├── aggiornamenti_script.log
    ├── errori_script.log
    └── YYYYMMDD-HHMMSS_PC-NAME/
        ├── session.log
        ├── riepilogo.txt
        ├── riepilogo.csv
        ├── riepilogo.html
        └── ...
```

Each new run generates a dedicated folder, making it easy to review past operations.

> **Screenshot**
>
> Insert a screenshot of the `logs` folder structure here.

The most important files are:

- **session.log** – contains the entire Toolkit run;
- **summary.txt** – a quick summary readable with any text editor;
- **summary.csv** – data that can be easily imported into Excel or other spreadsheets;
- **summary.html** – a report formatted for viewing in a web browser.

> **Tip**
>
> If you require assistance, always attach the entire session folder rather than just the summary file. This will enable us to accurately reconstruct all the operations performed by the Toolkit.

---

## Troubleshooting

Below are the most common issues that may prevent the Maintenance Toolkit from working correctly.

### The Toolkit does not start

Check that you have fully extracted the contents of the ZIP archive and that you are running `Avvia_Manutenzione.bat`.

Do not run `MaintenanceToolkit.ps1` directly, nor any of the scripts in the `modules` folder.

---

### Windows blocks the script from running

Check that PowerShell is allowed to run local scripts and that any security software is not preventing it from starting.

If necessary, run the Toolkit with Administrator privileges.

---

### A module terminates with an error

The occurrence of an error does not necessarily mean that the entire maintenance process will be interrupted.

Refer to the final summary and the session log files to identify the module that caused the issue and its description.

---

### Maintenance takes a long time

Some modules, such as Microsoft Update, DISM RestoreHealth and SFC Scannow, may take several minutes.

During these operations, the Toolkit continues to display progress messages. Please wait until they have completed before stopping the process.

---

### Requesting support

Before requesting support, please ensure you are using the latest available version of the Toolkit.

If the problem persists, please attach the entire session log folder and briefly describe the behaviour you have encountered.

Up-to-date contact details are always available on the project’s official website.

---

## Frequently Asked Questions

### Can I run the Toolkit from a USB stick?

Yes. The Maintenance Toolkit does not require installation and can be run directly from a USB stick or a shared folder.

---

### Can I use the Toolkit without an internet connection?

Yes.

Modules that do not require network access will continue to function normally. However, some features, such as Microsoft Update or Winget, do require an internet connection.

---

### Can I stop the maintenance at any time?

You can stop the process, but it is advisable to wait until the current module has finished to avoid incomplete results in the logs.

---

### Do the logs contain personal data?

The logs contain only technical information useful for system diagnostics and for documenting the intervention.

However, before sharing the logs with third parties, it is advisable to check their content.

---

### How can I check if a newer version is available?

Use the **Check for updates** function, if available in the installed version, or visit the project’s official website.

---

### Where can I find up-to-date documentation?

Documentation, new versions and information about the project are available on the official Kraugh website and on the project’s GitHub repository.