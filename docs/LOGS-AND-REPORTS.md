# Logs and reports

This document defines the distinction between **logs** and **reports/output artifacts** in Maintenance Toolkit.

The distinction is based on the purpose of the information, not on the file extension. A `.txt`, `.json`, `.csv` or other file can belong to either category depending on what it represents.

## Logs

A **log** records what happened while Maintenance Toolkit was running.

Logs are primarily intended for:

- understanding the execution flow;
- troubleshooting warnings and errors;
- determining which modules ran, were skipped or failed;
- recording relevant actions performed by MT or by external tools invoked by MT;
- correlating events with a specific computer and execution session.

Typical questions answered by logs are:

- What did MT do during this run?
- Which module generated a warning or error?
- Why was a module skipped?
- What did an external command return?
- When did the run start and finish?

Runtime logs are stored under the session tree:

```text
logs\<COMPUTERNAME>\<YYYYMMDD-HHMMSS_COMPUTERNAME>\
```

The session summary is:

```text
logs\<COMPUTERNAME>\<YYYYMMDD-HHMMSS_COMPUTERNAME>\riepilogo.txt
```

`riepilogo.txt` is part of the logging system even though it is deliberately written as a concise, human-readable summary rather than as a verbose diagnostic log.

Machine-readable files used to describe the execution itself, such as module-result or session-profile data, are also logs when their purpose is to describe what happened during that run.

## Reports and output artifacts

A **report** or **output artifact** contains information produced by Maintenance Toolkit for consultation, analysis, export or interchange.

Reports are primarily intended for:

- presenting collected information to a technician or administrator;
- preserving diagnostic or inventory data independently from the execution narrative;
- allowing later analysis;
- exchanging structured data with another tool or system;
- acting as a stable output contract when explicitly documented as such.

Typical questions answered by reports are:

- What is the current configuration or state of this computer?
- What did a diagnostic collection discover?
- What software or hardware is installed?
- What data should another application import?

Maintenance Toolkit 4.0.0 already uses the repository/runtime `reports\` area for Network Diagnostics reports.

A report does not become a log merely because it is JSON. For example, a topology or diagnostic JSON intended to describe collected machine/network information is a report. Conversely, a JSON file that records module execution results is a log.

## Practical rule

Use this rule when deciding where a new artifact belongs:

> **A log tells what happened while MT was running. A report/output artifact contains information that MT produced for someone or something to consume.**

The same operation can legitimately produce both.

Example:

```text
Log:
Inventory collection completed successfully.
Remote publication failed: share unavailable.

Report/output artifact:
The JSON containing the collected machine inventory.
```

The failure to publish the report is therefore recorded in the log; the inventory itself remains a report/output artifact.

## Relationship between logs and reports

Logs and reports should remain correlatable whenever practical. Useful correlation information can include:

- computer name or another stable device identifier;
- execution timestamp;
- session/run identifier;
- collector version;
- report generation timestamp.

A report should not need the complete runtime log in order to be interpreted when it is intended as a standalone artifact or interchange format.

Likewise, logs should record enough information to determine whether a report was successfully generated, where it was written and whether any subsequent publication/copy operation succeeded.

## Support Package versus Inventory

The planned Support Package and the planned MT 5.x Inventory snapshot serve different purposes.

The **Support Package** is an on-demand troubleshooting bundle. It may contain selected MT logs, diagnostic reports, Windows Event Log exports and other evidence useful to a technician. Its contents must be designed with privacy, sensitive-data and archive-size considerations in mind.

The **Inventory snapshot** is a structured machine-state report intended for stable automated consumption, including by DMT. It follows the versioned Inventory Schema and is not a ZIP of troubleshooting evidence.

Do not merge these contracts merely because both can contain technical information about the same computer.

## Failure behaviour

Failure to create a non-essential report must be handled according to the importance of that report to the requested operation.

In general:

- the failure must be logged;
- MT should not silently claim that an artifact was produced when it was not;
- optional remote publication must not make normal local maintenance dependent on the remote destination;
- partial or invalid interchange files should not be exposed as successfully completed output.

For the planned MT Inventory contract, a valid local snapshot remains the primary output. Failure of an optional remote copy is a warning/publication failure, not a reason to discard the valid local snapshot.

Specific features may define stricter requirements.

## Structured interchange formats

When an output artifact is intended for consumption by another application, its structure is part of a data contract and must be treated more strictly than an internal implementation detail.

Such formats should, where appropriate:

- have an explicit schema/version identifier;
- use stable documented field meanings;
- define required and optional fields;
- define timestamp formats;
- document compatibility expectations;
- define partial/unavailable/error semantics;
- keep machine-readable field names and enumerations language-independent;
- avoid exposing accidental internal implementation structures as public contracts.

This rule applies to the planned MT Inventory JSON consumed by DMT (Dashboard Maintenance Toolkit). The Inventory JSON is a **report/output artifact**, not a log. DMT must depend on the documented Inventory Schema rather than on MT's internal runtime structures.

## Privacy and sensitive information

Both logs and reports can contain machine, user, network or software information. New fields must therefore be evaluated for necessity before being recorded.

Do not add credentials, secrets, Wi-Fi/VPN secrets, BitLocker recovery keys or similarly sensitive data to logs or reports. When potentially identifying information is useful, document why it is collected and keep the scope limited to what the feature requires.

## Paths and configuration

Code should use the project's configured/resolved log and report paths rather than introducing independent hard-coded output locations without an architectural decision.

New output locations, retention rules or publication destinations are structural behaviour and must be discussed before implementation.

## Checklist for new artifacts

Before introducing a new generated file, answer these questions:

1. Is it describing execution, or is it information produced for consumption?
2. Is it therefore a log or a report/output artifact?
3. Who is expected to consume it: MT, a technician, an administrator or another application?
4. Does it need to survive independently of the execution session?
5. Does it require a stable/versioned schema?
6. Where should it be written?
7. How is it correlated with the run that produced it?
8. What happens if generation or publication fails?
9. Does it contain information that creates privacy or security concerns?
10. Are machine-readable fields stable and independent from UI localization?

The answers should be reflected in the relevant feature documentation before a public release.
