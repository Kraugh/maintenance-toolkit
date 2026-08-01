# Development Workflow

This document describes the development and release workflow used by the
Maintenance Toolkit project.

## Stable releases

A stable release is published only when it is objectively better and at least
as reliable as the previous stable version.

There is no release deadline. If a candidate is not convincing, the previous
stable release remains recommended.

## Feedback collection

After a stable release, feedback is collected through:

- GitHub Issues;
- user reports;
- maintainer testing;
- code and repository reviews.

Feedback is recorded before implementation so it is not lost or changed by
memory.

## Sprint planning

Before changing code:

1. review the open issues;
2. define a clear sprint goal;
3. select the issues included in the sprint;
4. defer unrelated work.

Repository maintenance is useful only when it improves development,
distribution or user experience. Organization is not an end in itself.

## Implementation

Changes should be:

- small;
- focused;
- traceable to an issue or documented decision;
- testable independently where possible.

Avoid unrelated “while we are here” changes.

## Module-level debugging

When a defect is isolated to one module:

1. modify only that module;
2. replace the module in the current test build;
3. test only the affected function;
4. integrate the validated patch into the next complete candidate.

Do not create a new Release Candidate for every unvalidated typo or local
patch.

When a defect affects shared code, distribute only the minimum set of affected
files for targeted validation.

## Release Candidates

A complete Release Candidate is created only after individual patches have
been validated.

Each candidate is tested to find regressions, not merely to confirm that the
expected feature works.

A failed candidate is never promoted because work has already been invested in
it.

## Validation

Before a stable release, test the complete Toolkit on:

- Windows 11;
- Windows 10;
- different update conditions where practical.

Validation includes:

- module results;
- console behaviour;
- return to the main menu;
- log and summary consistency;
- native process exit codes;
- update and connectivity behaviour.

## Publishing

Before publishing:

1. update the version and changelog;
2. update the public stable manifest;
3. generate the release package and checksum;
4. verify the archive contents;
5. confirm that the repository is clean;
6. publish the GitHub release;
7. close or update the completed issues.

## User-interface principles

For long-running operations:

- always show elapsed time;
- show a progress bar only when the underlying tool provides real progress;
- otherwise show a spinner;
- never invent percentages or remaining-time estimates;
- keep live console status on one line where possible;
- retain technical detail in logs without flooding the console.

## Core principles

- Quality before schedule.
- Stable before new.
- Honest status reporting.
- Small, testable changes.
- The previous stable release remains available until the new one earns its
  place.
