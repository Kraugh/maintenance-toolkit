# Development process / Processo di sviluppo

Maintenance Toolkit is developed through approximately two-week development sprints.

Maintenance Toolkit viene sviluppato tramite sprint di circa due settimane.

During each sprint, bug reports, feature requests and user feedback are collected.  
At the end of the sprint, the open issues are reviewed and the work for the next release is selected.

Durante ogni sprint vengono raccolti bug report, richieste di funzionalità e feedback degli utenti.  
Al termine dello sprint, le issue aperte vengono esaminate e viene selezionato il lavoro per la release successiva.

Release dates are intentionally not fixed. Quality takes priority over speed.

Le date di rilascio non sono prefissate. La qualità ha priorità sulla velocità.

---

# Roadmap

> La roadmap contiene soltanto obiettivi che il progetto ha deciso di realizzare.
> L'ordine delle sezioni non rappresenta necessariamente l'ordine cronologico
> di implementazione.

## Stato attuale

- [x] Release stabile pubblica **3.7.1**
- [x] Repository GitHub pubblico
- [x] Pacchetto ZIP allegato alla release
- [x] Manuale tecnico italiano con screenshot
- [x] Test su Windows 11
- [x] Test su Windows 10 22H2
- [x] Test da cartella locale
- [x] Test da Dropbox
- [x] Controllo remoto della versione tramite kraugh.it

---

## Prossime release 3.7.x — consolidamento

- [ ] Migliorare il feedback durante le operazioni Winget di lunga durata
- [ ] Mostrare messaggi periodici senza alterare gli argomenti passati a Winget
- [ ] Interpretare in modo più chiaro gli esiti parziali di Winget
- [ ] Tradurre in messaggi leggibili i codici Microsoft Update conosciuti
- [ ] Chiarire nel menu la differenza tra moduli automatici e manuali
- [ ] Valutare una denominazione più chiara per l'autotest
- [ ] Classificazione definitiva degli esiti SFC
- [ ] Heartbeat rifinito per DISM e SFC
- [ ] Riepilogo rapido e più leggibile della sessione

---

## Internazionalizzazione

- [ ] Separare le stringhe dell'interfaccia dalla logica del Toolkit
- [ ] Creare risorse linguistiche italiane e inglesi
- [ ] Selezionare la lingua all'avvio
- [ ] Cambiare lingua dal menu
- [ ] Memorizzare la preferenza nel file INI
- [ ] Usare l'inglese come fallback per le stringhe mancanti
- [ ] Completare la documentazione inglese

---

## Esecuzione automatizzata

- [x] Modalità non interattiva `-RunAll`
- [ ] Modalità diagnostica `-Debug`
- [x] Autotest da riga di comando `-SelfTest`
- [ ] Test mirato alle novità della release `-TestRelease`
- [ ] Logging diagnostico più verboso solo dove utile

---

## Distribuzione centralizzata

- [x] Guida per amministratori di sistema
- [x] Guida Group Policy passo-passo
- [x] Guida Task Scheduler passo-passo
- [ ] Esecuzione come `SYSTEM`
- [ ] Test di Winget in contesto `SYSTEM`
- [ ] Raccolta e centralizzazione dei log
- [ ] Verifica da share SMB
- [ ] Verifica da chiavetta USB

---

## Aggiornamenti del Toolkit

- [x] File di versione unico
- [x] Voce di menu **Cerca aggiornamenti**
- [x] Verifica della versione più recente disponibile
- [x] Manifest remoto della release su kraugh.it
- [ ] Apertura della pagina ufficiale di download
- [ ] Riorganizzazione del riepilogo finale in sezioni
- [ ] Sistema di aggiornamento automatico, solo dopo il consolidamento della verifica manuale

---

## Diagnostica avanzata

- [ ] Cronologia Windows Update
- [ ] Raccolta selettiva degli eventi di Windows
- [ ] Analisi di `CBS.log`
- [ ] Inventario SMART avanzato
- [ ] Report HTML avanzato
- [ ] Integrazione opzionale con Sysinternals

---

## OEM

- [ ] Migliorare l'integrazione HP
- [ ] Migliorare l'integrazione Dell
- [ ] Aggiungere il supporto Lenovo
- [ ] Separare chiaramente aggiornamenti, driver e firmware OEM

---

## Pubblicazione e distribuzione

- [x] Prima release GitHub completa di ZIP
- [ ] Pagina dedicata su kraugh.it
- [ ] Collegamenti a repository, documentazione e ultima release
- [ ] Storico delle release sul sito
- [ ] Video introduttivo
- [ ] Video guida completa
- [ ] Video dedicato alla distribuzione tramite GPO

---

## Evoluzioni future approvate

- [ ] Firma digitale degli script
- [ ] Localizzazione multilingua dell'interfaccia
