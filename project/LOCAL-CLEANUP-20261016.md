# Local test artifact retirement — 16 October 2026

## Italiano

Inventario in sola lettura, nessuna nuova manutenzione, installazione o prova SYSTEM. La [sintesi strutturata](CLEANUP-EVIDENCE-20261016.json) conserva nomi delle cartelle, dimensioni, esiti, conteggi e codici presenti nei risultati originali, con SHA-256 delle fonti. Non contiene snapshot di configurazione, XML dei task, credenziali o log integrali. Non trasforma fallimenti intermedi in successi. I resoconti [4.1.2 finale](MT-4.1.2-RELEASE-VERIFICATION.md), [candidato R01](MT-4.1.2-LOCAL-CANDIDATE.md), [piloti privati](MT-4.1-VM-PILOT-20261015.md) e [accettazione #28](ISSUE-28-ACCEPTANCE-20261016.md) restano le spiegazioni dei risultati e dei limiti.

### Evidenze consolidate

- R02 finale: aggregato `Passed`, 17 controlli nella fase 4.0.6 e 45 nella fase 4.1.1; tre codici MSI 0 nel completamento, autotest ZIP/MSI 0. Il primo writer era fallito per un conflitto di accesso al file; il completamento verifica dati, consenso, task, pulizia e assenza di riavvio. Non fu eseguita manutenzione. Gli hash dei pacchetti finali restano nel resoconto della release.
- I risultati precedenti 4.1.1/R01 e i piloti privati conservano il proprio stato originale nella sintesi. Un risultato privato `msi-final-result.json` è `Failed`: l'asserzione del driver sulla concorrenza MSI non fu soddisfatta. Non è il risultato aggregato finale della 4.1.2.
- I due log MSI in `C:\Temp` del 9 ottobre riportano `MainEngineThread is returning 0`, rispettivamente installazione 16:49:42 e disinstallazione 16:50:56 della 4.0.4. È evidenza storica del log, non una nuova prova né un risultato della 4.1.2.
- Le bozze issue in `C:\Temp` sono checkpoint storici: #25 richiedeva ancora audit dei prerequisiti/servizi; #26 procedura GPO completa e prova pulita; #27 menu ancora assente nella 4.0.4; #29 ripristino predefinito e coerenza codici ancora da verificare; #30 copertura hardware differita. I checkpoint del 5 ottobre riportavano scansione DCU SYSTEM senza applicazione, BIOS soltanto rilevato e NVIDIA soltanto analisi. Non chiudono le issue e non dimostrano una nuova prova odierna. Le fonti temporanee sono attribuite ai checkpoint, non a osservazioni indipendenti di questo inventario.

### Eliminabili manualmente dopo questa consolidazione

In `C:\ProgramData`, soltanto le undici cartelle indicate come `removable-after-document-review` nella sintesi JSON: tutte quelle inventariate `MaintenanceToolkit-411-InstallTest-*`, `MaintenanceToolkit-412-InstallTest-*`, `MaintenanceToolkit-412-R02-*` e i quattro `MaintenanceToolkit-Pilot-*`. L'elenco JSON riporta i nomi esatti, non una regola di cancellazione con wildcard. Nessun task inventariato punta a queste cartelle; il controllo processi ha trovato soltanto il comando di inventario stesso. Ripetere il controllo prima di una cancellazione differita. Eliminare queste copie ritira le installazioni isolate e gli snapshot privati, non l'installazione operativa in Program Files. I dati grezzi non saranno più disponibili per ulteriori analisi forensi; resta il resoconto anonimizzato.

```text
C:\ProgramData\MaintenanceToolkit-411-InstallTest-20261016-075607
C:\ProgramData\MaintenanceToolkit-412-InstallTest-20261016-090238
C:\ProgramData\MaintenanceToolkit-412-InstallTest-20261016-090829-resume
C:\ProgramData\MaintenanceToolkit-412-InstallTest-20261016-090927-bootstrap
C:\ProgramData\MaintenanceToolkit-412-InstallTest-20261016-091131-from411
C:\ProgramData\MaintenanceToolkit-412-R02-InstallTest-20261016-093414
C:\ProgramData\MaintenanceToolkit-412-R02-Resume-20261016-093939
C:\ProgramData\MaintenanceToolkit-Pilot-20261015-175925-21af8173
C:\ProgramData\MaintenanceToolkit-Pilot-20261015-175925-21af8173-R02
C:\ProgramData\MaintenanceToolkit-Pilot-20261015-180705-9fde84c3-R03
C:\ProgramData\MaintenanceToolkit-Pilot-20261015-185059-cf9a6d0b-R04
```

Nel temporaneo utente (`%LOCALAPPDATA%\Temp`):

```text
MT-4.0.3-dev.5-Pilot
MT-DCU-BIOS-Scan-20260921-120759
MT-GitHub-Check
MT-GitHub-SV-FinalCheck
```

Sono payload storici estratti e copie di verifica; la cartella DCU è vuota e non conserva una prova BIOS. Non sono l'installazione corrente. I due file `MT-inventory-finalization-test.json` e `MT-inventory-finalization-error-test.json` contengono snapshot inventario: conservarli per ora, finché l'esito specifico del relativo test non è stato ricostruito; il nome da solo non dimostra il risultato.

In `C:\Temp`:

```text
MT-Install-4_0_4-20261009-164940-d2c3771a.log
MT-Uninstall-4_0_4-20261009-165053-5a4dcb90.log
MT-Issue-25-20261009-1842-8c03b578.md
MT-Issue-26-20261009-1842-8c03b578.md
MT-Issue-27-20261009-1842-8c03b578.md
MT-Issue-29-20261009-1839-de59899a.md
MT-Issue-30-20261009-1839-de59899a.md
MT-Issue29-06948c13c66d4235b9b21b8320748754.md
MT-Issue30-955ac82eb7a04754b77600c61742acf3.md
```

### Conservare / esclusioni e limiti

- `C:\ProgramData\Kraugh`: accesso negato durante l'inventario; può contenere stato operativo protetto. Nessuna autorizzazione a svuotarlo deriva da questo elenco.
- `C:\ProgramData\MaintenanceToolkit-ProtectedTest-20261014-141042-beed9ed1`: conserva anche log recenti di sessioni interattive; non ancora classificata come semplice copia sacrificabile.
- Downloads: `software.tgz` e `api.tgz` sono sorgenti forniti dall'hosting. Non eliminati: non è ancora verificata la recuperabilità completa da GitHub del contenuto del sito e delle API. `desktop.ini` resta un file di sistema.
- Desktop: collegamento/script di rete e archivi DMT appartengono ad altri ambiti. Non toccati. `C:\Temp\PigeonCheck-*.json` riguarda un altro prodotto e resta escluso.
- Nessun elemento `MT-*` trovato nella ricerca mirata in `C:\Windows\Temp`. Non è un censimento di tutti i file temporanei del sistema. Le altre applicazioni, altri profili utente, cestino e aree protette non sono dichiarati puliti.
- Nessuna cancellazione effettuata da questa fase. I precedenti blocchi automatici di cancellazione restano rispettati. Nessun commit/push: questi documenti sono per ora locali e devono essere salvati su GitHub con un successivo passaggio autorizzato per renderli recuperabili da remoto.

Questa decisione di ritiro sostituisce l'obbligo locale di mantenere tutte le cartelle grezze elencate nei precedenti resoconti, soltanto per le risorse esplicitamente classificate eliminabili qui. Non cambia i risultati storici né autorizza la rimozione dei pacchetti pubblicati.

## English

Read-only retirement review, not a new installation, maintenance or SYSTEM test. The accompanying JSON preserves original result statuses, recorded counts/codes and SHA-256 source identifiers without private snapshots. Historical failures remain failures; final R02 acceptance remains distinct from earlier pilots. Existing release/pilot/issue reports explain the scope and limitations.

Only the eleven ProgramData directories explicitly marked removable in JSON, the four named user-temp directories and the nine listed C:\Temp files are eligible for manual retirement. Recheck for running processes/task references before delayed deletion. Raw private evidence will no longer be available; anonymized summaries remain. Operational protected state, the recent ProtectedTest installation, hosting downloads, unrelated projects and unresolved inventory-test snapshots remain excluded. No deletion, commit or push was performed. These local documents require a separately authorized Git checkpoint and push before remote recoverability is established. This retirement decision supersedes earlier blanket retention statements only for the explicitly classified resources; public packages remain unchanged.
