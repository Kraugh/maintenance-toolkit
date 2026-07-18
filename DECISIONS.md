# Architectural Decisions

This document records important architectural, organizational and editorial
decisions taken during the development of Maintenance Toolkit.

It is not a changelog. It explains why a decision was made.

Existing decisions are not silently rewritten when the project changes.
A later decision may supersede an earlier one while preserving the history.

---

## 2026-07-18 — GitHub becomes the official repository

### Decision

GitHub is the official source repository for Maintenance Toolkit.

The local working copy is stored outside Dropbox.

### Reason

Git provides:

- complete version history;
- change tracking;
- easier collaboration;
- safer development workflow;
- issue, tag and release management.

Dropbox may remain a private backup or distribution channel, but it is no
longer the authoritative development repository.

---

## 2026-07-18 — Release workflow

### Decision

Development follows this workflow:

```text
Change
↓
Test
↓
Review with git diff and git status
↓
Commit
↓
Push
↓
Tag
↓
GitHub Release
↓
Distribution ZIP
```

Commits represent the development history.

Tags identify exact software versions.

Releases represent tested versions distributed to users.

A documentation-only change does not require a new software release number.

### Reason

Separating commits, tags and releases makes each change traceable and avoids
creating unnecessary software versions for repository-only modifications.

---

## 2026-07-18 — Atomic changes and releases

### Decision

Each bugfix release introduces one clearly identifiable correction whenever
possible.

New features are developed and tested separately from unrelated bugfixes.

### Reason

Small and isolated changes simplify testing, regression analysis and rollback.

---

## 2026-07-18 — Project files in the repository root

### Decision

The following project-governance files are stored in the repository root:

- `README.md`
- `LICENSE`
- `CHANGELOG.md`
- `ROADMAP.md`
- `BACKLOG.md`
- `DECISIONS.md`

User manuals and instructional material are stored in `docs/`.

### Reason

Project status and governance must be immediately visible from the repository
homepage, while manuals belong to a dedicated documentation tree.

---

## 2026-07-18 — Separation of roadmap, backlog and changelog

### Decision

Each planned item has one authoritative location:

- `BACKLOG.md` contains ideas not yet scheduled;
- `ROADMAP.md` contains approved objectives;
- `CHANGELOG.md` contains completed and released work.

Items should not be duplicated across these files.

### Reason

A single source of truth prevents contradictory lists and makes project status
easier to understand.

---

## 2026-07-18 — Documentation language structure

### Decision

User documentation is organized by language:

```text
docs/
├── ita/
└── eng/
```

Three-letter language identifiers are used.

### Reason

The folder name `it` could be confused with Information Technology.
Using `ita` and `eng` is explicit and avoids ambiguity for the intended
technical audience.

---

## 2026-07-18 — Documentation file naming

### Decision

User documentation files use lowercase names separated by hyphens.

Examples:

- `manuale-tecnico.md`
- `manuale-sistemista.md`
- `field-technician-guide.md`
- `system-administrator-guide.md`

Well-known repository files remain uppercase.

### Reason

This convention is readable, predictable and portable across Windows and
case-sensitive operating systems.

---

## 2026-07-18 — Documentation conventions

### Decision

Every user document begins with:

- title;
- document version;
- compatible software version;
- last update date;
- table of contents.

Documentation is developed incrementally. A complete outline is created first,
then sections are written and reviewed.

An unfinished section contains:

```markdown
*Da completare.*
```

The following standard callouts are used:

```markdown
> **Nota**
>
> Testo.
```

```markdown
> **Attenzione**
>
> Testo.
```

```markdown
> **Suggerimento**
>
> Testo.
```

### Reason

A consistent editorial style improves readability, simplifies translation and
makes documents easier to maintain.

---

## 2026-07-18 — Update checking architecture

### Decision

Maintenance Toolkit will provide a **Cerca aggiornamenti** menu entry.

The first implementation will check the latest available version and offer to
open the official download page. Automatic replacement of local files is
deferred until the manual process is stable.

A small remote manifest hosted on kraugh.it is preferred over hard-coding
release data in the Toolkit.

### Reason

A remote manifest allows version, release date, download location and advisory
messages to change without modifying the local program.

---

## 2026-07-18 — Distribution analytics

### Decision

Public download links on kraugh.it may redirect to GitHub release assets while
recording technical download information per version.

The planned private statistics include timestamp, requested version, source IP,
user agent and referrer. Downloads performed for testing by the author must be
identifiable and excludable from aggregate statistics.

### Reason

Version-specific download statistics help evaluate adoption, update continuity
and the effectiveness of documentation and publication channels.
