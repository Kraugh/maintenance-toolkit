# Development Workflow

This document describes the development and release workflow used by the Maintenance Toolkit project.

## Stable releases

A stable release is published only when it is objectively better and at least as reliable as the previous stable version.

There is no release deadline. If a candidate is not convincing, the previous stable release remains recommended.

## Feedback collection

After a stable release, feedback is collected through:

- GitHub Issues;
- user reports;
- maintainer testing;
- code and repository reviews.

Feedback is recorded before implementation so it is not lost or changed by memory.

## Roadmap, backlog and issues

Use the project documents for distinct purposes:

- `project/roadmap.md` contains goals the project has decided to pursue;
- `project/backlog.md` contains unscheduled ideas that have not yet become committed roadmap work;
- GitHub Issues contain concrete, reviewable and closable units of work;
- GitHub Milestones group the concrete issues explicitly selected for a specific release;
- historical sprint documents and architectural decisions preserve what was true when that work was performed.

Do not leave completed work in the roadmap/backlog as apparently unfinished. Do not rewrite historical documents merely to make them look current.

## Sprint / development-cycle planning

Before changing code:

1. review the open issues;
2. review the roadmap goals relevant to the next development cycle;
3. define a clear goal;
4. select or create the concrete issues included in the cycle;
5. when planning a named release, assign only its explicitly selected issues to the corresponding GitHub Milestone;
6. defer unrelated work.

Repository maintenance is useful only when it improves development, distribution or user experience. Organization is not an end in itself.

## Implementation

Changes should be:

- small;
- focused;
- traceable to an issue or documented decision;
- testable independently where possible.

Avoid unrelated “while we are here” changes.

Structural changes, public data contracts, new output locations and cross-project interfaces require an explicit architectural decision before implementation.

## Localization gate during implementation

All new MT-generated user-facing text must follow `docs/LOCALIZATION.md`.

In particular:

- do not introduce hard-coded user-facing strings in application logic;
- use external JSON language resources;
- preserve English fallback behaviour;
- keep machine-readable identifiers and data contracts language-independent;
- update every supported language resource required by the current release scope when adding or changing UI text.

A feature is not implementation-complete if its required localization resources are missing.

## Module-level debugging

When a defect is isolated to one module:

1. modify only that module;
2. replace the module in the current test build;
3. test only the affected function;
4. integrate the validated patch into the next complete candidate.

Do not create a new Release Candidate for every unvalidated typo or local patch.

When a defect affects shared code, distribute only the minimum set of affected files for targeted validation.

## Release Candidates

A complete Release Candidate is created only after individual patches have been validated.

Each candidate is tested to find regressions, not merely to confirm that the expected feature works.

A failed candidate is never promoted because work has already been invested in it.

## Validation

Before a stable release, test the complete Toolkit on supported Windows versions and representative environments.

Validation includes, as applicable:

- module results;
- console behaviour;
- return to the main menu;
- log and summary consistency;
- report/output generation;
- native process exit codes;
- update and connectivity behaviour;
- localization selection and English fallback;
- machine-readable schema compatibility;
- optional remote-output failure behaviour.

Version-specific test matrices belong with the feature/release documentation rather than being frozen permanently in this workflow document.

## Documentation gate

Documentation does not need to be rewritten after every commit, but **every public release has a mandatory documentation review before publication**.

The release is not documentation-complete until all material that describes the current public behaviour has been checked against the release candidate. This includes, as applicable:

- the repository root `README.md`;
- all user and technical documentation under `docs/`;
- `docs/CHANGELOG.md`;
- roadmap/backlog references that describe current or future project status;
- configuration examples and documented defaults;
- command-line options, exit codes and scheduled-execution guidance;
- localization/language support and fallback behaviour;
- log/report paths, formats and output contracts;
- versioned public schemas and example interchange files;
- release/version manifests;
- localized documentation variants that the release publishes;
- the public Maintenance Toolkit pages under `kraugh.it/software/`, including all published language variants and related tutorial/download material.

The website check is performed against a current source archive downloaded from the hosting environment and supplied for release review. Do not rely on a web crawler or cached public-page result as proof that the deployed website is current. Compare the supplied website sources with the release documentation and identify obsolete, missing or contradictory information before publication.

A documentation discrepancy is a release issue: either correct it before the release or explicitly document and accept the exception.

## Publishing

Before publishing:

1. update the version and changelog;
2. complete runtime, localization and schema validation required by the release;
3. complete the documentation gate, including the manual website-source review;
4. update the public stable manifest;
5. generate the release package and checksum;
6. verify the archive contents;
7. confirm that the repository is clean;
8. publish the GitHub release;
9. close or update the completed issues;
10. close the release milestone only when its selected work is complete or explicitly deferred/re-scoped;
11. verify that roadmap/backlog status still matches the published release.

## User-interface principles

For long-running operations:

- always show elapsed time;
- show a progress bar only when the underlying tool provides real progress;
- otherwise show a spinner;
- never invent percentages or remaining-time estimates;
- keep live console status on one line where possible;
- retain technical detail in logs without flooding the console.

For all user-facing MT text, apply the localization contract rather than embedding presentation strings in code.

## Core principles

- Quality before schedule.
- Stable before new.
- Honest status reporting.
- Small, testable changes.
- Stable, versioned contracts at integration boundaries.
- Documentation must describe reality, not intent.
- The previous stable release remains available until the new one earns its place.
