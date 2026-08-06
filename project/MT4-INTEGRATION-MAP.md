# Maintenance Toolkit 4.0
## Technical Integration Map — MT 3.7.2 + NDP 0.0.19-RC

Status: architecture baseline  
Date: 2026-08-06  
Sources:

- Maintenance Toolkit 3.7.2, commit/tag baseline `f8cb368 / v3.7.2`
- NDP 0.0.19-RC
- `NDP-to-MT4-HANDOFF-20260806.md`

---

## 1. Executive decision

Maintenance Toolkit 4.0 will not execute NDP as a nested application.

NDP becomes the native **Network Diagnostics** domain of MT and keeps its
standalone 0.0.19-RC package only as a regression reference.

The integration must first create one common MT4 platform for:

- settings;
- localization;
- rendering;
- long-running operations;
- logging;
- profiling;
- privilege checks;
- reports;
- autotest.

Only after that common platform is stable should the NDP network engines be
moved into MT.

---

## 2. Current codebase summary

### Maintenance Toolkit 3.7.2

Strengths:

- stable interactive application and session lifecycle;
- one UAC boundary at startup;
- mature maintenance modules;
- session logging and per-module results;
- reliable external-process execution;
- clean one-line status for long operations;
- update check and release manifest;
- final TXT/HTML summaries;
- proven Windows 10 and Windows 11 behaviour.

Main architectural debt for MT4:

- most user-visible text is hardcoded in Italian;
- application orchestration, menu, self-test and report generation are
  concentrated in `MaintenanceToolkit.ps1`;
- `modules/00_common.ps1` contains several unrelated services;
- configuration is split between INI, constants and code;
- modules communicate through environment variables and a JSON result file;
- the existing network report is a simple collector, not a topology engine;
- localization-sensitive parsing exists in functional code, notably SFC result
  interpretation.

### NDP 0.0.19-RC

Strengths:

- localization with `en-US` and `it-IT`;
- JSON-based settings, rules, reports, scenarios, version and theme;
- separated topology, routing, rules and rendering engines;
- reusable duration formatting and operation feedback;
- profiler and structured diagnostic model;
- extensive autotest and repeatable scenarios;
- explicit report identity and internal `reports` directory;
- tested Hyper-V and VPN interpretation;
- optional SpeedTest handling.

Main integration debt:

- standalone menu and launcher must disappear inside MT;
- NDP prefixes and project-specific globals must become MT core contracts;
- several module scripts dot-source dependencies independently;
- `NetworkReportEngine.ps1` is still large and mixes significant collection
  and report construction work;
- some text remains hardcoded in report/collector code despite the localization
  principle;
- version/build data appears in language/configuration files and needs one
  authoritative source;
- legacy standalone settings such as `TechnicalReportDirectory: Desktop` must
  not survive the integration;
- logging is described architecturally but is less mature than MT session
  logging.

---

## 3. Target MT4 architecture

```text
maintenance-toolkit/
├─ MaintenanceToolkit.ps1          # thin entry point only
├─ Avvia_Manutenzione.bat          # single UAC launcher
├─ config/
│  ├─ settings.json
│  ├─ modules.json
│  ├─ logging.json
│  ├─ reports.json
│  ├─ rules.json
│  └─ version.json
├─ languages/
│  ├─ en-US.json
│  └─ it-IT.json
├─ themes/
│  └─ default.json
├─ app/
│  ├─ core/
│  │  ├─ Bootstrap.ps1
│  │  ├─ Settings.ps1
│  │  ├─ Localization.ps1
│  │  ├─ Renderer.ps1
│  │  ├─ Formatters.ps1
│  │  ├─ Operations.ps1
│  │  ├─ ProcessRunner.ps1
│  │  ├─ Logging.ps1
│  │  ├─ Profiler.ps1
│  │  ├─ Privileges.ps1
│  │  ├─ Results.ps1
│  │  └─ Reports.ps1
│  ├─ modules/
│  │  ├─ maintenance/
│  │  │  ├─ Connectivity.ps1
│  │  │  ├─ Inventory.ps1
│  │  │  ├─ RestorePoint.ps1
│  │  │  ├─ Winget.ps1
│  │  │  ├─ MicrosoftUpdate.ps1
│  │  │  ├─ Defender.ps1
│  │  │  ├─ OEM.ps1
│  │  │  ├─ DISM.ps1
│  │  │  ├─ SFC.ps1
│  │  │  ├─ DiskHealth.ps1
│  │  │  └─ Cleanup.ps1
│  │  └─ network/
│  │     ├─ Collectors/
│  │     ├─ TopologyEngine.ps1
│  │     ├─ RoutingAnalyzer.ps1
│  │     ├─ RulesEngine.ps1
│  │     ├─ NetworkDiagnostics.ps1
│  │     └─ NetworkReports.ps1
│  └─ tools/
│     ├─ Invoke-Autotest.ps1
│     └─ ScenarioValidator.ps1
├─ rules/
│  └─ core.json
├─ tests/
│  ├─ scenarios/
│  └─ RunScenario.ps1
├─ external/
│  ├─ README.md
│  └─ speedtest.exe              # optional runtime dependency
├─ logs/                         # runtime, ignored by Git
└─ reports/                      # runtime, ignored by Git
```

The exact filenames may change, but the separation of responsibilities is
mandatory.

---

## 4. Component disposition map

Legend:

- **KEEP**: preserve behaviour with minimal change.
- **IMPORT**: bring from NDP into MT4.
- **MERGE**: combine both implementations into one MT4 service.
- **REFACTOR**: preserve capability but redesign its boundaries.
- **REPLACE**: retire the MT implementation in favour of the NDP engine.
- **DROP**: do not integrate.

| Area | MT 3.7.2 | NDP 0.0.19-RC | MT4 decision |
|---|---|---|---|
| Entry point | `MaintenanceToolkit.ps1` | `app/Start.ps1` | **REFACTOR MT** into a thin bootstrap; **DROP** NDP standalone menu |
| UAC launcher | `Avvia_Manutenzione.bat` | `.cmd` launchers | **KEEP MT**; NDP core never elevates |
| Module catalog | hardcoded objects in main | hardcoded menu actions | **REFACTOR** into localized/configured module metadata |
| Settings | INI + constants | structured JSON | **MERGE**, moving toward JSON while preserving 3.7.2 migration |
| Localization | absent | `Localization.ps1` + JSON | **IMPORT and generalize** as MT core |
| Renderer | `Write-*` helpers in common | dedicated renderer + theme | **MERGE**; NDP architecture, MT status semantics |
| Status levels | OK/WARN/SKIP/ERROR | OK/INFO/WARNING/CRITICAL | **NORMALIZE** one shared enum and renderer mapping |
| Duration formatting | embedded elapsed formatting | `Format-NDDuration` | **IMPORT** and use everywhere |
| Long operations | mature native process wrapper | generic operation timer | **MERGE**: MT process runner + NDP reusable operation contract |
| Native process execution | robust MT wrapper | not equivalent | **KEEP/REFACTOR MT** into `ProcessRunner.ps1` |
| Logging | mature session logs | config/diagnostic intent | **KEEP MT behaviour**, refactor into service, adopt JSON config |
| Module results | env vars + `module_result.json` | returned objects/models | **REFACTOR** to returned result objects; transitional adapter allowed |
| Profiler | limited duration in session | step profiler | **IMPORT**, integrate with MT logs/results |
| Privilege checks | embedded self-test | dedicated core | **MERGE** into dedicated MT service |
| Autotest | main-script checks | 639-line extensive tool | **MERGE**, using NDP coverage model and MT release checks |
| Scenarios | absent | repeatable network scenarios | **IMPORT** as developer/test assets |
| Connectivity | explicit gateway/DNS/TCP check | network diagnostics tests | **KEEP MT basic check**, expose it as shared collector service |
| Inventory | MT module | partial NDP report collection | **KEEP MT**, later deduplicate collectors |
| Basic network report | `03_network.ps1` | advanced engines | **REPLACE** with MT4 Network Diagnostics entry points |
| Network collection | basic MT | large `NetworkReportEngine` | **IMPORT then split** into collectors and report composition |
| Topology | absent | `TopologyEngine.ps1` | **IMPORT** |
| Hyper-V binding | absent/basic | authoritative `Get-VMSwitch` path | **IMPORT**, preserve tested precedence |
| Routing analysis | absent | `RoutingAnalyzer.ps1` | **IMPORT** |
| Rules engine | absent | `RulesEngine.ps1` + JSON rules | **IMPORT** |
| Topology rendering | absent | `TopologyRenderer.ps1` | **IMPORT**, adapt to common renderer |
| Quick diagnosis | absent | script workflow | **REFACTOR** into callable MT module action |
| Technical report | basic MT report | detailed NDP workflow | **REFACTOR/IMPORT** under common report service |
| Reports directory | session logs + summaries | internal `reports` | **MERGE** with strict logs/reports separation |
| Report identity | MT session metadata | explicit option/type/SpeedTest/RunId | **IMPORT NDP contract** for all diagnostic reports |
| SpeedTest | absent/optional historical | included optional executable | **IMPORT as optional dependency**, warning only when absent |
| Themes | console colours in code | `themes/default.json` | **IMPORT carefully**; renderer owns visual behaviour |
| Update check | mature MT feature | version JSON | **KEEP MT**, localize and centralize version source |
| Release tooling | `create-release.ps1` | manual RC convention | **KEEP MT**, update for MT4 layout |
| Maintenance modules | stable MT modules | none | **KEEP**, localize and migrate to common core |
| NDP launchers | none | `NetworkDiagnostics.cmd`, `AUTOTEST.cmd` | **DROP from runtime package**; retain standalone baseline archive |
| NDP name/version UI | separate product identity | NDP branding | **DROP in integrated UI**; report engine may note origin only in development metadata |

---

## 5. Core collision analysis

### 5.1 `modules/00_common.ps1` must be dismantled, not expanded

At 609 lines it currently contains:

- log path initialization;
- text writing;
- status rendering;
- INI parsing;
- result persistence;
- process-output decoding;
- command-line quoting;
- long-operation display;
- process execution.

Adding Localization, Profiler, themes and NDP report services to this file would
create the Frankenstein architecture we explicitly want to avoid.

MT4 should split it into focused core files. During migration,
`00_common.ps1` may temporarily become a compatibility loader that dot-sources
the new services.

### 5.2 MT process execution wins

The MT wrapper has already survived real DISM, SFC, Winget and Microsoft Update
tests on Windows 10 and 11. NDP's generic long-operation function is useful as
an API/UX model, but it must not replace the native process runner.

Target distinction:

- `Invoke-MTProcess`: owns process lifetime, stdout/stderr, exit code and logs.
- `Invoke-MTLongOperation`: owns generic activity display and elapsed time.
- process execution may use the long-operation renderer but remains a separate
  service.

### 5.3 NDP localization architecture wins

MT has hundreds of embedded Italian strings across the main script and modules.
NDP already supplies:

- language resolution;
- `en-US` fallback;
- language imports;
- key-based text lookup;
- key-consistency autotests.

This becomes the MT4 localization foundation, renamed to MT conventions and
extended to support formatting arguments and missing-key diagnostics.

### 5.4 Logging and profiling are complementary

MT has stronger persistent operational logging.
NDP has stronger step profiling.

The target session should contain both:

```text
logs/<computer>/<session>/
├─ session.log
├─ errors.log
├─ module-results.json
├─ profile.json
└─ technical artifacts
```

User-facing diagnostic reports belong under `reports`, not inside logs.

### 5.5 Result transport must stop depending on environment variables

MT currently uses environment variables for paths and a shared
`module_result.json`. This works but is fragile for a larger modular
application.

MT4 modules should return a common object, for example:

```text
ModuleKey
Status
SummaryKey
SummaryArguments
Started
Finished
Duration
RequiresReboot
Artifacts
Diagnostics
```

A temporary compatibility adapter can convert existing module result files
until all maintenance modules are migrated.

---

## 6. Localization migration rules

1. `en-US` is always complete and is the fallback.
2. `it-IT` must contain the same keys.
3. Version numbers do not belong in language files.
4. Module code contains no user-visible sentences.
5. Parsing logic must never depend on the selected UI language.
6. Native localized Windows output must be interpreted through:
   - exit codes;
   - structured APIs;
   - language-independent patterns where available;
   - isolated native-output parsers with test fixtures.
7. Autotest fails on:
   - missing English keys;
   - mismatched language keys;
   - malformed format placeholders;
   - hardcoded UI text in migrated modules, where detectable.
8. Unsupported Windows languages show the documented English fallback message.

The SFC module requires special attention because MT 3.7.2 currently recognizes
Italian native-output text. That must become a separate native-output parser,
not part of UI localization.

---

## 7. Menu integration proposal

Do not copy NDP's standalone menu into MT.

The main MT menu should remain the application shell and gain one localized
entry:

```text
[N] Network Diagnostics
```

Selecting it opens a domain submenu:

```text
[1] Quick diagnosis
[2] Full technical report
[3] Quick diagnosis + SpeedTest
[4] Full technical report + SpeedTest
[5] Open Network Connections (ncpa.cpl)
[M] Return to main menu
```

The four report actions call the same underlying services with explicit option
metadata. They do not execute `Start.ps1` or launch another PowerShell process.

---

## 8. Report contract for MT4 Network Diagnostics

Every execution creates one `RunId`.

Required header fields:

```text
Product
Version
Build/channel
Menu option and localized description
Report type
SpeedTest included/not included
Interface scope
RunId
Computer
User
Administrative state
Timestamp
Language
```

Artifacts from one execution share the RunId:

```text
MT4-NET-OPT02-Technical-PC-YYYYMMDD-HHMMSS.txt
MT4-NET-OPT02-Topology-PC-YYYYMMDD-HHMMSS.json
MT4-NET-OPT02-Rules-PC-YYYYMMDD-HHMMSS.json
```

Exact prefix can be decided later; identity and ASCII safety are mandatory.

---

## 9. Autotest target

MT4 AUTOTEST must merge the strongest checks from both projects.

### Platform

- PowerShell 5.1 compatibility;
- administrative state;
- required paths;
- JSON parsing;
- PowerShell syntax;
- command availability;
- optional dependencies;
- release/version consistency.

### Localization

- English completeness;
- language-key parity;
- placeholder compatibility;
- fallback behaviour;
- unsupported-language message.

### Core contracts

- renderer smoke tests;
- formatter smoke tests;
- process-runner smoke tests;
- result-object schema;
- log/report directory separation;
- long-operation behaviour.

### Network domain

- topology model;
- Hyper-V binding;
- routing mode;
- VPN state vs installed adapters;
- rules engine isolation;
- report identity;
- shared RunId;
- SpeedTest missing/present behaviour;
- scenario validation.

Expected environmental limitations remain WARN/SKIP, not automatic ERROR.

---

## 10. Migration phases

### Phase 0 — Freeze and safety

- Tag/freeze MT 3.7.2.
- Preserve NDP 0.0.19-RC unchanged.
- Create MT4 development branch.
- Add integration documents and regression checklist.
- No feature development.

### Phase 1 — MT4 common platform

- Introduce `app/core`, `config`, `languages`, `themes`, `reports`.
- Import and rename NDP localization/formatter/renderer/profiler services.
- Extract MT logging/process/results services from `00_common.ps1`.
- Add compatibility loader for existing maintenance modules.
- Keep existing MT menu and behaviour working.

Exit criterion: MT maintenance functions still pass regression tests in both
languages.

### Phase 2 — Bilingual MT maintenance shell

- Localize main menu, update check, summaries, self-test and common statuses.
- Move module names and descriptions to language JSON.
- Localize existing maintenance modules incrementally.
- Isolate parsing of native Windows output.

Exit criterion: full MT 3.7.2 behaviour available in EN and IT.

### Phase 3 — Network Diagnostics domain

- Move NDP collectors and engines under `app/modules/network`.
- Remove standalone elevation/menu assumptions.
- Wire the Network Diagnostics submenu into MT.
- Use common settings, renderer, logging, profiler and reports.
- Keep the NDP model/rules logic unchanged where possible.

Exit criterion: MT4 output matches NDP 0.0.19-RC on the regression scenarios.

### Phase 4 — Unified autotest and scenarios

- Merge MT and NDP autotests.
- Preserve repeatable scenarios.
- Add cross-language and package checks.
- Validate Windows 10/11, Hyper-V, VPN and missing SpeedTest cases.

### Phase 5 — Consolidation

- Remove compatibility adapters.
- Split oversized network collector/report files.
- Remove obsolete standalone NDP runtime files from MT package.
- Update documentation, release tooling and manifest.
- Only then consider additional features.

---

## 11. First sprint proposal

Name:

`MT4 Sprint 0 — Architecture and common core`

Scope:

1. create an MT4 branch;
2. add this integration map;
3. add `config`, `languages`, `themes`, `app/core`, `reports`;
4. import Localization and Formatters under MT names;
5. create one authoritative version/config loader;
6. split renderer functions out of `00_common.ps1`;
7. define the common module-result object;
8. extend AUTOTEST for localization and core contracts;
9. keep every existing maintenance module operational;
10. do **not** integrate the network engines yet.

This sprint intentionally produces little visible functionality. Its output is
the safe foundation that prevents MF(rankenstein) 4.

---

## 12. Existing issue impact by title

| Issue | MT4 treatment |
|---|---|
| Feedback during long operations | absorbed into common Operations/Renderer contract |
| Native DISM and SFC progress output | remains separate; real progress only |
| Repository structure for long-term maintainability | largely delivered by Phase 1 |
| Log and info collector | redesign against unified logs/results/reports |
| Use English as primary repository language | superseded by full bilingual runtime/repository work |
| Support package ZIP generator | remains a useful MT4 feature after log structure stabilizes |
| Network Diagnostics module for MT 5.0 | retitle as MT4 parent/epic and reference NDP 0.0.19-RC |
| Advanced VPN Diagnostics Engine | partially supported by NDP; keep open only for functionality beyond baseline |
| Diagnostics Rules Engine | baseline exists in NDP; close only after MT4 integration/regression passes |

No issue should be closed merely because NDP contains an implementation.
Integration and regression validation are the completion criteria.

---

## 13. Immediate decisions

Accepted now:

- MT4 common core follows separated NDP-style architecture.
- MT's tested process execution and session logging are preserved.
- NDP localization, profiler, topology, routing, rules and scenario concepts are
  imported.
- MT basic network report will eventually be replaced by Network Diagnostics.
- `00_common.ps1` becomes a transitional compatibility loader, not the future
  dumping ground.
- Network engines are not copied until the common bilingual platform is stable.
- The standalone NDP archive remains immutable as the regression oracle.

Open design decisions for Sprint 0:

- final JSON schema for modules and settings;
- whether INI is migrated immediately or read through a compatibility adapter;
- final common status enum;
- final MT4 report filename prefix;
- exact location of developer-only scenarios in the repository;
- whether `speedtest.exe` is included in every release ZIP or downloaded/added
  separately.

---

## 14. Definition of success

MT4 succeeds when:

- existing MT maintenance operations remain stable;
- EN/IT are complete and interchangeable;
- NDP operates as a native domain with no nested launcher or second UAC;
- topology/routing/rules outputs match the standalone regression baseline;
- reports are self-identifying and stored internally;
- optional dependencies degrade gracefully;
- real errors remain visible;
- autotest blocks parsing, localization, packaging and runtime regressions;
- the project has one core, one renderer, one logger, one settings system and
  one release identity.
