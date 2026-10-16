# GitHub issue review — 14 October 2026

Historical checkpoint. Current closure/remaining-work decisions after 4.1.1 deployment are in the [15 October review](ISSUE-REVIEW-20261015.md); the original findings below are preserved.

Sources: live `gh issue list --state open --limit 100 --json number,title,body` and individual `gh issue view` reads; local source/roadmap and [4.1 validation record](MT-4.1-LOCAL-VALIDATION.md). Read-only GitHub review: no issue edited, commented on or closed.

## Conclusion / Esito

None of the 17 open issues has sufficient evidence for complete closure. #27/#28 have local implementation and simulated tests, not full acceptance coverage. H/G/P results are user-reported; signatures, hashes and 72 isolated checks were verified locally. Stable MSI 4.0.6 user-reported upgrade does not prove the 4.1 updater or a live selective Winget pass.

Nessuna delle 17 issue aperte e chiudibile integralmente con le evidenze disponibili. Proporre aggiornamenti di avanzamento per #27, #28 e #20, senza dichiarare completate le prove mancanti. Non chiudere automaticamente per la presenza di codice o documenti.

| Issue | Remaining closure criteria |
|---|---|
| [#30 — NVIDIA: advisory-only driver availability and professional workstation validation](https://github.com/Kraugh/maintenance-toolkit/issues/30) | Professional GPU hardware matrix, post-update read-only checks, ambiguous/offline model cases and CAD/ISV limits remain to validate. |
| [#29 — [OEM Dell] Gestire aggiornamenti rinviati con exit code 0 e creazione del punto di ripristino](https://github.com/Kraugh/maintenance-toolkit/issues/29) | Real SYSTEM Dell deferred/restart outcomes and DCU self-update timeout/reboot-summary evidence remain unresolved; isolated regression fixes do not close the operational issue. |
| [#28 — [FEATURE] Add secure one-click standalone updates](https://github.com/Kraugh/maintenance-toolkit/issues/28) | Real previous-version MSI/ZIP upgrade, interruption/failure recovery and complete preservation checks remain unverified. Signed package verification is not an installation test. |
| [#27 — [FEATURE] Add standalone scheduled-task configuration](https://github.com/Kraugh/maintenance-toolkit/issues/27) | Creation/update implemented; inspection/removal, last/next/result visibility and complete missed-run/power/network behaviour remain incomplete. Real unattended SYSTEM/UNC validation is still required. |
| [#26 — [DOCS] Rewrite the complete MSI/GPO deployment guide](https://github.com/Kraugh/maintenance-toolkit/issues/26) | Complete GPO step-by-step screenshots, all deployment/upgrade/rollback paths, reproducible clean pilot and supplied website-source alignment remain incomplete. |
| [#25 — [FEATURE] Add OEM update provider architecture](https://github.com/Kraugh/maintenance-toolkit/issues/25) | Complete provider architecture and representative Dell/HP outcome validation remain incomplete; Lenovo deferred. |
| [#24 — [MT 5.0] Evolve MT to one engine with three presentation modes](https://github.com/Kraugh/maintenance-toolkit/issues/24) | One shared engine with headless/console/GUI separation is not complete. |
| [#23 — [MT 5.0] Add local Port & Service Analyzer](https://github.com/Kraugh/maintenance-toolkit/issues/23) | Port & Service Analyzer has not been implemented. |
| [#21 — [MT 5.0] Align documentation, schema examples and public release material](https://github.com/Kraugh/maintenance-toolkit/issues/21) | Full schema/source/reliability documentation, complete localization and website-source release gate remain incomplete. |
| [#20 — [MT 5.0] Expand JSON localization to seven official languages](https://github.com/Kraugh/maintenance-toolkit/issues/20) | H and seven target resources exist locally, but five new translations are partial; legacy hardcoded UI and representative non-Latin validation remain. Issue target still includes Swedish rather than the newly approved Spanish; reconcile scope before closure. |
| [#19 — [MT 5.0] Validate Inventory across representative Windows environments](https://github.com/Kraugh/maintenance-toolkit/issues/19) | Representative Windows/hardware/identity and remote-output failure matrix has not been completed. |
| [#18 — [MT 5.0] Profile and benchmark Inventory performance](https://github.com/Kraugh/maintenance-toolkit/issues/18) | Repeatable MT4/MT5 timings, memory/size measurements and benchmark methodology have not been collected. |
| [#17 — [MT 5.0] Define inventory reliability, status and error model](https://github.com/Kraugh/maintenance-toolkit/issues/17) | Complete reliability/status/error contract and fault-injection matrix still require validation; existing inventory foundation is insufficient evidence for full closure. |
| [#12 — Feature: Expand Network Diagnostics Rules Engine](https://github.com/Kraugh/maintenance-toolkit/issues/12) | Initial rules exist; complete expanded gateway/DNS/DHCP/route/metric/MTU remediation and representative environment validation remain. |
| [#11 — [FEATURE] Sub-issue: Advanced VPN Diagnostics Engine](https://github.com/Kraugh/maintenance-toolkit/issues/11) | VPN foundation exists; advanced provider/route/MTU/DNS and before/after validation scope remains incomplete. |
| [#9 — [FEATURE] Add support package (ZIP) generator for logs and diagnostics](https://github.com/Kraugh/maintenance-toolkit/issues/9) | Requested current-computer support ZIP menu/generator is absent; release ZIP packaging is a different function. |
| [#5 — [FEATURE] Show native DISM and SFC progress output](https://github.com/Kraugh/maintenance-toolkit/issues/5) | Elapsed time/spinner feedback does not implement native DISM/SFC progress display. |

## Already closed

GitHub already marks #14 (schema), #15 (collector), #16 (snapshot writer) and #22 (MSI/central scheduling foundation) closed. Do not reopen or duplicate their completed foundation work solely because broader validation issues remain open. Other historical closed issues retain their original evidence.

## Next validation phase

1. Agree the remaining #27 scope: task inspection/removal/status and missed-run/power/network controls; verify actual SYSTEM triggers and inaccessible UNC behaviour.
2. Run separately authorized real MSI/ZIP upgrades and interruption/recovery cases for #28; compare settings, protected opt-in, exceptions and task XML before/after.
3. Reconcile #20 Spanish versus historical Swedish target; complete translation and representative locale coverage before claiming seven fully supported languages.
4. Obtain current hosting source archive for #26/#21 documentation/site comparison. No website-source verification performed in this phase.

Documentation policy: [IT/EN publication, multilingual runtime](../docs/LOCALIZATION.md). Updated documents are working-tree changes, not included retroactively in immutable signed R02 packages. No push, release, tag or live website change.

## Documentation verification

52 Markdown/TXT documentation files scanned, excluding generated reports/logs, build outputs and package staging. All 85 relative Markdown file targets resolve; no missing file targets. This check does not certify external URLs or heading anchors. `git diff --check` passed. Historical sprint/audit bodies were preserved. No temporary files or tasks created for this review. Branch feature/4.1-self-update, HEAD b576a7bef15a00399859cb9a18b6089864ba3c55, no upstream. Existing runtime changes belong to the prior development phase; this review changes documentation only.

## Follow-up — 15 October 2026

#27: inspection/removal/status and configurable missed-run/power/network conditions are now implemented locally, with protected diagnostic journaling and simulated Windows API coverage, including real wizard interactions. #28: fixed scheduled resume host arguments (verified with an innocuous real PowerShell child process), short-download rejection and consumed-payload cleanup. Test-MT41 now reports 112 PASS. These changes supersede the corresponding implementation gaps in the dated table above, but do not establish real SYSTEM/UNC or MSI/ZIP upgrade acceptance. Neither issue is closed. VM checkpoint confirmed; see [pilot](MT-4.1-PILOT.md).

## R04 pilot follow-up

#27 now has real SYSTEM scheduling/update/removal evidence, preserved user task XML, actual loopback UNC publication and unavailable-share WARN. #28 has real MSI/ZIP application, locked-file ZIP recovery, helper-to-runtime single resume, real signature/tamper rejection and an aborted HTTPS transfer. R04 (4.0.9006) passes 117 regression checks. These supersede the corresponding pending pilot items above. MSI rollback/interruption after changes and production feed/bootstrap remain open; local UNC is not a corporate identity test. [Evidence](MT-4.1-VM-PILOT-20261015.md). No GitHub issue was edited or closed.

## Controlled MSI rollback follow-up

#28 now also has real deferred MSI failure after file operations: native 1603, Windows Installer rollback, all previous application hashes and product registration restored, configuration/task preservation, explicit recovery before unblocking and failed payload cleanup. 18 checks passed. Failure fixture 4.0.9007 is not a candidate; installed R04 remains 4.0.9006. The 1618 experiment remains inconclusive. Production feed/bootstrap and publication documentation gates remain; no issue was closed.
