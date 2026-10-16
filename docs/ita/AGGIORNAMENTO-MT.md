# Aggiornamento MT — 4.1

Istruzioni per i pacchetti MT 4.1.2. Verificare la disponibilità pubblica su GitHub Releases. Il primo passaggio dalla 4.0.6 richiede installazione manuale con pacchetti ufficiali verificati. Le prove con numerazione privata sono documentate separatamente.

## Verifica storica privata 4.1.2 R01

Il 16 ottobre 2026 i pacchetti locali finali firmati 4.1.2 MSI/ZIP hanno superato i passaggi manuali autenticati dalle versioni pubbliche 4.0.6 e 4.1.1 sulla VM Windows 11 / Windows PowerShell 5.1, oltre all'installazione MSI da zero. MSI e SelfTest elevati della versione installata hanno restituito 0. Conservati impostazioni, log/report, opt-in protetto, InventoryShare e XML dei task; verificati recupero ZIP con file bloccato e rifiuto dello script alterato. Nessuna manutenzione o riavvio. [Risultati completi e limiti](../../project/MT-4.1.2-LOCAL-CANDIDATE.md).

L'updater 4.1.1 può fermarsi prima dell'installazione se un altro programma ha un percorso di disinstallazione non valido nel registro: caso riprodotto sulla VM. Quell'installazione richiede un aggiornamento manuale verificato quando sarà disponibile una sostituzione autorizzata. Non modificare voci di registro estranee né aggirare i controlli di fiducia. Questi risultati riguardano il precedente R01 privato; lo stato dei pacchetti e della pubblicazione è registrato su GitHub Releases. Windows 10, GPO reale/SMB aziendale e conservazione di un file eccezioni aziendale presente non sono stati verificati qui. Queste istruzioni del repository sono aggiornate dopo i test; i contenuti dei pacchetti congelati restano invariati.

## Primo passaggio da 4.0.6

La 4.0.6 non puo applicare l’updater 4.1. Il primo aggiornamento e manuale, con pacchetti ufficiali verificati e privilegi amministrativi. Attendere il termine di eventuale manutenzione attiva; non terminarla forzatamente.

Prima dell’installazione conservare una copia protetta di config/settings.json, config/MaintenanceToolkit.ini, log/report e preferenze/eccezioni sotto ProgramData, rispettandone ACL e proprietario. Registrare InventoryShare da HKLM\Software\Kraugh\Maintenance Toolkit e salvare XML/argomenti dei task pertinenti. Non inserire identita aziendali nei resoconti pubblici.

MSI: verificare checksum, firma con timestamp e produttore del nuovo pacchetto. Per GPO la distribuzione resta dell’organizzazione, con CREATE_TASK=0 e task GPO invariati. Per installazione manuale, usare /norestart REBOOT=ReallySuppress e passare esplicitamente il precedente INVENTORY_SHARE quando configurato; non accettare implicitamente un valore vuoto. CREATE_TASK=0 evita di introdurre una pianificazione aggiuntiva. Conservare log e codice nativo; non avviare manutenzione se esito, versione o stato sono incerti.

ZIP: verificare origine, checksum e catalogo firmato dei file prima di eseguire script o togliere Mark of the Web. Estrarre in una cartella nuova; conservare il vecchio albero fino alla verifica. Copiare soltanto impostazioni e dati locali necessari. Non mescolare app/core/moduli di versioni differenti.

Dopo il passaggio verificare versione nuova, impostazioni, eccezioni, destinazione inventario e task prima di eseguire manutenzione. Ripristinare solo settings.json/INI e dati locali necessari; non sovrascrivere config/version.json con quello vecchio. Un riavvio eventualmente richiesto resta una decisione manuale separata, mai automatica.

## Dalla 4.1 in poi

V rileva e propone l’aggiornamento standalone con conferma. G configura gestione standalone e opt-in protetto; automatismo disabilitato per default, prima delle sole esecuzioni pianificate abilitate. GPO: rilevazione e segnalazione, installazione affidata all’organizzazione. Unknown: sola rilevazione finche la gestione standalone non e dichiarata esplicitamente. Appartenenza al dominio e formato MSI/ZIP non stabiliscono da soli la gestione GPO. Nessun task updater permanente aggiuntivo.

Con installazione incerta non riprendere manutenzione e non eliminare manualmente journal/lock per aggirare il blocco: conservare log e completare recupero o reinstallazione verificata con revisione amministrativa. Errori di preparazione prima delle modifiche possono invece produrre WARN con continuazione della versione corrente.

## Ambito delle prove

117 regressioni e pilota reale su Windows 11 Pro build 26200 / Windows PowerShell 5.1. Test Windows 10 saltato per decisione esplicita dell’utente: non dichiarato verificato. UNC locale verificato, autorizzazioni su server aziendali da validare nel contesto SYSTEM effettivo. Documentazione pubblica solo IT/EN; nuove lingue del runtime con copertura parziale e fallback inglese.

## Patch 4.1.1 per il trasporto HTTP

La 4.1.0 e ritirata dalle release pubbliche: usare direttamente la 4.1.1, senza passaggi intermedi. Il maintainer riferisce nessuna adozione 4.1.0 da parte degli utenti; i download tecnici di verifica non provano installazioni utente. Le indicazioni sotto restano per copie storiche/di prova. [Stato corrente issue e accettazione](../../project/ISSUE-REVIEW-20261015.md).

La 4.1.0 puo ricevere HTTP 403 dall'hosting prima di scaricare metadati/payload, perche non invia User-Agent. Eseguire il passaggio manuale alla 4.1.1 con MSI/ZIP ufficiale verificato, conservando impostazioni, eccezioni, log/report, InventoryShare e task come sopra. La patch invia soltanto l'identificativo prodotto, senza nomi macchina o utenti. Non eliminare journal/lock per aggirare un eventuale stato incerto. I pacchetti 4.1.0 restano invariati.
