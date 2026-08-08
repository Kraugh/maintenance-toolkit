# Maintenance Toolkit 4.0.0 — RC1 checklist

This checklist is the release gate for the first 4.0.0 Release Candidate.

## Repository

- [ ] `git status` reports a clean working tree.
- [x] Foundation AUTOTEST reports 0 errors and 0 warnings.
- [x] Legacy compatibility test passes.
- [x] `git add -A` produces no EOL warnings.
- [x] Version is consistent between runtime and `config/version.json`.

## Runtime smoke tests

### Windows 11

- [ ] Toolkit starts from `Avvia_Manutenzione.bat`.
- [ ] Administrative elevation succeeds.
- [ ] Main menu renders correctly.
- [x] Network Quick Diagnosis completes and returns to the menu.
- [x] Technical Network Report completes.
- [ ] At least one representative legacy maintenance module completes.

### Windows 10

- [ ] Toolkit starts from `Avvia_Manutenzione.bat`.
- [ ] Administrative elevation succeeds.
- [ ] Main menu renders correctly.
- [x] Network Quick Diagnosis completes and returns to the menu.
- [x] Technical Network Report completes.
- [ ] At least one representative legacy maintenance module completes.

## Network diagnostics

- [x] Physical adapter is identified correctly.
- [x] Default gateway and effective DNS servers are plausible.
- [x] DNS resolution probe behaves correctly.
- [x] DHCP, MTU, metric and link speed are displayed.
- [x] No-VPN systems report no active VPN without false warnings.
- [x] Hyper-V guest reports virtual-first topology correctly.
- [ ] A real VPN case is tested when available, or explicitly deferred to RC validation.

## Reports and presentation

- [x] Quick Diagnosis final outcome matches triggered rules.
- [x] Technical Report contains topology, health, VPN and rule summaries.
- [x] Italian UI contains no obvious missing localization keys.
- [x] English resources remain in key parity with Italian resources.

## Release package

- [ ] `tools/create-release.ps1` rejects a mismatched version.
- [ ] Release ZIP is generated successfully with the exact candidate version.
- [ ] ZIP contains launcher, runtime directories and runtime documentation.
- [ ] ZIP excludes `external`, `logs` and `reports`.
- [ ] SHA-256 sidecar is generated.
- [ ] Extracted ZIP starts successfully on a clean test path.

## Promotion

- [ ] Update `docs/CHANGELOG.md` with the RC1 entry.
- [ ] Set `config/version.json` channel to `release-candidate`.
- [ ] Generate `4.0.0-rc.1`.
- [ ] Commit and push the RC candidate.
- [ ] Publish RC only after the complete candidate passes the release gate.

No new feature is accepted after this gate unless it fixes a release-blocking
problem. Other work moves to the post-4.0 backlog.
