# Architectural Decisions

This document records important architectural, organizational and editorial
decisions taken during the development of Maintenance Toolkit.

It is not a changelog. It explains why a decision was made.

Existing decisions are not silently rewritten when the project changes.
A later decision may supersede an earlier one while preserving the history.

---

## 2026-07-18 — GitHub becomes the official repository

### Decision

GitHub is the official source repository for Maintenance Toolkit.

The local working copy is stored outside Dropbox.

### Reason

Git provides:

- complete version history;
- change tracking;
- easier collaboration;
- safer development workflow;
- issue, tag and release management.

Dropbox may remain a private backup or distribution channel, but it is no
longer the authoritative development repository.

---

## 2026-07-18 — Release workflow

### Decision

Development follows this workflow:

```text
Change
↓
Test
↓
Review with git diff and git status
↓
Commit
↓
Push
↓
Tag
↓
GitHub Release
↓
Distribution ZIP
```

Commits represent the development history.

Tags identify exact software versions.

Releases represent tested versions distributed to users.

A documentation-only change does not require a new software release number.

### Reason

Separating commits, tags and releases makes each change traceable and avoids
creating unnecessary software versions for repository-only modifications.

---

## 2026-07-18 — Atomic changes and releases

### Decision

Each bugfix release introduces one clearly identifiable correction whenever
possible.

New features are developed and tested separately from unrelated bugfixes.

### Reason

Small and isolated changes simplify testing, regression analysis and rollback.

---

## 2026-07-18 — Project files in the repository root

### Decision

The following project-governance files are stored in the repository root:

- `README.md`
- `LICENSE`
- `CHANGELOG.md`
- `project/roadmap.md`
- `project/backlog.md`
- `project/decisions.md`

User manuals and instructional material are stored in `docs/`.

### Reason

Project status and governance must be immediately visible from the repository
homepage, while manuals belong to a dedicated documentation tree.

---

## 2026-07-18 — Separation of roadmap, backlog and changelog

### Decision

Each planned item has one authoritative location:

- `project/backlog.md` contains ideas not yet scheduled;
- `project/roadmap.md` contains approved objectives;
- `CHANGELOG.md` contains completed and released work.

Items should not be duplicated across these files.

### Reason

A single source of truth prevents contradictory lists and makes project status
easier to understand.

---

## 2026-07-18 — Documentation language structure

### Decision

User documentation is organized by language:

```text
docs/
├── ita/
└── eng/
```

Three-letter language identifiers are used.

### Reason

The folder name `it` could be confused with Information Technology.
Using `ita` and `eng` is explicit and avoids ambiguity for the intended
technical audience.

---

## 2026-07-18 — Documentation file naming

### Decision

User documentation files use lowercase names separated by hyphens.

Examples:

- `manuale-tecnico.md`
- `manuale-sistemista.md`
- `field-technician-guide.md`
- `system-administrator-guide.md`

Well-known repository files remain uppercase.

### Reason

This convention is readable, predictable and portable across Windows and
case-sensitive operating systems.

---

## 2026-07-18 — Documentation conventions

### Decision

Every user document begins with:

- title;
- document version;
- compatible software version;
- last update date;
- table of contents.

Documentation is developed incrementally. A complete outline is created first,
then sections are written and reviewed.

An unfinished section contains:

```markdown
*Da completare.*
```

The following standard callouts are used:

```markdown
> **Nota**
>
> Testo.
```

```markdown
> **Attenzione**
>
> Testo.
```

```markdown
> **Suggerimento**
>
> Testo.
```

### Reason

A consistent editorial style improves readability, simplifies translation and
makes documents easier to maintain.

---

## 2026-07-18 — Update checking architecture

### Decision

Maintenance Toolkit will provide a **Cerca aggiornamenti** menu entry.

The first implementation will check the latest available version and offer to
open the official download page. Automatic replacement of local files is
deferred until the manual process is stable.

A small remote manifest hosted on kraugh.it is preferred over hard-coding
release data in the Toolkit.

### Reason

A remote manifest allows version, release date, download location and advisory
messages to change without modifying the local program.

---

## 2026-07-18 — Distribution analytics

### Decision

Public download links on kraugh.it may redirect to GitHub release assets while
recording technical download information per version.

The planned private statistics include timestamp, requested version, source IP,
user agent and referrer. Downloads performed for testing by the author must be
identifiable and excludable from aggregate statistics.

### Reason

Version-specific download statistics help evaluate adoption, update continuity
and the effectiveness of documentation and publication channels.
---

## 2026-08-01 — Long-running operation status

### Decision

Every long-running operation always displays elapsed time.

When a real progress value is available from the underlying tool, Maintenance
Toolkit may display a progress bar based only on that value.

When real progress is not available, Maintenance Toolkit displays a spinner
instead of an estimated percentage.

The live status is refreshed on the same console line once per second. Periodic
heartbeat entries may still be written to technical logs at a lower frequency.

Maintenance Toolkit never invents percentages or remaining-time estimates.

After 30 minutes, one discreet reminder may suggest notifying anyone waiting for
the user. After one hour, one hydration reminder may be shown.

### Reason

Elapsed time is useful even when completion cannot be predicted. A single live
line keeps the console readable, while honest progress reporting preserves user
trust.


---

## 2026-08-06 — MT4 integration baseline

NDP 0.0.19-RC is the immutable network regression baseline. MT4 will integrate its engines as a native domain only after a common bilingual core exists. MT process execution and session logging are retained; NDP localization, profiling, topology, routing, rules and scenario concepts are imported.


---

## 2026-08-06 — MT4 compatibility loader

### Decision

`modules/00_common.ps1` becomes a temporary compatibility loader that imports
focused services from `app/core`.

The current module-facing function names remain available during migration.

### Reason

This prevents a simultaneous rewrite of every stable maintenance module while
stopping `00_common.ps1` from becoming the permanent dumping ground for MT4.

New MT4 code must import core services through `Bootstrap.ps1` and must not add
new implementation functions to `modules/00_common.ps1`.


---

## 2026-08-06 — Bootstrap core-loading scope

### Decision

`Bootstrap.ps1` loads MT4 core service files at script scope when the bootstrap
itself is dot-sourced.

`Initialize-MT4Foundation` initializes settings, language and theme only.

### Reason

In Windows PowerShell 5.1, dot-sourcing service files inside an initialization
function creates the imported functions in that function's local scope. Those
commands disappear when the function returns.

Loading services at bootstrap script scope keeps them available to the caller
and to the existing compatibility layer.


---

## 2026-08-06 — StrictMode isolation during MT4 migration

### Decision

Dot-sourced MT4 runtime core files must not enable `Set-StrictMode` at top
level while MT 3.7.2 modules are still using the compatibility loader.

StrictMode remains enabled in standalone developer and AUTOTEST scripts.

New MT4 functions may be written defensively and tested under StrictMode, but
the compatibility layer must not silently alter the execution semantics of
legacy modules.

### Reason

Windows PowerShell 5.1 propagates top-level StrictMode through dot-sourced
scripts into the caller scope.

MT 3.7.2 contains valid legacy constructs, including scalar `.Count`
behaviour, that become runtime errors when StrictMode is unexpectedly enabled.


---

## 2026-08-06 — Legacy scalar Count regression contract

### Decision

The compatibility test reproduces the actual MT 3.7.2 single-selection
expression instead of asserting that a scalar object has `Count == 1`.

### Reason

In Windows PowerShell 5.1 without StrictMode, a missing scalar `.Count`
property evaluates to `$null`. The legacy MT expression
`$Selected.Count -eq 0` therefore evaluates to false and execution continues.

The regression introduced in dev.3 was not a wrong Count value; it was the
`PropertyNotFoundStrict` exception caused by leaked StrictMode.

---

## 2026-08-07 — Bilingual shell before module localization

### Decision

MT4 localizes the application shell first while preserving the stable 3.7.2
maintenance module implementations.

The shell owns menu/navigation, module display names, session/report labels,
update-check presentation and application information.

Module-internal activity text and result details may remain Italian during this
transition and will be migrated module by module.

For Windows PowerShell 5.1 compatibility, MT4 runtime `.ps1` files are stored
as UTF-8 with BOM.


---

## 2026-08-07 — Foundation settings ownership

### Decision

`Initialize-MT4Foundation` accepts an optional preloaded `Settings` object.

If supplied, that object is authoritative for the initialization cycle and is
not reloaded from disk.

If omitted, the foundation imports `config/settings.json` normally.

### Reason

Runtime overrides such as `-Language en-US` must survive foundation
initialization. Dev.6 modified a settings object in the application shell and
then immediately discarded it because the foundation loaded a second copy from
disk.

This contract also prepares MT4 for future command-line or test overrides
without mutating persistent configuration.


---

## 2026-08-07 — Runtime localization contract for maintenance modules

### Decision

The MT4 shell publishes its resolved language in `MT_LANGUAGE`.

Migrated maintenance modules obtain user-facing text through
`Get-MTRuntimeText`; they do not depend on the shell-local `T` helper.

`modules/00_common.ps1` temporarily loads and initializes the shared
Localization service so legacy and migrated modules can coexist.

### Rule for migrated modules

After a maintenance module is marked migrated, user-facing sentences must not
be hardcoded in that module. They belong in `languages/en-US.json` and
`languages/it-IT.json`.

Native program output is not translated or rewritten. For example, Winget may
still display output in the operating system/application language; MT-owned
messages around that output follow the selected MT language.

---

## 2026-08-07 — Common process feedback is localized in ProcessRunner

### Decision

All MT-owned long-operation and process completion/failure messages are
localized in `app/core/ProcessRunner.ps1`.

### Reason

These strings are core UI shared by Winget, DISM, SFC and other process-based
modules. They must not be translated independently by each module.

---

## 2026-08-07 — Separate repository layout from end-user distribution layout

### Decision

The Git repository remains contributor-friendly and keeps the conventional
`README.md`, `CONTRIBUTING.md` and `LICENSE` files in its root.

The generated end-user ZIP has a stricter contract: its root contains only
`Avvia_Manutenzione.bat`. Runtime code lives under `app`, configuration under
`config`, localization under `languages`, and user documentation under `docs`.

### Reason

A GitHub visitor and a technician extracting a release archive have different
needs. The repository must remain understandable to contributors, while the
release package must make the correct launch action unambiguous.

---

## 2026-08-07 — Dot-sourced compatibility loaders must not own generic caller variables

### Decision

`app/modules/00_common.ps1` uses compatibility-specific variable names and
resolves the repository root two levels above `app/modules`.

### Reason

Because the loader is dot-sourced, a generic `$ProjectRoot` assignment mutates
the caller scope. Dev.10 therefore changed the AUTOTEST project root from the
repository root to `app`, producing duplicated paths such as `app/app/tools`
and failed `app/config` / `app/languages` lookups.

---

## 2026-08-07 — NDP integration begins with engine primitives, not workflows

### Decision

MT4 dev.12 imports the NDP 0.0.19-RC topology, routing and rules engines as
engine primitives under `app/modules/network`.

The NDP standalone entry point, `.cmd` launchers, `QuickDiagnosis.ps1` and
`TechnicalReport.ps1` are not copied into the MT runtime.

### Regression bridge

Original `ND` engine function names are temporarily preserved. This is
intentional: it minimizes behavioural changes while MT output is compared
against the immutable NDP 0.0.19-RC oracle.

NDP profiler and privilege helpers are generalized immediately to MT names
because they are common-platform services rather than network-domain identity.

### Execution boundary

Network Diagnostics remains disabled in the MT menu in dev.12. The foundation
loader only dot-sources callable functions into the existing MT process. It
does not elevate, open a nested menu, or launch another PowerShell process.


---

## 2026-08-07 — Network Diagnostics first appears as a native MT submenu

### Decision

MT4 dev.13 exposes Network Diagnostics through `[N]` in the existing
Maintenance Toolkit menu.

The first action, Quick diagnosis, calls the imported NDP topology, routing and
rules engines directly in the current MT PowerShell process.

### Boundaries

- no NDP standalone menu;
- no `Start.ps1`;
- no `.cmd` launcher;
- no second PowerShell process;
- no internal UAC/elevation request;
- no report generation yet.

The original NDP engine model is preserved while MT owns orchestration,
localization and presentation.


---

## 2026-08-07 — MT presentation must not invent host-visible physical hardware

### Decision

When the NDP topology model returns the same virtual adapter as both the
logical interface and the physical backend, MT treats the physical backend as
not visible from the Hyper-V guest rather than displaying that virtual adapter
as a physical NIC.

### Reason

A guest VM cannot reliably identify the host's real network adapter unless the
Hyper-V binding information is actually available. MT therefore keeps the
engine model unchanged for regression parity but applies a conservative
presentation rule at the MT orchestration layer.


---

## 2026-08-07 — Native Network Technical Report owns report identity, not engines

### Decision

MT4 dev.14 introduces `NetworkReports.ps1` as the Network Diagnostics report
composition layer.

Topology, routing and rules engines remain independent and return models. The
report layer consumes those models and writes the user-facing TXT plus
correlated JSON artifacts.

### Report contract

The first eight lines identify the report before any decorative heading:

1. Maintenance Toolkit version;
2. menu option/action;
3. report type;
4. SpeedTest state;
5. scope;
6. RunId;
7. computer;
8. timestamp.

All related artifacts use the same RunId and an ASCII-safe descriptive prefix.

SpeedTest is deliberately not part of dev.14; the report states that explicitly.


---

## 2026-08-07 — Parenthesize command expressions used as .NET method arguments

### Decision

When a PowerShell command invocation is passed as an argument to a .NET method
such as `.Add(...)`, MT4 wraps the command invocation in parentheses.

### Reason

Windows PowerShell 5.1 rejects constructs such as
`$List.Add(Get-MTText ...)`, producing a parser cascade. The compatible form is
`$List.Add((Get-MTText ...))`.


---

## 2026-08-07 — Report line buffers use a behavioural contract

### Decision

Report helper functions accept the line buffer as an object and verify that it
exposes a mutable `.Add()` method instead of relying on PowerShell parameter
binding to a generic `List[string]`.

### Reason

Windows PowerShell 5.1 parameter binding can enumerate or reject collection
arguments in ways that are undesirable for an intentionally mutable buffer,
especially while the collection is empty. The report helpers need object
identity and mutation semantics, not collection coercion.


---

## 2026-08-07 — Multiline format operators require explicit continuation

### Decision

When an MT PowerShell format expression (`-f`) spans multiple physical lines,
the line containing `-f` ends with an explicit continuation character.

### Reason

Windows PowerShell 5.1 may otherwise bind only part of the intended argument
list when the expression is nested in another call. The resulting runtime
exception reports a format index outside the supplied argument list.

This is treated as a PowerShell 5.1 compatibility rule and is covered by
AUTOTEST.


---

## 2026-08-07 — Network report composition does not use PowerShell -f

### Decision

Network Technical Report composition uses a dedicated
`Format-MTNetworkReportText` helper backed by .NET `String.Format`.

### Reason

Three successive Windows PowerShell 5.1 runtime failures showed that the `-f`
operator is too easy to make ambiguous when combined with multiline syntax,
method calls and argument lists.

The report layer now passes an explicit object array to a single formatter.
Formatting failures also include the template and argument count, so a future
mismatch can be located immediately.


---

## 2026-08-07 — Runtime paths are read from the structured Paths object

### Decision

Network report output uses `config/settings.json -> Paths.Reports`.

### Reason

The MT4 structured settings schema stores runtime directories under `Paths`.
Dev.14d incorrectly looked for a top-level `ReportDirectory` property. In
PowerShell this evaluated to an empty value, so `Join-Path` resolved to the
project root and the report artifacts were written beside the launcher.


---

## 2026-08-07 — SpeedTest remains an optional local dependency

### Decision

MT4 never downloads or installs Ookla SpeedTest automatically.

Network Diagnostics searches `external/speedtest.exe` first and then PATH.
Options 3 and 4 request SpeedTest explicitly. Missing executable is a warning
and does not fail Quick Diagnosis or the Technical Report.

### Artifacts

When SpeedTest succeeds during a Technical Report, the raw parsed result is
stored as a correlated `-SpeedTest.json` artifact using the same RunId as the
TXT, Topology and Rules files.


---

## 2026-08-07 — Optional report sections obey the report formatter contract

### Decision

Any future section added to `NetworkReports.ps1`, including SpeedTest, must use
`Format-MTNetworkReportText` for formatted report values.

### Reason

Dev.15 accidentally reintroduced five PowerShell `-f` expressions in the new
SpeedTest section. The pre-existing dev.14d AUTOTEST correctly rejected them
before runtime. The safe formatter contract therefore applies to the whole
report composer, not only the original sections.


---

## 2026-08-07 — Public release packages contain no runtime artifacts or external binaries

### Decision

`create-release.ps1` excludes the following directories completely:

- `external/`
- `logs/`
- `reports/`

The builder validates both the staging tree and the generated ZIP and fails if
any excluded directory is present.

### Reason

The repository is a development workspace; the release archive is a clean
end-user distribution. Logs and reports may contain environment-specific data,
and external binaries have independent redistribution terms.

The same increment also applies presentation-only polish: virtual adapters take
precedence over the Windows `HardwareInterface` flag in human output, while raw
engine data remains unchanged.


---

## 2026-08-07 — Multiline source assertions must enable regex Singleline mode

### Decision

AUTOTEST regex assertions that span multiple physical lines use `(?s)` or a
non-regex ordering check.

### Reason

PowerShell/.NET regex `.` does not match newline by default. Dev.16 correctly
implemented the virtual-first report presentation, but its test falsely failed
because the assertion expected `.*?` to cross line boundaries.


---

## 2026-08-07 — MT health rules extend, rather than rewrite, the NDP baseline

### Decision

The original NDP 0.0.19-RC `RulesEngine.ps1` remains unchanged. MT-specific
health collection and new rules are implemented in `NetworkHealth.ps1`, and
`Invoke-MTNetworkRules` combines baseline and MT extension results.

### Reason

This preserves the regression oracle while allowing MT4 to expand diagnostic
coverage. Gateway ICMP non-response is deliberately a Warning: lack of echo
reply is evidence, not proof that the gateway is unavailable, because network
devices may intentionally block ICMP.


---

## 2026-08-07 — Health batch 2 evaluates DNS/DHCP on the effective interface

### Decision

DNS and DHCP health are evaluated against the interface selected by the
effective/default route rather than across every Windows adapter.

### Reason

Windows systems contain many disconnected miniports, VPN adapters and virtual
interfaces. Treating all of them as health-critical would create false
positives.

NET005/NET006 therefore inspect DNS only on the effective interface. NET007
uses the same effective interface and triggers only when DHCP is known to be
disabled and no usable non-APIPA IPv4 address exists.

CIM/WMI collection failure is not itself a network fault: DHCP state becomes
Unknown and the rule stays clear.


---

## 2026-08-07 — Repository EOL policy is explicit and versioned

### Decision

Maintenance Toolkit stores normal text files as LF through `.gitattributes`.
Native Windows `.bat` and `.cmd` launchers are stored as CRLF.

### Reason

Developer machines may use `core.autocrlf=true`. Without a repository policy,
replacing the development tree from generated ZIP files caused Git to emit
line-ending conversion warnings for nearly every source file. The repository
must define its own deterministic EOL contract instead of depending on local
Git configuration.

---

## 2026-08-07 — Network Health batch 3 remains conservative

### Decision

NET008 warns only for MTU below 1280 on the effective non-VPN IPv4 interface.
NET009 warns only when multiple default routes share the same best total metric.
NET010 warns only when the effective adapter is physical, non-virtual, non-VPN
and reports 10 Mbps or less.

### Reason

MT4 Health rules should identify suspicious evidence without flagging common
VPN and virtualization configurations as faults.


---

## 2026-08-07 — Health AUTOTEST fixtures track the complete Health context contract

### Decision

Synthetic `Health` fixtures used by earlier Network Health batches include
neutral values for fields introduced by later batches.

### Reason

`Invoke-MTNetworkRules` evaluates the complete enabled rule set. Under
`Set-StrictMode -Version Latest`, an older fixture that omits a newly introduced
Health property can fail before the intended rule assertion is reached.

This is a test-fixture compatibility issue; dev.20 batch-3 runtime behaviour is
unchanged.
