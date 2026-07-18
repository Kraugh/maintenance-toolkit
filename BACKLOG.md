## In lavorazione

Queste attività sono già state approvate e sono attualmente in corso di sviluppo.

- Completamento della documentazione tecnica italiana.
- Definizione dello standard documentale del progetto.
- Prima pubblicazione completa del repository GitHub.

---

# Backlog

Idee e miglioramenti non ancora pianificati.

Una voce viene spostata nella `ROADMAP.md` soltanto quando viene approvata
come obiettivo concreto. Una volta completata, viene registrata nel
`CHANGELOG.md`.

---

## Must Have

Funzionalità considerate necessarie prima di una prima release stabile
destinata a una distribuzione ampia.

- Configurazione dei moduli direttamente dal menu
- Ripristino della configurazione predefinita
- Classificazione affidabile degli esiti DISM e SFC
- Test su Windows 10 e Windows 11
- Test da USB, Dropbox e share SMB
- Documentazione italiana per tecnico e sistemista

---

## Should Have

Funzionalità importanti, ma non bloccanti per il core operativo.

- Riduzione delle percentuali duplicate di DISM e SFC
- Migliore normalizzazione della codifica di Winget
- Esportazione e importazione della configurazione
- Report HTML avanzato
- Raccolta selettiva dei log di sistema
- Analisi della cronologia di Windows Update
- Integrazione SMART avanzata
- SIW come modulo opzionale
- Integrazione estesa con Sysinternals
- Voce di menu "Cerca aggiornamenti"
- Verifica della versione disponibile
- Apertura automatica della pagina ufficiale della release

---

## Nice To Have

Miglioramenti utili o caratterizzanti, da valutare dopo la stabilizzazione.

- Tema ASCII ispirato alle interfacce degli anni Novanta
- Tema opzionale `Classic311`
- Mascotte o identità grafica del progetto
- Pillole di saggezza del sistemista nei log
- Promemoria discreti per idratazione e pause
- Commenti ed Easter egg nei sorgenti
- Segnale sonoro opzionale al termine delle operazioni

---

## Parking Lot

Idee valide, ma appartenenti a progetti futuri o non ancora sufficientemente
definite.

### Sweep — futuro secondo repository GitHub

Utility indipendente per la pulizia controllata degli alberi di directory.

Ipotesi iniziali:

- scansione ricorsiva di una directory;
- estensioni e nomi file configurabili;
- modalità `DryRun`;
- esclusioni configurabili;
- creazione preventiva di un archivio ZIP;
- conservazione della struttura relativa dei file;
- log con percorso originale di ogni elemento archiviato;
- cancellazione soltanto dopo la creazione e verifica dell'archivio.

### Ecosistema Kraugh Open Source

- convenzioni condivise tra repository;
- struttura documentale comune;
- stile uniforme per README, changelog, roadmap e release;
- eventuale mascotte comune o coordinata.
