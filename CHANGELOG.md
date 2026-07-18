# Changelog

All notable released changes to Maintenance Toolkit are documented here.

Repository-only documentation changes may be committed without changing the
software version.

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
- aggiunti `ABOUT.txt`, `README.md`, `ROADMAP.md` e `BACKLOG.md`;
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
