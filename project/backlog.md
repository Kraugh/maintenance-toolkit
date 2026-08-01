# Backlog

This document collects ideas, improvements and possible future developments.

Questo documento raccoglie idee, miglioramenti e possibili sviluppi futuri.

Items listed here are not scheduled. Only GitHub Issues selected during Sprint Planning become part of a future release.

Le voci presenti non sono pianificate. Soltanto le GitHub Issue selezionate durante lo Sprint Planning entrano in una futura release.

---

## User experience / Esperienza utente

- Chiarire la differenza tra moduli inclusi nell'esecuzione completa e moduli disponibili solo manualmente
- Mostrare un heartbeat durante operazioni lunghe
- Registrare l'heartbeat anche nei log
- Migliorare i messaggi Winget in caso di successo parziale
- Tradurre in testo comprensibile i codici Microsoft Update conosciuti
- Valutare la denominazione pubblica dell'autotest
- Riorganizzare il riepilogo finale in sezioni più leggibili
- Ridurre le percentuali duplicate mostrate da DISM e SFC

---

## Internationalization / Internazionalizzazione

- Separare tutte le stringhe dalla logica del Toolkit
- Creare file di lingua italiano e inglese
- Consentire la selezione della lingua all'avvio
- Consentire il cambio lingua dal menu
- Salvare la lingua scelta nel file INI
- Usare l'inglese come fallback
- Tradurre menu, messaggi, riepiloghi e testi destinati all'utente
- Completare la documentazione inglese

---

## Configuration / Configurazione

- Configurare i moduli direttamente dal menu
- Ripristinare la configurazione predefinita
- Esportare e importare la configurazione

---

## Diagnostics / Diagnostica

- Classificare in modo affidabile gli esiti DISM e SFC
- Creare un report HTML avanzato
- Raccogliere selettivamente i log di sistema
- Analizzare la cronologia di Windows Update
- Integrare informazioni SMART avanzate
- Valutare SIW come modulo opzionale
- Estendere l'integrazione con Sysinternals

---

## Enterprise deployment / Distribuzione centralizzata

- Scrivere una guida per amministratori di sistema
- Documentare la distribuzione tramite Group Policy
- Documentare la distribuzione tramite Task Scheduler
- Testare l'esecuzione in contesto `SYSTEM`
- Testare Winget in contesto `SYSTEM`
- Centralizzare i log su una share
- Verificare il funzionamento da share SMB

---

## Nice to have / Miglioramenti facoltativi

- Tema ASCII ispirato alle interfacce degli anni Novanta
- Tema opzionale `Classic311`
- Mascotte o identità grafica del progetto
- Pillole di saggezza del sistemista nei log
- Promemoria discreti per idratazione e pause
- Commenti ed Easter egg nei sorgenti
- Segnale sonoro opzionale al termine delle operazioni
- File centralizzato e localizzabile per i messaggi della papera (`duck-messages`)
- Messaggi della papera coerenti per completamento, avvisi ed errori

---

## Parking lot / Idee per progetti futuri

### Sweep — future standalone repository / futuro repository indipendente

Utility per la pulizia controllata degli alberi di directory.

Ipotesi iniziali:

- scansione ricorsiva di una directory;
- estensioni e nomi file configurabili;
- modalità `DryRun`;
- esclusioni configurabili;
- creazione preventiva di un archivio ZIP;
- conservazione della struttura relativa dei file;
- manifest con percorso originale, hash, dimensione e data;
- log con percorso originale di ogni elemento archiviato;
- cancellazione soltanto dopo la creazione e la verifica dell'archivio;
- possibilità di ripristino nella posizione originale.

### Kraugh Open Source ecosystem / Ecosistema Kraugh Open Source

- convenzioni condivise tra repository;
- struttura documentale comune;
- stile uniforme per README, changelog, roadmap e release;
- identità grafica coordinata;
- processo di sviluppo basato su sprint e issue.
