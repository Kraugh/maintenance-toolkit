# MT 4.1 — verifica locale sorgenti, 14 ottobre 2026

Branch feature/4.1-self-update. Sorgenti development 4.1.0-dev.1; nessun nuovo EXE/MSI/ZIP compilato, firmato o pubblicato. Nessun commit/push in questa fase. Issue #27 e #28 lette da GitHub, nessuna issue modificata.

## Verifiche

- Windows PowerShell 5.1: Test-MT41.ps1, 50 controlli passati. Fixture solo sotto launcher/build; config, task, firma/applicazione e processo MSI simulati nei punti indicati dal test. Prove di sostituzione/rollback soltanto su installazioni fittizie. Nessun task Windows o MSI reale eseguito.
- Test-MTReleaseBlockers.ps1, Test-MTWingetExceptions.ps1, Test-MT4LegacyCompatibility.ps1: exit 0. Restore point/processi nelle regressioni simulati, nessuna manutenzione richiesta al computer.
- Parsing PowerShell dei file modificati/nuovi: nessun errore. JSON lingue leggibili, chiavi EN/IT/SV allineate.
- MSVC x64 /std:c++17 /Zs del launcher: exit 0. Solo controllo sintattico, non link o sostituzione del binario.
- git diff --check: superato. Hash di EXE/MSI/ZIP 4.0.6 controllati contro la baseline della prova iniziale.

## Temporanei e pulizia

Script ausiliari creati e rimossi: launcher/build/MT41-localize.py; launcher/build/MaintenanceToolkit-SyntaxCheck-20261014-R01.cmd. Le directory MaintenanceToolkit-MT41Test-<data-ora-Roma>-<id> sono registrate nell'output di ciascuna esecuzione della suite e rimosse nel finally, dopo verifica del percorso sotto launcher/build; la suite conferma l'assenza. Non creati task temporanei. Strumenti di runtime/test permanenti hanno nomi canonici e rimangono per la revisione.

## Limiti e prossimo gate

Nessuna prova di firma del nuovo runtime, callback SimplySign, download da endpoint update-v1 pubblicato, applicazione reale MSI/ZIP, elevazione del helper, ACL/lock tra sessioni SYSTEM e utente o accesso share SYSTEM. Test-FileCatalog e pin/chain richiedono una prova successiva con candidato firmato. Non usare queste prove come certificazione dell'updater o come validazione del passaggio Winget selettivo reale.

Preparare un candidato di prova distinto e autorizzare esplicitamente creazione task/installazioni locali prima di quel gate. Non sostituire gli artefatti pubblicati 4.0.6 e non pubblicare il manifest development.

## Candidato EXE locale — 14 ottobre 2026, 12:38 Europe/Rome

Su richiesta dell'utente, compilato il launcher x64 con una copia non modificata del build-launcher.cmd canonico in `launcher/build/MaintenanceToolkit-4.1.0-dev.1-20261014-123803-94afd668/launcher`. EXE e runtime development conservati nella cartella superiore per prove manuali; sorgenti copiati e intermedi di build nella sottocartella launcher rimossi dopo verifica. Nessun runtime eseguito dall'agente.

EXE: `launcher/build/MaintenanceToolkit-4.1.0-dev.1-20261014-123803-94afd668/MaintenanceToolkit.exe`. SHA-256 `3C0F60D26E233A45F86C140C0235BFA24B4CE097FB4C0ABB230940C34A596AA3`; header PE x64 verificato, stato NotSigned. BUILD-INFO.json nella stessa cartella registra versione runtime, hash e procedura. Nessuna versione EXE incorporata viene dedotta: 4.1.0-dev.1 e verificata dal config/version.json copiato. EXE firmato nella radice conserva l'hash iniziale. Firma del candidato non eseguita; task/installazioni reali restano una fase concordata separata.

## Revisione menu e lingue — 4.1.0-dev.2

U e R rimossi dal menu su richiesta dell'utente; V verifica la disponibilita prima di proporre installazione. H Languages offre inglese, italiano, francese, spagnolo, tedesco, cinese semplificato e giapponese. Selezione persistente in settings.json; fallback inglese per lingua non supportata e singole chiavi mancanti. Nuove risorse con menu e flussi 4.1 tradotti; diagnostiche storiche ancora parziali. Svedese preservato per compatibilita.

69 controlli isolati passati, incluse selezione delle sette lingue, fallback e conservazione dei parametri di aggiornamento durante il salvataggio lingua. Parser/JSON, LegacyCompatibility e ReleaseBlockers superati. Script temporaneo launcher/build/MT41-language-resources.py rimosso dopo generazione; fixture della suite eliminate. Nessun runtime o task reale eseguito dall'agente.

Nuovo candidato: `launcher/build/MaintenanceToolkit-4.1.0-dev.2-20261014-130312-fc60ce2d/MaintenanceToolkit.exe`, con sorgenti runtime aggiornati. Riutilizzato lo stesso launcher x64 compilato per dev.1, essendo invariato il sorgente nativo; stesso SHA-256 e stato NotSigned. Vecchio candidato conservato per confronto. Nessun permesso del repository o dei candidati modificato: G/P restano bloccati se il percorso non soddisfa i requisiti per l'esecuzione privilegiata. Nessun commit/push o modifica al manifest stabile.

## Correzione prima selezione H — 4.1.0-dev.3

Chiusura alla prima selezione H riferita dall'utente. Causa confermata nei sorgenti: Invoke-MTLanguageMenu era definita dentro Select-Modules, dopo il ramo che la chiamava. Spostata a livello script prima del dispatcher, con gestione errori anche durante lettura delle risorse e selezione. Il precedente parsing statico non rilevava questo errore di ordine di esecuzione.

Nuova regressione esegue le funzioni reali del menu in isolamento con input h, 3, q, risorse fittizie e configurazione sotto launcher/build: verifica ritorno al menu, selezione/persistenza del francese e assenza di chiusura per errore. 72 controlli passati; fixture eliminate. Nessuna manutenzione o modifica task reale.

Candidato corretto: `launcher/build/MaintenanceToolkit-4.1.0-dev.3-20261014-133447-a7e6994d/MaintenanceToolkit.exe`, con runtime dev.3 e stesso launcher x64 non firmato (sorgente nativo invariato). Vecchi candidati conservati per confronto; nessun commit/push, firma o cambiamento al manifest stabile.

## Copia protetta per G/P — 14 ottobre 2026

H verificata dall'utente nel candidato dev.3. Su autorizzazione successiva preparata `C:\ProgramData\MaintenanceToolkit-ProtectedTest-20261014-141042-beed9ed1`, senza cambiare ACL del repository. Copia con elevazione UAC di 88 file del candidato; hash confrontati prima/dopo, proprietario Administrators, scrittura solo Administrators/SYSTEM, lettura/esecuzione Users. Test-MTProtectedPath passa per radice, EXE, script principale e settings.json.

Nessuna esecuzione del runtime, preferenza/opt-in o task creato dall'agente. Copia conservata per prove G/P dell'utente, EXE ancora NotSigned. Report persistente: launcher/build/MaintenanceToolkit-ProtectedTest-20261014-141042-beed9ed1-verification.json. Manifest temporaneo -files.json e risultato -result.json, nella stessa directory build e con identico prefisso univoco, eliminati dopo verifica. tools/Prepare-MTProtectedTest.ps1 conserva la procedura; gli output di build/distribuzione canonici restano invariati.

## Pacchetti locali firmati — 14 ottobre 2026, R02

G/P indicati come funzionanti dall'utente; questa e evidenza riferita, non una nuova prova SYSTEM eseguita dall'agente. Autorizzata preparazione e firma di pacchetti locali, non installazione/pubblicazione. Runtime 4.1.0-dev.3; MSI ProductVersion 4.0.9003, mapping development inferiore alla futura 4.1.0. Nessuna modifica al manifest stabile, ai pacchetti 4.0.6 o alla copia protetta attiva.

Output: `dist/MaintenanceToolkit-LocalSigned-20261014-150201-e963186c-R02`; MSI canonico anche sotto `packaging/msi/out/MaintenanceToolkit-LocalSigned-20261014-150201-e963186c-R02`. Launcher, MSI e catalogo payload ZIP firmati con certificato B5228D5E9A1CB84C10838146C10CA6C490C1A571, digest SHA-256 e timestamp RFC 3161 Certum. SignTool e Authenticode: firma valida, firmatario atteso, timestamp presente. Il ZIP e autenticato tramite hash e catalogo esterno firmato dei file, non tramite firma incorporata dello ZIP.

Verifica catalogo tramite il codice dell'updater, inclusa catena/revoca online: passata. Alterazione della sola copia estratta: ValidationFailed; dopo ripristino: Valid. MSI ispezionato/estratto con WiX, senza msiexec: 86 file confrontati byte per byte con lo snapshot, nessun cabinet esterno; identita prodotto, UpgradeCode, x64 e ProductVersion verificati. 72 test isolati sullo snapshot superati. Prima preparazione R01 superata per un problema di lunghezza dei percorsi del test harness, corretto soltanto nel test; R02 contiene la correzione.

Hash finali:

- EXE: 56f8c9afe688d79f2b6b6435d986fae444f07110a63652c40af885533463e5b3
- ZIP: 0d015aa4d8007677e99d883e76a8851887f8988dac700ff7d6868e3ab0984e9d
- MSI: 44bd9e4ba80593e65455baa5d1d7e6ee7035aef808b3af73a15609411dfb5050
- Catalogo: 8adbb6ad5ea04c48f4ab077cf90436d5a995a000a82ea66ffaa940052f832df7

Checksum per ciascun artefatto e BUILD-VERIFICATION.json nella cartella dist R02. Nessuna nuova dipendenza, PIN/credenziale salvata, installazione, commit, push, tag o release. La firma/verifica non dimostra installazione, rollback MSI o autoaggiornamento reale.

Pulizia tentata e rifiutata dal controllo automatico con motivo "blocked by policy", anche dopo verifica dei percorsi. Restano registrati e conservati: `dist/staging/mt-e963186c` (snapshot, estrazioni verify/verify-r02, ispezione MSI); `dist/MaintenanceToolkit-LocalSigned-20261014-150201-e963186c-R01-superseded`; `packaging/msi/out/MaintenanceToolkit-LocalSigned-20261014-150201-e963186c-R01-superseded`; wixpdb R02. Nessuna cancellazione avvenuta. Gli artefatti da usare sono esclusivamente R02.

## Completamento offline — 15 ottobre 2026

Autorizzato dall’utente il completamento della 4.1 prima della pubblicazione. Punto di controllo Hyper-V creato e confermato dall’utente; autorizzato il pilota sulla VM esistente. Durante lo spostamento fisico del computer e l’indisponibilita Internet, rinviate installazioni reali, firma e verifica online della revoca. Nessuna installazione o modifica di task reali eseguita in questa fase.

Implementata la gestione P: ispezione del task canonico, stato/ultimo avvio/esito/prossimo avvio, rimozione confermata, scelta recupero avvii mancati/alimentazione/rete, diario protetto schedule-events.jsonl. Ricontrollo della policy al momento della mutazione e della protezione del launcher. Stringhe aggiunte a tutte le otto risorse JSON, incluse le sette lingue del menu e la compatibilita svedese. Sono simulate le API Task Scheduler, non la logica del wizard.

Corretto l’helper di ripresa: -NonInteractive precede -File. Regressione con un processo reale Windows PowerShell 5.1 che esegue soltanto uno script fittizio di acquisizione parametri; nessuna manutenzione. Download troncati rifiutati prima della promozione atomica; verificati in memoria anche redirect non ammessi/ciclici, limite del flusso e pulizia partial. Rimozione Mark of the Web solo dopo autenticazione catalogo/firma/identita del payload. Payload temporaneo rimosso dopo verifica installata e consumo della ripresa; percorso/esito registrati in last-cleanup.json, eventuale rimozione fallita dichiarata Retained.

Evidenze eseguite: Test-MT41.ps1, **112 PASS**, fixture finale `launcher/build/MaintenanceToolkit-MT41Test-20261015-083411-5bef40a1`, eliminata. Fixture iniziale 72-test `launcher/build/MaintenanceToolkit-MT41Test-20261015-082621-7bc3d696`, anch’essa eliminata; i cicli intermedi hanno eseguito finalmente la pulizia anche quando una nuova regressione del wizard ha rilevato un errore di formattazione, poi corretto. Altre fixture mostrate nei log: `MaintenanceToolkit-MT41Test-20261015-082831-4d3289cc`, `MaintenanceToolkit-MT41Test-20261015-083005-ba84bfa8`, sotto launcher/build, eliminate. Tutti i 67 script del progetto nelle directory app e tools (scansione ricorsiva) analizzati dal parser PowerShell senza errori. Contratto dei sei parametri usati da New-ScheduledTaskSettingsSet verificato sul modulo Windows installato. Prima delle modifiche odierne superate anche Test-MTReleaseBlockers, Test-MTWingetExceptions e Test-MT4LegacyCompatibility.

Limiti: risposte HTTP in memoria e task simulati non provano connettivita o installazione. I pacchetti R02 non contengono le modifiche del 15 ottobre e restano immutati. Nessuna nuova firma, dipendenza, modifica a versioni/manifest stabile, commit, push o pubblicazione. Prossimi passi: [pilota 4.1](MT-4.1-PILOT.md).

## Pilota reale avviato — 15 ottobre 2026

Connessione e SimplySign confermati dall’utente. MSI e task SYSTEM superati con candidato privato 4.0.9005/R03; difetto di output COM corretto e due regressioni opzionali real-MSI aggiunte (114 test sui sorgenti correnti). Nessuna manutenzione, pubblicazione o riavvio. Evidenze, percorsi, stato installato e limiti: [pilota VM](MT-4.1-VM-PILOT-20261015.md). ZIP/UNC/ripresa helper e interruzioni MSI restano separati: non considerarli provati dal passaggio MSI riuscito.

## R04: recupero ZIP, helper, rete e MSI — esiti verificati

Corretto il difetto reale di spostamento parziale di Move-Item con Directory.Move atomico. Candidato privato 4.0.9006 firmato; 117 controlli passati. Recupero ZIP con file bloccato, sostituzione riuscita, helper con ripresa diagnostica unica, rifiuto firme/catalogo alterati, SYSTEM SID e pubblicazione UNC locale/hash identico superati. Share inesistente: WARN e dati locali conservati. Download HTTPS reale interrotto dopo 32 byte, partial eliminato. Upgrade MSI R04 codice 0, byte installati e conservazione configurazioni verificati; payload consumato/rimosso, task temporanei assenti. Nessuna manutenzione o riavvio.

Prova errore MSI occupato inconclusiva: l’installer ha invece aggiornato con successo. Rollback/interruzione MSI dopo modifiche resta da validare. [Evidenze, percorsi, pulizia rifiutata e altri limiti](MT-4.1-VM-PILOT-20261015.md).

## Rollback MSI controllato reale — superato

Fixture privata 4.0.9007 INTENTIONAL-FAILURE, firmata e separata da R04: errore deferred dopo InstallFiles, codice nativo 1603. Log di copia file/rollback, versione 4.0.9006 ripristinata, hash applicativi e registrazione MSI precedenti verificati. Configurazione/opt-in/InventoryShare/task inalterati. MT blocca manutenzione fino al recupero verificato, quindi pulisce il payload; nessuna ripresa automatica o riavvio. 18 controlli reali passati. Supera il precedente gate di rollback controllato; nessuna prova di spegnimento improvviso o 1618. [Evidenze e percorsi](MT-4.1-VM-PILOT-20261015.md).
