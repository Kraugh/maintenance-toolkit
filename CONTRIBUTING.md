# Contributing

Thank you for your interest in Maintenance Toolkit.

Bug reports, test results, documentation improvements and feature suggestions
are welcome.

Before opening a new Issue:

- search existing issues first;
- state the exact Maintenance Toolkit version;
- state the Windows version;
- describe the expected and actual behaviour;
- provide clear reproduction steps;
- attach relevant logs or reports when useful;
- remove personal or sensitive information before publishing logs.

During a Release Candidate phase, release-blocking bug fixes and documentation
corrections take priority over new features. Larger feature work is normally
deferred to the next development cycle.

Please keep pull requests focused and explain the problem being solved.

Every public release, including a patch, requires real VM installation/upgrade tests of the final signed MSI and ZIP before publication. Follow the [mandatory VM installation gate](project/DEVELOPMENT_WORKFLOW.md#mandatory-vm-installation-gate), record the source revision and artifact SHA-256 hashes, and publish exactly the verified bytes without rebuilding or re-signing. Failed candidates remain local; download and signature checks alone do not establish installation success.

Thank you for contributing.

A gentleman never runs.
He never stops either.

## Languages and evidence

Public documentation, instructions and announcements on GitHub and the website are published in Italian and English only. Runtime JSON translations may cover additional languages. State the actual release and translation coverage; do not present partial development resources as fully supported stable languages. See [localization](docs/LOCALIZATION.md), [workflow](project/DEVELOPMENT_WORKFLOW.md) and the [current issue review](project/ISSUE-REVIEW-20261015.md). Issue closure requires evidence for its complete acceptance criteria, not only a passing isolated test or a user-reported pilot.
