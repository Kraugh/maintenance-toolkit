# Istruzioni operative — Maintenance Toolkit

## Ambito e fonti di progetto

- Lavora nel repository selezionato. Leggi `project/DEVELOPMENT_WORKFLOW.md`, le decisioni pertinenti in `project/decisions.md`, `project/roadmap.md`, `CONTRIBUTING.md` e `docs/LOCALIZATION.md` prima di intervenire. Conserva il contesto storico di sprint e audit.
- Procedi per fasi, con modifiche piccole e mirate all'ambito autorizzato. Prima di implementare, definisci obiettivo e verifiche e riesamina le issue pertinenti; roadmap, backlog e issue mantengono i rispettivi ruoli descritti nel workflow.
- Riporta risultati verificati, fonte dell'evidenza e limiti. Distingui prove eseguite, risultati riferiti dall'utente e analisi statica; non estendere una prova pilota a garanzie generali.
- Cambiamenti strutturali, contratti pubblici, nuovi percorsi di output e interfacce tra progetti richiedono una decisione architetturale esplicita prima dell'implementazione.

## Strumenti, build e distribuzione

- Usa strumenti e dipendenze già disponibili. Installare o acquisire nuove dipendenze richiede autorizzazione, anche quando un helper di build lo fa automaticamente.
- Non cambiare percorsi o procedure di build e distribuzione senza segnalarlo prima.
- Mantieni le procedure canoniche: `launcher/build-launcher.cmd` per il launcher, `packaging/msi/Build-MSI.ps1` per MSI (WiX e Util extension 5.0.2), `tools/create-release.ps1` per ZIP.
- Mantieni gli output nel repository: `MaintenanceToolkit.exe`, intermedi in `launcher/build`, MSI in `packaging/msi/out`, ZIP e checksum in `dist`, staging temporaneo in `dist/staging`. La firma Authenticode con timestamp di launcher e MSI precede il calcolo dei checksum finali e il packaging che li include.
- Non sovrascrivere silenziosamente pacchetti esistenti. Non sostituire artefatti già pubblicati con byte diversi sotto lo stesso nome/versione; usa una successiva distribuzione identificata correttamente.

## Git e pubblicazione

- Conserva le modifiche locali prima di sincronizzare; verifica branch, stato, HEAD e upstream. Niente reset distruttivi o force push.
- Non creare release o tag né pubblicare senza autorizzazione. Esegui commit e push soltanto nell'ambito autorizzato della sessione.
- Le pubblicazioni sono vietate dal lunedì al venerdì nelle fasce 08:30–12:30 e 13:30–17:30, fuso `Europe/Rome`, salvo deroga esplicita per la sessione. Verifica giorno e ora locali prima di pubblicare; una generica autorizzazione alla pubblicazione non costituisce deroga alle fasce.
- Prima di una release, completa i controlli e il gate documentale previsti dal workflow, incluso il confronto con i sorgenti correnti del sito forniti dall'hosting. Non usare pagine memorizzate come prova del sito distribuito.

## Runtime, sicurezza e documentazione

- Le stringhe dell'interfaccia generate da MT devono risiedere nei JSON `languages`, con fallback inglese e aggiornamento delle risorse supportate. Mantieni identificatori e contratti tecnici indipendenti dalla lingua; non tradurre artificialmente l'output nativo degli strumenti.
- Mantieni documentazione, configurazione, CLI, manifest e comportamento allineati. Conserva come storiche le evidenze di versioni precedenti; non attribuirle alla versione corrente.
- Nessun riavvio automatico. BIOS non automatico: eventuali interventi restano un flusso manuale separato, esplicitamente autorizzato e con le protezioni previste dal progetto. NVIDIA solo analisi, senza download o installazione automatici.
- Le esecuzioni headless, pianificate, GPO e SYSTEM restano non interattive. Preserva i confini tra MT e DMT e non introdurre manutenzione del computer fuori dall'ambito autorizzato.
- Per operazioni lunghe mostra il tempo trascorso; usa percentuali solo se fornite realmente dallo strumento, altrimenti uno spinner. Non inventare progressi o tempi residui.

## File e task temporanei

- Registra nomi e percorsi esatti dei file e task temporanei creati durante il lavoro, così da poterli verificare e rimuovere senza chiedere all'utente di recuperare nomi creati dall'agente.
- Dopo la verifica, rimuovi quelli non più necessari nell'ambito autorizzato, controllando i percorsi prima della rimozione. Conserva gli artefatti necessari alla revisione e segnala quelli mantenuti.
- Artefatti di scambio: nomi univoci con progetto, data e ora `Europe/Rome`, più revisione o altro suffisso quando necessario a evitare collisioni. File interni: nomi canonici, senza data o revisione. Pacchetti pubblici: prodotto e versione, secondo le convenzioni esistenti.

- GitHub e sito pubblicano documentazione, istruzioni e annunci soltanto in italiano e inglese. Comunicare la disponibilita multilingue del runtime, distinguendo lingue validate nella release pubblica e copertura parziale dei candidati; non creare pagine pubbliche nelle altre lingue. Applicare [docs/LOCALIZATION.md](docs/LOCALIZATION.md).
