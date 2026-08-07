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
