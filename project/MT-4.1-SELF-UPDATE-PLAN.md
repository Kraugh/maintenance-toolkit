> Current: final 4.1.0 packaging/publication authorized after checks. See [release verification](MT-4.1-RELEASE-VERIFICATION.md). Dated design/pilot sections below preserve historical status.

# MT 4.1 — piano di autoaggiornamento

## Stato sviluppo locale — 15 ottobre 2026

Implementazione sorgenti 4.1.0-dev.3 sul branch feature/4.1-self-update, issue #27/#28 riesaminate. Il successivo chiarimento dell'utente autorizza anche applicazione MSI/ZIP con prove simulate; La firma dei candidati locali e stata successivamente autorizzata e completata; installazioni reali rimangono una fase concordata separata. Nessun push/release. Manifest stabile e pacchetti 4.0.6 invariati.

Implementati menu di pianificazione/preferenze/aggiornamento/lingue, tre modalita pianificate, trigger giornalieri multipli/settimanali/avvio, pubblicazione JSON, precedenze, opt-in protetto fuori dai file MSI, lock, manifest/cataloghi verificati, helper separato, sostituzione/rollback ZIP, applicazione MSI e ripresa consumabile una sola volta. V include la rilevazione, U e R rimossi dal menu. Il recupero transazionale rimane interno; reinstallazione verificata e controllo amministrativo in caso di stato incerto. Languages seleziona sette lingue con scelta persistente e fallback inglese per chiavi mancanti; traduzioni storiche nelle nuove risorse ancora parziali. Certificato ammesso fissato nel verificatore, non nel manifest remoto. Tool di metadati non firma e non pubblica. La versione dev impedisce la creazione accidentale di un MSI pubblico.

117 controlli di regressione passati in Windows PowerShell 5.1, incluse sette selezioni lingua, persistenza e fallback per chiave; regressioni ReleaseBlockers, WingetExceptions e LegacyCompatibility passate nell'incremento precedente. Launcher compilato per il candidato locale senza sostituire l'EXE della radice; Candidato R02 successivamente firmato e verificato: EXE/MSI/catalogo, SHA-256 e timestamp; vedere [evidenze](MT-4.1-LOCAL-VALIDATION.md). Nessun recupero esposto nel menu utente.

Da validare nel pilota: creazione/verifica completa del task reale, esecuzione SYSTEM, share e ACL reali, applicazione MSI e custom action/rollback, preservazione task/eccezioni e interruzioni durante handoff. Ispezione/rimozione/stato del task e condizioni di alimentazione/rete implementati e verificati con API simulate il 15 ottobre; date specifiche di calendario non previste dal wizard. Il checkpoint VM e stato confermato: [sequenza del pilota](MT-4.1-PILOT.md). Vedere le guide locali IT/EN. Le sezioni di proposta sotto conservano il percorso progettuale: le decisioni implementate sono specificate nel nuovo contratto di sviluppo in decisions.md.

## Decisione approvata — 13 ottobre 2026

- Standalone ZIP e MSI non gestito: comando "Aggiorna MT" con conferma; automatismo solo dopo abilitazione esplicita.
- Gestione GPO: rilevazione e segnalazione; installazione affidata alla GPO.
- Gestione sconosciuta: nessuna installazione automatica. La sola appartenenza al dominio non identifica una gestione GPO.
- Nessun riavvio automatico; preservare configurazione, eccezioni e ownership dei task.

## Decisioni aggiuntive approvate — 14 ottobre 2026

- Policy macchina > JSON locale > default.
- `unknown`: sola rilevazione; prima di installare configurare esplicitamente `standalone`.
- Opt-in protetto e conservato negli upgrade.
- Automatismo standalone all'inizio dell'esecuzione pianificata esistente, prima della manutenzione; nessun task permanente aggiuntivo.
- Dopo un aggiornamento verificato, la nuova versione riprende una sola volta la manutenzione richiesta, senza ciclo di aggiornamento.
- Download o verifica falliti prima di modificare l'installazione: la versione corrente continua la manutenzione e segnala WARN.
- Applicazione iniziata con stato dell'installazione incerto: non proseguire la manutenzione; avviare il recupero previsto e riportarne l'esito.
- GPO: soltanto rilevazione e segnalazione, nessuna installazione da MT. Nessun riavvio automatico.

## Proposta iniziale di configurazione — storico; contratto implementato in decisions.md

Estendere il JSON esistente `config/settings.json`, senza duplicare le impostazioni nell'INI legacy. Esempio dei default proposti (non modifica il file reale):

```json
"SelfUpdate": {
  "Management": "unknown",
  "AutomaticInstallEnabled": false
}
```

`Management` ammette solo `unknown`, `standalone`, `gpo`; `AutomaticInstallEnabled` deve essere un booleano JSON reale. ZIP/MSI descrive il formato di installazione, distinto dall'ownership. MSI presente, dominio, SYSTEM e `CREATE_TASK=0/1` non identificano da soli la gestione GPO.

Per GPO, proporre un indicatore amministrativo in `HKLM\Software\Policies\Kraugh\Maintenance Toolkit\SelfUpdate`: `Management` (stringa con gli stessi valori) e `AutomaticInstallEnabled` (DWORD 0/1). Questo è un nuovo contratto di policy, non una modifica ai percorsi di build/distribuzione. Non riutilizzare la chiave MSI di `InventoryShare` per identificare la gestione. Non creare task GPO né modificarne la configurazione.

Precedenza approvata: policy macchina > JSON locale > default. Dettagli proposti: la policy è una fonte completa; con chiave presente, i valori mancanti assumono `unknown`/false senza ereditare autorizzazioni dal JSON. Una policy `gpo` prevale su un JSON `standalone`; segnalare la differenza e restare in sola rilevazione. Nessun parametro CLI, INI o variabile d'ambiente può aggirare policy o abilitare implicitamente l'automatismo.

Abilitazione standalone: un'azione interattiva distinta richiede conferma e salva esplicitamente true nella configurazione locale; false disabilita. Richiedere permessi coerenti con l'installazione, senza elevazione implicita in headless. Se esiste policy macchina, le opzioni sono amministrate: la UI non la modifica. Un amministratore può abilitare l'automatismo per `standalone` con policy esplicita; `gpo` non consente mai installazione da MT.

| Configurazione effettiva | Comando con conferma | Automatismo |
|---|---|---|
| `standalone`, false | Consentito, dopo controlli di sicurezza | Disabilitato |
| `standalone`, true | Consentito, dopo controlli di sicurezza | Abilitato, subordinato a lock e verifiche |
| `gpo`, false | Solo rilevazione e segnalazione | Disabilitato |
| `unknown`, false | Solo rilevazione; configurazione esplicita `standalone` obbligatoria prima di installare | Disabilitato |
| `gpo` o `unknown`, true | Configurazione contraddittoria: nessuna installazione | Disabilitato, errore segnalato |
| Fonte invalida o illeggibile | Nessuna installazione; rilevazione se possibile | Disabilitato, nessun fallback permissivo |

Sezione assente o proprietà mancanti: default `unknown`/false per i campi mancanti. Valori null, tipi errati, enum sconosciute, chiavi duplicate o proprietà inattese nella sezione sono invalidi. Una fonte prioritaria invalida non può essere scavalcata da una fonte inferiore. I risultati devono riportare fonte, valori effettivi e motivo del blocco senza dati aziendali. Con JSON interamente assente/invalido, questa è la proposta di sicurezza dell'updater: il comportamento attuale del caricamento runtime non viene modificato né dichiarato tollerante.

Requisito approvato: opt-in protetto e conservato negli upgrade. Dettagli proposti: validare ACL e origine della configurazione prima dell'automatismo elevato; con JSON modificabile da utenti non autorizzati bloccare e segnalare. Definire lo storage e la persistenza delle preferenze: l'attuale packaging include `config`, quindi non è sufficiente aggiungere i campi al payload.

## Sequenza pianificata e recupero

Usare l'esecuzione pianificata esistente: risolvere gestione/opt-in, acquisire il coordinamento con le altre esecuzioni, rilevare l'aggiornamento e, solo per standalone abilitato, prepararlo prima di avviare manutenzione. Non introdurre un task permanente updater e non modificare i task GPO.

Prima della modifica dell'installazione, errori di download/verifica producono WARN e lasciano continuare la manutenzione corrente. Registrare la transizione all'applicazione; se dopo tale transizione lo stato è incerto, bloccare la manutenzione, avviare recovery e registrarne l'esito. Non dedurre una continuazione automatica dopo recovery: il contratto di recupero deve stabilire quando l'installazione è di nuovo verificata.

Dopo successo verificato, trasferire alla nuova versione la richiesta originale di manutenzione una sola volta. Proposta tecnica da concordare: handoff protetto con identificatore di transazione e consumo unico, associato alla versione/installazione attesa; il riavvio del processo per la ripresa salta il controllo di autoaggiornamento. Non usare un semplice flag non protetto come autorizzazione. Ripresa, fallimento e consumo del handoff devono essere testabili anche dopo interruzioni.

## Fasi successive del piano

1. Definire i dettagli di storage, validazione e persistenza di configurazione/policy secondo precedenza, opt-in protetto e comportamento `unknown` approvati; concordare il contratto concreto prima del runtime.
2. Definire manifest versionato compatibile con il controllo attuale, payload MSI/ZIP, hash e metadata firmati che autentichino anche gli script ZIP. Concordare identità ammessa, rotazione del certificato e verifica offline; non modificare ora il manifest stabile.
3. Implementare verifica di integrità, firma e produttore, rifiuto downgrade e origini non ammesse, con gli strumenti disponibili. Nuove dipendenze richiedono autorizzazione.
4. Coordinare manutenzione e updater con lock comune e helper verificato che attenda runtime e launcher; automatismo all'inizio dell'esecuzione pianificata, senza task permanente aggiuntivo. Non applicare durante manutenzioni attive. Definire handoff protetto e ripresa unica senza nuovo ciclo updater; pianificare il primo passaggio dalle versioni prive del lock.
5. MSI: aggiornare tramite Windows Installer senza riavvio, preservando impostazioni, `InventoryShare`, eccezioni/ACL e task MSI. Non toccare task GPO. ZIP: staging, backup e sostituzione controllata dei soli file applicativi, preservando configurazioni e dati locali. Mantenere build e output canonici.
6. Verificare versione e stato dopo l'applicazione; progettare rollback ZIP e recovery MSI senza promettere rollback non provati. Registrare file/task temporanei, pulire payload inutili e conservare evidenze/backup necessari con retention concordata.
7. Testare precedenze, assenza/errori/contraddizioni, ACL, consenso, policy GPO, concorrenza, firme/hash errati, interruzioni e recovery. Verificare WARN con continuazione prima della modifica, blocco con stato incerto dopo applicazione, ripresa unica e assenza di cicli/task permanenti aggiuntivi. Prove Windows PowerShell 5.1, ZIP/MSI standalone e SYSTEM/GPO; confronto configurazione, opt-in, eccezioni e task prima/dopo. Documentazione IT/EN e risorse JSON delle lingue supportate, con fallback inglese.

## Nuovo ambito 4.1 — creazione guidata di un'attivita pianificata

Richiesta approvata: aggiungere al menu MT una funzione per creare un'attivita eseguita come SYSTEM. L'utente sceglie ora e frequenza: quotidiana, all'avvio del computer, a piu orari o in determinati giorni. Destinazione opzionale locale o di rete per i report JSON.

Progettazione prima dell'implementazione:

- Decisione approvata: offrire tre modalita selezionabili, "Intera manutenzione MT" (opzione suggerita), "Solo analisi e report" e "Solo controllo aggiornamenti". L'utente sceglie esplicitamente la modalita nel menu prima della conferma; non assegnare implicitamente `-RunAll`. Definire prima dell'implementazione i moduli ammessi nella modalita di sola analisi, senza operazioni di manutenzione, e gli argomenti canonici di ciascuna modalita.
- La modalita "Solo controllo aggiornamenti" rileva e segnala: non autorizza installazioni. L'automatismo resta subordinato alla gestione standalone e all'opt-in protetto, secondo le decisioni precedenti; non trasformare questa attivita in un task updater permanente aggiuntivo. Definire l'interazione dell'automatismo con la modalita "Solo analisi e report" prima dell'implementazione.
- Richiedere privilegi amministrativi per creare l'attivita; mostrare riepilogo di azioni, trigger e destinazione prima della conferma. Non chiedere credenziali per SYSTEM.
- Definire ownership e nome canonico del task standalone, coordinandolo con il task MSI esistente. Non creare un secondo task permanente per l'updater, non sovrascrivere task GPO o task esistenti senza una scelta esplicita. In gestione GPO segnalare che la pianificazione appartiene all'amministratore.
- Distinguere trigger all'avvio del computer da accesso utente; definire giorni della settimana, eventuali date specifiche, orari multipli, recupero di esecuzioni mancate e comportamento delle esecuzioni sovrapposte. Rispettare il coordinamento manutenzione/updater e il divieto di riavvio automatico.
- Definire quali JSON esportare: inventario, risultati di manutenzione e/o diagnostica. `-InventoryShare` esiste per gli snapshot inventario, ma non equivale alla destinazione di tutti i report JSON; non estenderne il significato implicitamente.
- Destinazione di rete: usare un percorso UNC, non un'unita mappata dell'utente. SYSTEM accede con l'identita del computer quando applicabile; non garantire accesso sulla base della sessione interattiva. Definire permessi, indisponibilita e conservazione locale prima di introdurre il nuovo contratto.
- Preservare task e destinazione negli upgrade, testare trigger e contesto SYSTEM e documentare la funzione IT/EN con stringhe nei JSON delle lingue supportate.

Questa sezione registra l'ambito e i punti inizialmente da definire; lo stato attuale dell'implementazione e delle prove e riportato in apertura. Nessun task reale creato durante lo sviluppo.

## Limiti delle prove esistenti

L'upgrade MSI 4.0.6 con codice 0, versione verificata, otto eccezioni inalterate e task GPO conservato è una prova riferita dall'utente. Non valida l'updater 4.1 né il passaggio Winget selettivo reale, che resta da verificare. I nuovi test locali usano installazioni fittizie e confini Windows simulati, senza manutenzione del computer.

## Gate documentale e issue

[Revisione issue](ISSUE-REVIEW-20261014.md): #27 richiede ancora ispezione/rimozione/stato del task e prove reali; #28 upgrade reale e scenari di errore/interruzione; #20 traduzioni complete e allineamento del target spagnolo. Non dichiarare chiuse queste issue per i soli 72 test isolati. GitHub/sito: annunci e istruzioni soltanto IT/EN, disponibilita multilingue con copertura parziale dichiarata. [Testo preparato](../docs/PUBLICATION-NOTES-4.1.md), non pubblicato. Le modifiche documentali successive non cambiano i byte dei pacchetti R02 gia firmati; un futuro pacchetto aggiornato richiede un nuovo identificatore e nuove verifiche.

## Risultato pilota R04

MSI/ZIP, recupero ZIP reale, SYSTEM/UNC locale, helper con ripresa unica e interruzione HTTPS verificati; installato candidato privato 4.0.9006. Difetto Move-Item corretto con Directory.Move atomico. Rollback/interruzione MSI dopo modifiche, feed pubblico/bootstrap e confronto sito restano gate. Le precedenti sezioni "da validare" conservano lo stato storico; [evidenze correnti](MT-4.1-VM-PILOT-20261015.md).

## Aggiornamento del gate MSI

Anche il rollback MSI controllato dopo InstallFiles e ora verificato (1603, ripristino 4.0.9006, hash/registrazione/configurazione e blocco manutenzione). La fixture 4.0.9007 e volutamente non installabile e non e un candidato. Restano finalizzazione/versione pubblica, bootstrap documentato e distribuzione/verifica del feed in una fase autorizzata, confronto sorgenti sito e copertura degli ambienti dichiarati; nessuna pubblicazione in questa fase. [Risultati](MT-4.1-VM-PILOT-20261015.md).

## Windows 10 test waiver — user approved

15 October 2026: the user explicitly waived the Windows 10 test for this 4.1 phase. It is no longer a blocking test in this phase, but Windows 10 must not be described as validated by this pilot. Actual environment: Windows 11 Pro build 26200 / Windows PowerShell 5.1. Other release gates remain in force. See [release preparation](MT-4.1-RELEASE-PREPARATION.md).
