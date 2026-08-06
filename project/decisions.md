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
