# MT 4.1 — piano di autoaggiornamento

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

## Configurazione proposta — da concordare, non implementata

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

## Evidenze e limiti

Piano documentale, nessuna implementazione o nuova prova Windows. L'upgrade MSI 4.0.6 con codice 0, versione verificata, otto eccezioni inalterate e task GPO conservato è una prova riferita dall'utente. Non valida il futuro updater né il passaggio Winget selettivo reale, che resta da verificare.
