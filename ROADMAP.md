# Roadmap

> La roadmap contiene soltanto obiettivi che il progetto ha deciso di
> realizzare. L'ordine delle sezioni non rappresenta necessariamente
> l'ordine cronologico di implementazione.

---

## Serie 3.0.6.x — consolidamento del core

- [x] Report rete robusto durante l'esecuzione da Dropbox e share
- [x] Correzione e dettaglio della Pulizia TEMP
- [ ] Classificazione definitiva degli esiti SFC
- [ ] Heartbeat rifinito per DISM e SFC
- [ ] Riepilogo rapido della sessione

---

## Serie 3.0.7 — esecuzione e test da riga di comando

- [ ] Modalità non interattiva `-RunAll`
- [ ] Modalità diagnostica `-Debug`
- [ ] Test completo `-TestAll`
- [ ] Test mirato alle novità della release `-TestRelease`
- [ ] Logging diagnostico più verboso solo dove utile
- [ ] Prima integrazione con Task Scheduler e Group Policy

---

## Distribuzione centralizzata

- [ ] Esecuzione come `SYSTEM`
- [ ] Distribuzione tramite Task Scheduler
- [ ] Distribuzione tramite Group Policy
- [ ] Test di Winget in contesto `SYSTEM`
- [ ] Raccolta e centralizzazione dei log
- [ ] Verifica da share SMB
- [ ] Verifica da chiavetta USB

---

## Compatibilità

- [x] Test su Windows 11 25H2
- [x] Test da cartella locale
- [x] Test da Dropbox
- [ ] Test su Windows 10 22H2
- [ ] Test con account standard ed elevazione UAC
- [ ] Matrice di compatibilità documentata

---

## Aggiornamenti del Toolkit

- [ ] File di versione unico
- [ ] Voce di menu **Cerca aggiornamenti**
- [ ] Riorganizzazione del riepilogo finale in sezioni (Moduli eseguiti, Avvisi, Errori e Percorso dei log)
- [ ] Verifica della versione più recente disponibile
- [ ] Apertura della pagina ufficiale di download
- [ ] Manifest remoto della release su kraugh.it
- [ ] Sistema di aggiornamento automatico, solo dopo il consolidamento
  della verifica manuale

---

## Documentazione

- [x] Repository GitHub pubblico
- [x] Documentazione in Markdown
- [x] Convenzioni editoriali
- [x] Struttura multilingua `docs/ita` e `docs/eng`
- [ ] Completamento della Guida Tecnico in italiano
- [ ] Completamento della Guida Sistemista in italiano
- [ ] Traduzione inglese delle guide
- [ ] Screenshot dell'interfaccia
- [ ] Guida GPO passo-passo
- [ ] Guida Task Scheduler passo-passo
- [ ] Manuale PDF con spiegazioni e screenshot

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

- [ ] Prima release GitHub completa di ZIP
- [ ] Pagina dedicata su kraugh.it
- [ ] Collegamenti a repository, documentazione e ultima release
- [ ] Storico delle release sul sito
- [ ] Video introduttivo
- [ ] Video guida completa
- [ ] Video dedicato alla distribuzione tramite GPO

---

## Statistiche di distribuzione

- [ ] Download mediato da kraugh.it
- [ ] Conteggio dei download per versione
- [ ] Dashboard amministrativa privata
- [ ] Registrazione tecnica di timestamp, versione, IP, user agent e referrer
- [ ] Esclusione identificabile dei download di test dell'autore
- [ ] Collegamento finale alle release ospitate su GitHub

---

## Evoluzioni future approvate

- [ ] Firma digitale degli script
- [ ] Localizzazione multilingua dell'interfaccia
- [ ] Pacchetto MSI
- [ ] Versione eseguibile
