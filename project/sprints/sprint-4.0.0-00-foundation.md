# MT4 Sprint 0 — Architecture and common core

## Goal

Create the bilingual common foundation for MT4 without integrating the NDP network engines and without breaking MT 3.7.2 maintenance behaviour.

## Scope

- [x] Add the integration map.
- [x] Add `app/core`, `config`, `languages`, `themes`, `reports`, `logs`, `tests`, `rules`, `external`.
- [x] Import and rename Localization and Formatters concepts.
- [x] Define the first common module-result object.
- [x] Add foundation settings and version JSON.
- [x] Add EN/IT language files with key parity.
- [x] Add foundation autotest.
- [ ] Extract renderer compatibility functions from `modules/00_common.ps1`.
- [ ] Define the legacy INI migration adapter.
- [ ] Localize the MT application shell.
- [ ] Integrate Network Diagnostics engines.

## Guardrails

- Existing MT 3.7.2 runtime remains unchanged in this increment.
- NDP 0.0.19-RC remains immutable.
- No second UAC boundary.
- No network engine copy until the common core passes regression tests.


## Development increment 2 — core extraction

- [x] Extract logging from `modules/00_common.ps1`.
- [x] Extract legacy INI compatibility.
- [x] Extract tested native-process execution.
- [x] Move legacy renderer wrappers behind the MT4 renderer service.
- [x] Move the legacy file-based result adapter behind the MT4 result service.
- [x] Reduce `modules/00_common.ps1` to a compatibility loader.
- [x] Extend foundation AUTOTEST for compatibility contracts.
- [ ] Run MT 3.7.2 regression smoke tests through the compatibility loader.
- [ ] Begin localization of the application shell.


## Development increment 3 — bootstrap scope fix

- [x] Load core services when `Bootstrap.ps1` is dot-sourced.
- [x] Preserve core commands after `Initialize-MT4Foundation` returns.
- [x] Add pre-initialization and post-initialization command checks.
- [ ] Re-run foundation AUTOTEST on Windows PowerShell 5.1.
- [ ] Re-run targeted compatibility-loader regression tests.


## Development increment 4 — legacy runtime compatibility

- [x] Remove top-level StrictMode from dot-sourced MT4 runtime core services.
- [x] Preserve StrictMode in standalone developer/autotest tooling only.
- [x] Add a clean-process legacy compatibility smoke test.
- [x] Cover the single-module scalar `.Count` contract used by MT 3.7.2.
- [ ] Re-run foundation AUTOTEST on Windows 10 / PowerShell 5.1.
- [ ] Re-run connectivity, inventory and process-runner smoke tests.


## Development increment 5 — legacy smoke-test correction

- [x] Correct the Windows PowerShell 5.1 scalar `.Count` regression test.
- [x] Test the actual MT 3.7.2 contract instead of assuming scalar `.Count == 1`.
- [x] Preserve the dev.4 StrictMode isolation fix unchanged.
- [ ] Re-run foundation AUTOTEST on Windows 10 / PowerShell 5.1.
- [ ] Re-run connectivity, inventory and process-runner smoke tests.

## Development increment 6 — bilingual application shell

- [x] Runtime banner promoted to `4.0.0-dev.6`.
- [x] Automatic `it-IT` / `en-US` shell localization.
- [x] `-Language auto|en-US|it-IT` deterministic test override.
- [x] Localized module display names and Automatic/Manual states.
- [x] Localized menu, navigation, session headers and quick summaries.
- [x] Localized update-check and primary self-test presentation.
- [x] Localized TXT/HTML summary labels.
- [x] UTF-8 BOM enforced on MT4 runtime PowerShell files for Windows PowerShell 5.1.
- [x] Localization/encoding checks added to foundation AUTOTEST.
- [ ] Maintenance-module internal messages/details remain to be localized.
- [ ] Network Diagnostics engines remain outside MT runtime.


## Development increment 7 — explicit language override

- [x] Preserve caller-supplied settings through foundation initialization.
- [x] Fix `-Language en-US` being replaced by the Windows detected culture.
- [x] Keep `auto` language detection unchanged.
- [x] Add deterministic `en-US` and `it-IT` override tests to AUTOTEST.
- [ ] Validate dev.7 on Windows PowerShell 5.1.
- [ ] Run Connectivity once with `-Language en-US`.
- [ ] Commit the successful bilingual shell checkpoint.


## Development increment 8 — first localized maintenance modules

- [x] Publish the resolved shell language through `MT_LANGUAGE`.
- [x] Add runtime localization context for maintenance modules.
- [x] Add Localization to the compatibility loader.
- [x] Fully localize Connectivity user-facing text and result details.
- [x] Fully localize Winget user-facing text, heartbeat labels and result details.
- [x] Keep Connectivity and Winget operational logic unchanged.
- [x] Add runtime EN/IT localization smoke tests.
- [x] Add a hardcoded-string policy check for migrated modules.
- [ ] Validate Connectivity in EN and IT on Windows 11.
- [ ] Validate Winget in EN and IT without changing native Winget output.
- [ ] Continue module-by-module localization.

## Development increment 9 — localized ProcessRunner feedback

- [x] Localize long-operation start text.
- [x] Localize periodic heartbeat / elapsed-time text.
- [x] Localize process completion and failure text, with and without duration.
- [x] Keep process execution, elevation behaviour, timing and exit-code logic unchanged.
- [x] Add EN/IT ProcessRunner localization checks to AUTOTEST.
- [ ] Validate Winget in `en-US` on Windows 11.

## Development increment 10 — runtime and distribution structure cleanup

- [x] Keep `Avvia_Manutenzione.bat` as the user-facing launcher.
- [x] Move the PowerShell entry point under `app/`.
- [x] Move legacy maintenance modules under `app/modules/`.
- [x] Move `MaintenanceToolkit.ini` under `config/`.
- [x] Move ABOUT and CHANGELOG material under `docs/`.
- [x] Preserve GitHub-standard `README.md`, `CONTRIBUTING.md` and `LICENSE` in the repository root.
- [x] Make the release package root contain only `Avvia_Manutenzione.bat`.
- [x] Exclude `.github`, `project`, developer tools and repository metadata from the user release package.
- [x] Add structure regression checks to MT4 AUTOTEST.
- [ ] Validate launcher, EN/IT shell and representative modules on Windows 11.

## Development increment 11 — structure compatibility root fix

- [x] Correct repository-root resolution in `app/modules/00_common.ps1`.
- [x] Prevent the dot-sourced compatibility loader from overwriting a caller's `$ProjectRoot`.
- [x] Add an AUTOTEST regression guard for caller-scope root isolation.
- [ ] Re-run Foundation AUTOTEST on Windows 11.
- [ ] Launch MT from the root BAT and test EN/IT.

## Development increment 12 — Network Diagnostics foundation import

- [x] Import NDP 0.0.19-RC topology engine unchanged.
- [x] Import NDP 0.0.19-RC routing analyzer unchanged.
- [x] Import NDP 0.0.19-RC rules engine unchanged.
- [x] Preserve NDP function names during the regression bridge.
- [x] Generalize NDP profiler into MT core names.
- [x] Generalize NDP privilege helpers into MT core names.
- [x] Import the eight NDP diagnostic rules as `rules/network.json`.
- [x] Add a same-process Network Diagnostics foundation loader.
- [x] Add static/load regression checks to MT4 AUTOTEST.
- [x] Do not import standalone NDP launchers or menus.
- [x] Do not execute live network diagnostics yet.
- [ ] Validate foundation AUTOTEST on Windows 11 / PowerShell 5.1.
- [ ] Next increment: native MT Network Diagnostics submenu and first callable action.


## Development increment 13 — native Network Diagnostics menu

- [x] Enable the Network Diagnostics domain in MT4.
- [x] Add `[N] Network Diagnostics` to the MT main menu.
- [x] Add a bilingual MT-native Network Diagnostics submenu.
- [x] Add the first callable action: Quick diagnosis.
- [x] Execute topology, routing and rules engines in the existing MT process.
- [x] Reuse the NDP 0.0.19-RC topology/routing/rules models.
- [x] Render the first diagnostic output with MT-owned bilingual text.
- [x] Preserve `Get-VMSwitch` precedence from the NDP topology engine.
- [x] Do not spawn PowerShell/cmd or request additional elevation.
- [x] Add AUTOTEST guards against nested launch/elevation tokens.
- [ ] Validate Quick diagnosis on Windows 11 / Hyper-V in EN and IT.
- [ ] Next increment: technical report and internal `reports` contract.


## Development increment 13a — Hyper-V guest backend presentation

- [x] Detect when NDP returns the same virtual adapter as logical and physical backend.
- [x] Do not present a guest-only Hyper-V virtual NIC as a real physical adapter.
- [x] Show a localized warning that the physical backend is not visible from the guest.
- [x] Keep the NDP topology engine unchanged.
- [x] Render diagnostic duration in seconds when >= 1 second.
- [x] Add a regression fixture to AUTOTEST.
- [ ] Re-test Quick diagnosis on the Windows 11 Hyper-V guest in EN and IT.


## Development increment 14 — native Network Technical Report

- [x] Add `[2] Technical report` to the native Network Diagnostics submenu.
- [x] Generate the TXT report inside MT `reports/`.
- [x] Put report identity fields in the first eight lines.
- [x] Include option/menu, report type, SpeedTest state, scope, RunId, computer and timestamp.
- [x] Use an ASCII-safe descriptive filename.
- [x] Generate correlated Topology and Rules JSON artifacts with the same RunId.
- [x] Reuse NDP 0.0.19-RC topology/routing/rules engines unchanged.
- [x] Keep collection, interpretation, rules and report composition separate.
- [x] Do not add SpeedTest yet; report explicitly records `SpeedTest: NO`.
- [x] Add AUTOTEST checks for report identity, filename safety and no nested execution.
- [ ] Validate Technical Report on Windows 11 in EN and IT.
- [ ] Compare topology/rules artifacts with NDP 0.0.19-RC baseline.


## Development increment 14a — Windows PowerShell 5.1 parser fix

- [x] Parenthesize `Get-MTText` calls passed to `.Add(...)`.
- [x] Fix the parser cascade in `NetworkReports.ps1`.
- [x] Add an AUTOTEST regression guard for unparenthesized command calls inside `.Add(...)`.
- [ ] Re-run Foundation AUTOTEST on Windows PowerShell 5.1.
- [ ] Re-test Network Technical Report (`N` -> `2`).


## Development increment 14b — report mutable-buffer binding fix

- [x] Remove strict generic-list parameter binding from report helper functions.
- [x] Accept the mutable report buffer as an object and validate the `.Add()` contract at runtime.
- [x] Allow empty string values and section separators intentionally.
- [x] Add an AUTOTEST fixture using a newly-created empty report buffer.
- [ ] Re-run Foundation AUTOTEST on Windows PowerShell 5.1.
- [ ] Re-run Network Technical Report (`N` -> `2`).


## Development increment 14c — multiline format-operator fix

- [x] Make all multiline `-f` report expressions explicit for Windows PowerShell 5.1.
- [x] Cover interface, route, VPN, rule, profiler and error report formatting.
- [x] Add AUTOTEST samples for every affected format template.
- [x] Show source position on live Technical Report exceptions.
- [x] Keep write-at-end behaviour: no partial report artifacts on failure.
- [ ] Re-run Foundation AUTOTEST.
- [ ] Re-run Network Technical Report (`N` -> `2`).


## Development increment 14d — safe report formatter

- [x] Remove PowerShell `-f` from Network Report composition.
- [x] Centralize string formatting in `Format-MTNetworkReportText`.
- [x] Use .NET `String.Format` with an explicit argument array.
- [x] Add formatter tests for 1, 2, 5 and 6 arguments.
- [x] Add a deliberate mismatch test with diagnostic template/argument count.
- [x] Preserve write-at-end semantics and no partial artifacts on failure.
- [ ] Re-run Foundation AUTOTEST.
- [ ] Re-run Network Technical Report (`N` -> `2`).


## Development increment 14e — reports directory fix

- [x] Read the report directory from `config/settings.json -> Paths.Reports`.
- [x] Fall back safely to `reports` if the configured value is empty.
- [x] Keep all Network Technical Report artifacts under the internal `reports/` directory.
- [x] Add an AUTOTEST regression guard for the configured reports path.
- [ ] Re-run Foundation AUTOTEST.
- [ ] Re-run Network Technical Report (`N` -> `2`) and verify artifact location.


## Development increment 15 — optional SpeedTest integration

- [x] Add native optional Ookla SpeedTest service.
- [x] Search `external/speedtest.exe`, then PATH.
- [x] Never download or auto-install SpeedTest.
- [x] Missing executable degrades to WARN/SKIP, not ERROR.
- [x] Add `[3] Quick diagnosis + SpeedTest`.
- [x] Add `[4] Technical report + SpeedTest`.
- [x] Preserve one MT process and one elevation boundary.
- [x] Parse Ookla JSON and expose ping, jitter, download, upload and packet loss.
- [x] Technical report header records `SpeedTest: YES`.
- [x] SpeedTest report artifacts share the same RunId and prefix.
- [x] Add parser/conversion and no-download AUTOTEST guards.
- [ ] Validate missing-SpeedTest case on Windows 11.
- [ ] Validate present-SpeedTest case when `speedtest.exe` is available.


## Development increment 15a — SpeedTest report formatter fix

- [x] Route SpeedTest report values through `Format-MTNetworkReportText`.
- [x] Remove the five `-f` expressions reintroduced by dev.15.
- [x] Preserve the dev.14d safe-formatting contract for all report composition.
- [x] Add a SpeedTest-specific AUTOTEST regression guard.
- [ ] Re-run Foundation AUTOTEST.
- [ ] Continue with missing/present `speedtest.exe` runtime tests.
