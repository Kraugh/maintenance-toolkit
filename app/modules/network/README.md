# MT4 Network Diagnostics domain

Network Diagnostics is integrated natively into Maintenance Toolkit 4.

The domain originated from the validated **NDP 0.0.19-RC** baseline and now
runs through the MT4 shell, localization, reporting and Rules Engine.

Main components:

- `NetworkFoundation.ps1` — shared network-domain helpers;
- `TopologyEngine.ps1` — interface and topology model;
- `RoutingAnalyzer.ps1` — routes and routing-mode analysis;
- `NetworkHealth.ps1` — health evidence and rule conditions;
- `RulesEngine.ps1` — rule evaluation;
- `VPNDiagnostics.ps1` — active VPN evidence and classification;
- `SpeedTest.ps1` — optional Ookla Speedtest integration;
- `NetworkDiagnostics.ps1` — interactive Quick Diagnosis workflow;
- `NetworkReports.ps1` — technical TXT/JSON report generation.

The standalone NDP launchers are not part of the MT4 runtime.

Generated reports belong under `reports/`; operational logs remain under
`logs/`. Optional third-party tools are not bundled in the public release.
