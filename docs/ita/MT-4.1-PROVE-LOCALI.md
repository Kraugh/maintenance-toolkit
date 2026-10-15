# MT 4.1 — sviluppo e prove locali

I sorgenti indicano 4.1.0-dev.3, non una release pubblicata. Manifest stabile e pacchetti pubblici 4.0.6 invariati; questo incremento non fornisce nuovi binari firmati. Non eseguire manutenzione completa soltanto per provare pianificazione o updater.

## Menu e pianificazione

G configura gestione standalone esplicita e opt-in protetto. Policy macchina > preferenze locali > default JSON distribuiti. Unknown rileva soltanto aggiornamenti; il dominio non determina la gestione. P offre manutenzione (consigliata: tutti i moduli abilitati in configurazione), analisi (Connectivity, Inventory, NetworkReport, DiskHealth, NVIDIA informativo) o solo controllo aggiornamenti. Sono disponibili orari quotidiani multipli, giorni della settimana e avvio del computer; non date specifiche di calendario in questo incremento. Servono elevazione, installazione locale protetta, riepilogo e conferma. Non vengono sovrascritti task di altre installazioni o GPO. Orari nel fuso del computer; recupero esecuzioni mancate StartWhenAvailable, sovrapposizioni IgnoreNew, limite di quattro ore.

La destinazione JSON opzionale deve essere locale assoluta o UNC, esterna al runtime. Le unita mappate dell'utente non sono una destinazione SYSTEM affidabile: occorrono permessi della sua identita, tipicamente account computer sulle share di dominio. Tutti i JSON della sessione, incluso maintenance-summary.json, vengono copiati tramite file temporaneo e rinomina; un errore produce WARN e conserva i report locali. Il solo controllo aggiornamenti produce update-check.json e non installa, anche con opt-in.

Preferenze e transazioni protette risiedono in `%ProgramData%\Kraugh\MaintenanceToolkit\self-update\<installation-id>`, fuori dai file MSI. Il JSON config/settings.json puo contenere SelfUpdate.Management (unknown/standalone/gpo) e AutomaticInstallEnabled booleano. Policy: `HKLM\Software\Policies\Kraugh\Maintenance Toolkit\SelfUpdate`, Management REG_SZ e AutomaticInstallEnabled DWORD 0/1. Policy presente completa: campi mancanti unknown/false, senza ereditarieta del consenso locale. Errori, illeggibilita o contraddizioni bloccano l'installazione. Opt-in locale con ACL protette; la UI non modifica policy.

## Flusso di aggiornamento

V chiede conferma prima del download e prima dell'applicazione. L'automatismo opt-in precede manutenzione/analisi pianificata, senza task updater permanente. Lock globale per installazione; helper separato attende la chiusura di runtime e launcher. Preparazione fallita: WARN e continuazione corrente; applicazione incerta: blocco. Dopo verifica la nuova versione riprende una sola volta tramite handoff protetto consumato e salta l'updater. Nessun riavvio automatico. Primo upgrade da vecchie versioni prive del lock: finestra amministrata.

Endpoint applicazione previsto update-v1.json con update-v1.cat firmato; version.json resta il controllo informativo. Il catalogo autentica i byte JSON; SHA-256, firma, timestamp, certificato ammesso e revoca online precedono l'esecuzione. ZIP: catalogo esterno firmato di tutti gli script/risorse, rifiuto percorsi pericolosi, conservazione settings/INI e log/report, rollback alla cartella precedente se la verifica finale fallisce. config/version.json proviene dal nuovo payload. MSI: prodotto/versione/UpgradeCode/x64 e firma incorporata, Windows Installer con CREATE_TASK=0 e riavvio soppresso; conservazione InventoryShare e backup dati, ripristino soltanto del task MSI di questa installazione. Task GPO ed eccezioni ProgramData non vengono modificati. Errori MSI/riavvio pendente richiedono revisione del recupero: nessun downgrade cieco o continuazione automatica.

Consenso conservato negli upgrade; moduli eseguibili personalizzati o modifiche a lingue/temi/regole non vengono mescolati silenziosamente al payload autenticato. Backup ZIP disponibile durante rollback, rimosso dopo successo; errori conservano evidenze e backup mutabile. Transazioni incomplete bloccano nuove manutenzioni; handoff consumato non ripetibile. Dopo crash prima della ripresa occorre ispezionare la transazione: una sola esecuzione impedisce duplicazioni, non garantisce l'esecuzione dopo ogni interruzione.

U e R sono rimossi dal menu utente. V verifica prima la disponibilita e propone installazione solo in gestione standalone esplicita. Il recupero rimane una protezione interna della transazione, senza voce di menu. Uno stato incerto richiede reinstallazione verificata e controllo amministrativo della transazione protetta prima della manutenzione; reinstallare i soli file non cancella ciecamente una transazione incompleta.

H (Languages) seleziona inglese, italiano, francese, spagnolo, tedesco, cinese semplificato o giapponese e salva settings.json. Lingue di sistema non supportate e traduzioni mancanti usano l'inglese. Le nuove risorse traducono il menu e i flussi 4.1; le diagnostiche storiche non sono ancora interamente tradotte. Svedese conservato per compatibilita, fuori dal menu delle sette lingue.

## Prove sicure e gate reale

Da repository: Windows PowerShell 5.1 `-NoProfile -ExecutionPolicy Bypass -File app/tools/Test-MT41.ps1`. Bypass riguarda solo il processo, senza cambio policy macchina. Fixture univoche sotto launcher/build, poi eliminate; task, firme/applicazione e processo MSI simulati dove indicato. Nessuna installazione MSI o creazione task. La firma del catalogo fittizio era una prova separata autorizzata; nessun nuovo pacchetto firmato qui.

Prima del pilota: compilare e firmare un candidato distinto senza sostituire artefatti pubblicati; verificare quoting launcher, task SYSTEM, errori share, rollback MSI/custom action, opt-in, hash eccezioni, XML task ed errori di ripresa. tools/New-MTUpdateMetadata.ps1 estende gli output dist: PayloadCatalog crea catalogo v2 non firmato; dopo firma esplicita, Metadata verifica pacchetti/catalogo e crea JSON versionato e catalogo metadata non firmato sotto dist/updates. Non firma e non pubblica. La versione development non puo essere compilata come MSI pubblico; finalizzare la versione numerica e una fase separata.

## Candidato locale firmato — R02

Firma e verifica locali completate; le richieste precedenti descrivono il checkpoint precedente. Runtime 4.1.0-dev.3, MSI privato ProductVersion 4.0.9003: non e una release stabile.

Artefatti: `dist/MaintenanceToolkit-LocalSigned-20261014-150201-e963186c-R02`. Vedere [evidenze locali](../../project/MT-4.1-LOCAL-VALIDATION.md). 72 test isolati superati; installazione/upgrade reale e verifica SYSTEM/UNC restano da eseguire. Le nuove modifiche documentali non sono incluse retroattivamente nei pacchetti firmati. Vedere [revisione issue](../../project/ISSUE-REVIEW-20261014.md).

## Incremento del 15 ottobre — da includere nel prossimo candidato

P ora offre creazione/modifica, ispezione con ultimo/prossimo avvio ed esito, rimozione con conferma. Scegliere recupero avvii mancati (predefinito attivo), batteria (predefinito disattivo), rete necessaria (predefinito disattivo). Disponibilita rete non significa autorizzazione sulla share UNC. Operazioni registrate nel diario protetto schedule-events.jsonl. Nessun task GPO modificato.

112 controlli isolati superati; correzione della ripresa non interattiva e pulizia payload consumato. Queste modifiche non sono nei pacchetti R02. [Pilota VM](../../project/MT-4.1-PILOT.md) ancora da eseguire; nessuna garanzia di upgrade reale o SYSTEM deriva dai test simulati.

## Candidato privato R04 — 4.0.9006

117 controlli passati. Prove reali superate: MSI, sostituzione/recupero ZIP con file bloccato, helper e ripresa unica in sola analisi, task SYSTEM e copia JSON tramite UNC locale. Share inesistente: WARN con copia locale conservata. Trasferimento HTTPS reale interrotto e partial rimosso. Corretto Move-Item, che poteva spostare parzialmente una cartella: ora si usa la rinomina atomica Directory.Move.

R04 e il candidato verificato corrente; R02/R03 sono storici. MSI resta installato nella VM alla 4.0.9006, senza riavvio o manutenzione. La prova MSI occupato non ha riprodotto il rifiuto; rollback/interruzione MSI e share aziendale restano gate distinti. [Evidenze complete](../../project/MT-4.1-VM-PILOT-20261015.md). Nessuna pubblicazione o variazione del manifest stabile.

## Esito finale MSI e primo passaggio alla 4.1

Rollback MSI controllato verificato dopo InstallFiles: codice 1603, versione/hash/registrazione precedenti ripristinati, configurazione e task preservati. Nessun riavvio o manutenzione. Il candidato utilizzabile resta R04/4.0.9006; 4.0.9007 e una fixture che fallisce volutamente, da non installare/distribuire.

La 4.0.6 non contiene l’updater applicativo: il primo passaggio pubblico alla 4.1 sara manuale e documentato, non un aggiornamento automatico retroattivo. Prima del passaggio salvare settings.json, MaintenanceToolkit.ini, log/report, preferenze/eccezioni ProgramData e XML dei task; mantenere proprieta e ACL. Dopo l’installazione ripristinare solo le impostazioni locali necessarie e verificarle: non sovrascrivere config/version.json con quello vecchio. Installazioni GPO: procedura dell’organizzazione e task GPO invariati; non dichiararle standalone. Non avviare manutenzione finche versione, configurazione e ownership non sono verificate. Pacchetti/versione/feed pubblici saranno finalizzati in una fase successiva autorizzata.

Le prove attuali sono Windows 11 Pro build 26200 / Windows PowerShell 5.1; non dimostrano aggiornamento 4.1 su Windows 10 o accesso a una share aziendale. [Evidenze e limiti](../../project/MT-4.1-VM-PILOT-20261015.md).

[Aggiornamento e primo passaggio alla 4.1](AGGIORNAMENTO-MT.md). Test Windows 10 esplicitamente saltato; nessuna dichiarazione di validazione.
