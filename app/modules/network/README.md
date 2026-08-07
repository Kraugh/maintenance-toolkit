# MT4 Network Diagnostics domain

Baseline imported from **NDP 0.0.19-RC** (`NDP-20260806-0019-RC.zip`).

This directory initially contains only the engine primitives that are safe to
load as callable functions:

- `TopologyEngine.ps1`
- `RoutingAnalyzer.ps1`
- `RulesEngine.ps1`

The standalone NDP launchers and workflows (`Start.ps1`, `QuickDiagnosis.ps1`,
`TechnicalReport.ps1`, `.cmd` launchers) are intentionally **not** copied into
MT4. They must be refactored into native MT actions.

During the bridge phase the original `ND` function names are preserved so that
behaviour can be compared directly with the immutable NDP 0.0.19-RC baseline.
They will be renamed only after regression parity is proven.
