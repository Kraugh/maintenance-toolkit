# Changelog

All notable released changes to Maintenance Toolkit are documented here.

Repository-only documentation changes may be committed without changing the
software version.

## 4.0.0 — 17 August 2026

### Stable release

- promoted Maintenance Toolkit 4.0.0 from release candidate to stable;
- added the Maintenance Toolkit application icon to the native launcher;
- digitally signed `MaintenanceToolkit.exe` using an Authenticode code-signing certificate issued by Certum;
- added a trusted RFC 3161 timestamp to the signed executable;
- verified the final signed executable against the Windows Authenticode trust chain;
- retained the 4.0.0-rc.2 functionality and validated release layout without introducing new feature subsystems.

## 4.0.0-rc.2 — 10 August 2026

### Release candidate 2

- added the native `MaintenanceToolkit.exe` launcher as the recommended entry point;
- retained `Avvia_Manutenzione.bat` as a compatibility fallback for restricted environments;
- added a bilingual EN/IT startup guide in the distribution root;
- prevents system sleep while Maintenance Toolkit is running without forcing the display to remain on;
- validated Network Diagnostics with no VPN, OpenVPN DCO, FortiClient, and both VPNs active behind an external Hyper-V vSwitch;
- refined VPN DNS wording so detected DNS servers are not over-attributed to a specific VPN client;
- kept `external`, `logs`, and `reports` out of public release packages;
- prepared the release layout for Authenticode code signing.

## 4.0.0-rc.1 — 7 August 2026

### First Maintenance Toolkit 4.0 release candidate

- integrated the bilingual MT4 runtime while retaining validated legacy
  maintenance modules;
- integrated native Network Diagnostics into the MT menu;
- added topology-aware physical/virtual interface analysis;
- added route, gateway, DNS, DHCP, APIPA, MTU, metric and link-speed health
  diagnostics;
- added configurable DNS resolution probing;
- added automatic network-health rules with concise severity summaries;
- added Advanced VPN Diagnostics for active tunnel addresses, DNS, routes,
  split/full-tunnel classification and common VPN technology identification;
- added TXT technical network reports with correlated JSON topology and rule
  artifacts;
- retained optional Ookla Speedtest integration without bundling the external
  executable in the public package;
- added Foundation AUTOTEST and legacy-compatibility validation;
- normalized repository line endings and preserved UTF-8 BOM requirements for
  Windows PowerShell 5.1;
- strengthened release packaging with version-consistency, required-file and
  excluded-directory validation;
- added an explicit RC1 release gate.
- refreshed public documentation for MT4 RC1, including Smart App Control and long-operation notes.

### Validation completed before RC1

- Windows 11 physical system: Network Quick Diagnosis and Technical Report;
- Windows 10 22H2 / PowerShell 5.1 physical system: Network Quick Diagnosis,
  DNS health and Technical Report;
- Hyper-V Windows 11 guest: virtual-first topology handling;
- no-VPN systems: clean informational VPN state;
- Foundation AUTOTEST: 0 errors / 0 warnings on validated builds.

### RC validation still required

- complete Toolkit smoke test from the extracted candidate package;
- representative legacy maintenance module on Windows 10 and Windows 11;
- real connected VPN validation when an appropriate test environment is
  available.

No new feature subsystem is accepted during RC validation. Only
release-blocking fixes are allowed.

## 3.7.2 — 1 August 2026

### Highlights

- improved long-running operation feedback with a single live status line;
- always displayed elapsed time and used real progress values only;
- added real SFC and Winget progress when available;
- used a spinner when progress could not be measured honestly;
- removed the persistent PowerShell connectivity progress bar;
- made the HTTPS test destination and purpose explicit;
- improved Microsoft Update activity feedback;
- fixed native process exit-code handling on Windows PowerShell 5.1;
- fixed Winget argument preservation and partial-failure classification;
- fixed DISM and SFC output handling;
- fixed SFC clean-result recognition on Windows 10;
- restored reliable return to the interactive menu;
- reorganized project documentation under `project/`;
- added the documented development workflow;
- renamed menu states to `Automatico` and `Manuale`;
- renamed `Pulizia TEMP` to `Pulizia file temporanei`;
- added automatic release-package generation tooling.

### Validation

Validated on Windows 11 and Windows 10.

## 3.7.2-rc.6 — 1 August 2026

### Final candidate integration

- integrated the validated connectivity module patch;
- fixed formatting of the visible HTTPS destination message;
- integrated the validated Microsoft Update status-script patch;
- fixed SFC clean-result recognition on Windows 10 by reading native output as Unicode;
- added `project/DEVELOPMENT_WORKFLOW.md`;
- retained `kraugh_it/version.json` on stable version 3.7.1 until final promotion;
- performed additional static checks for version consistency, unsafe host/port
  interpolation, literal format placeholders and obsolete `Test-NetConnection` usage.

## 3.7.2-rc.5 — 1 August 2026

### Connectivity and Microsoft Update debugging

- fixed ambiguous PowerShell interpolation in connectivity messages;
- replaced the inline Microsoft Update status command with a temporary script
  launched through `-File` for Windows PowerShell 5.1 compatibility.

## 3.7.2-rc.4 — 1 August 2026

### User-interface refinements

- refreshed long-running operation status once per second on a single console line;
- always displayed elapsed time during long operations;
- displayed real SFC or Winget progress when available;
- used an honest spinner when real progress was unavailable;
- avoided invented percentages and estimated remaining times;
- reduced repetitive heartbeat entries in technical logs;
- added discreet reminders for exceptionally long operations;
- made the HTTPS connectivity-test destination and purpose visible.

## 3.7.2-rc.3 — 31 July 2026

### Critical regression fixes

- removed unsafe PowerShell event handlers from the process wrapper;
- restored reliable module completion and return to the interactive menu;
- replaced `Test-NetConnection` with an explicit TCP connectivity test;
- eliminated the persistent blue PowerShell progress bar.

## 3.7.2-rc.2 — 31 July 2026

### Process-wrapper fixes

- improved native exit-code handling;
- preserved Winget arguments;
- prevented unreadable DISM output from flooding the console;
- retained readable SFC progress;
- restored full `Automatico` and `Manuale` menu labels;
- renamed `Pulizia TEMP` to `Pulizia file temporanei`.

## 3.7.2-rc.1 — 31 July 2026

### Repository, documentation and initial UX work

- moved project-management documents under `project/`;
- added the sprint document;
- made English the primary repository language;
- preserved Italian documentation;
- removed duplicated TXT documentation from the repository;
- added release-package generation tooling;
- introduced improved feedback for long-running operations.

## 3.7.1 — 18 luglio 2026

### Miglioramenti di usabilità

- aggiunti messaggi chiari prima dell'installazione degli aggiornamenti Winget;
- indicato che l'operazione può richiedere diversi minuti sui computer non aggiornati da tempo;
- indicato che la comparsa delle finestre dei singoli installer è normale;
- aggiunto un messaggio al termine di ogni passaggio Winget;
- nessuna modifica alla logica di installazione degli aggiornamenti.

## 3.7.0 — 18 luglio 2026

### Nuove funzionalità

- aggiunta la voce di menu **Cerca aggiornamenti**;
- aggiunto il controllo della versione tramite `kraugh_it/version.json` pubblicato su kraugh.it;
- aggiunti messaggi della papera in italiano per esiti e anomalie del controllo aggiornamenti;
- aggiunta la voce di menu **Autotest del Toolkit**;
- aggiunti i parametri da riga di comando `-SelfTest` e `-CheckUpdates`;
- l'autotest verifica file richiesti, moduli, sintassi PowerShell, configurazione INI, manifest ed endpoint remoto;
- il mancato accesso al server degli aggiornamenti non impedisce l'uso del Toolkit.

## 3.0.6.2 — 18 luglio 2026

### Correzioni

- corretto l'errore di formattazione del modulo **Pulizia TEMP**;
- aggiunto `temp_non_eliminati.txt` con percorso e motivo degli elementi
  non eliminati;
- nessun'altra modifica alla logica del Toolkit.

## 3.0.6.1 — 17 luglio 2026

### Correzioni

- corretto il lock di `rete.txt` durante l'esecuzione da Dropbox o share;
- il report rete viene costruito interamente in memoria;
- `rete.txt` viene scritto una sola volta mediante il logger robusto;
- nessun'altra modifica alla logica del Toolkit.

## 3.0.6 — 17 luglio 2026

### Robustezza e usabilità

- introdotto un logger con retry e condivisione `ReadWrite`;
- i lock temporanei dei log cumulativi non interrompono il Toolkit;
- aggiunto heartbeat durante DISM e SFC;
- migliorata la classificazione degli esiti SFC;
- uniformata la dicitura **Crea punto di ripristino**;
- aggiunto il dettaglio degli elementi TEMP non eliminati;
- aggiunto il riepilogo dei controlli eseguiti e non eseguiti.

## 3.0.5.1 — 17 luglio 2026

### Correzioni

- corretta l'inizializzazione anticipata dei percorsi di log;
- i log vengono inizializzati dopo la creazione della sessione;
- il BAT mantiene aperta la finestra in caso di errore iniziale;
- nessuna modifica alla logica operativa dei moduli.

## 3.0.5 — 17 luglio 2026

### Gestione dei log

- aggiunta una cartella log distinta per ogni computer;
- adottato il formato `YYYYMMDD-HHMMSS_NOME-PC` per le sessioni;
- separati per macchina i log cumulativi;
- la voce **Apri cartella log** apre i log del computer corrente;
- la rotazione agisce soltanto sulle sessioni del computer corrente.

## 3.0.4.1 — 17 luglio 2026

### Pubblicazione

- aggiunta la licenza MIT;
- aggiunti `ABOUT.txt`, `README.md`, `project/roadmap.md` e `project/backlog.md`;
- aggiunta la voce **Informazioni** nel menu;
- aggiornata la documentazione della versione;
- nessuna modifica alla logica operativa della 3.0.4.

## 3.0.4 — 17 luglio 2026

### Correzioni e usabilità

- corretto `Test-Path` nel modulo Pulizia TEMP;
- rinominato **Punto di ripristino** in **Crea punto di ripristino**;
- corretto l'elenco dei moduli selezionati nei log;
- aggiunto il ritorno al menu dopo ogni esecuzione;
- rimossa la pausa obbligatoria dal normale flusso del BAT;
- ogni operazione avviata dal menu crea una sessione di log distinta.

## 3.0.3 — 17 luglio 2026

### Configurazione e correzioni

- DISM RestoreHealth e SFC Scannow disattivati per impostazione predefinita;
- entrambi i moduli restano disponibili per l'esecuzione manuale;
- corretto Winget quando aggiorna sé stesso o App Installer;
- aggiunto un secondo passaggio automatico di Winget;
- riscritto il modulo Microsoft Update;
- eliminata la collisione tra la collection `$I` e l'indice `$i`;
- corretto `Test-Path` nei moduli OEM;
- SIW escluso temporaneamente dal menu e dalla configurazione;
- migliorata la gestione della codifica SFC;
- migliorato il report dei dischi interni e rimovibili;
- aggiunta la firma del progetto.

## 3.0.1

### Correzioni

- rimosso il BOM da `Avvia_Manutenzione.bat`;
- corretta l'interpolazione della variabile `Label` in `00_common.ps1`.

## 3.0.0

- prima versione interattiva e modulare.
