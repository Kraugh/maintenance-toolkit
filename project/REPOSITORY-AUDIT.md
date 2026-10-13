# Audit del repository e dei pacchetti — 13 ottobre 2026

## Oggetto ed evidenza

Archivio fornito: maintenance-toolkit(7).zip. Commit: 0bb15eb5be6577ae763a3441d9293622c18838f4. Working tree allegato pulito. HEAD e origin/main salvato nell'archivio coincidono (ahead/behind 0/0). Questo non e un fetch live di GitHub.

L'archivio ha superato la verifica CRC. Sono stati letti e inventariati tutti i file presenti, inclusi oggetti Git, strumenti WiX locali, build e copie dei pacchetti. L'inventario allegato contiene dimensione e SHA-256 di ogni file. I 145 file tracciati sono stati controllati per leggibilita, nomi, riferimenti locali, versioni e configurazione; e stata effettuata una revisione statica dei percorsi operativi rilevanti. Il calcolo di un hash non dimostra la correttezza del programma.

## Controlli eseguiti

- Integrita ZIP e Git fsck: nessuna corruzione rilevata. I dangling blob segnalati da fsck sono oggetti non referenziati, non un errore del repository.
- Tutti i 20 JSON tracciati: parsing UTF-8 e assenza di chiavi duplicate.
- EN/IT/SV: 394 chiavi ciascuno; parita delle chiavi. Le chiavi letterali rilevate nelle chiamate Get-MTRuntimeText/T esistono nei JSON. Le chiamate dinamiche non sono dimostrate da questo controllo.
- Collegamenti relativi Markdown: nessun file locale mancante nel repository. I collegamenti web non sono stati tutti verificati live; le ancore Markdown non sono state validate semanticamente.
- Tutti i file di testo tracciati: decodifica UTF-8 riuscita. Le intestazioni storiche nei commenti non sono versioni operative.
- Runtime/config: 4.0.6 coerente. EXE, BAT e PS1 raggiungono il modulo Winget condiviso. Il modulo legge il percorso exceptions concordato; file assente mantiene il flusso normale, file invalido blocca Winget. Il piano esclude ID esatti senza --all; --skip-dependencies non controlla prerequisiti incorporati negli installer.
- MSI: struttura compound-file leggibile, cabinet interno presente (75 file), stream di firma presente. Questa ispezione non sostituisce SignTool e non costituisce nuova verifica crittografica della catena.
- ZIP pubblico 4.0.6: 90 elementi, CRC integro; tutti i file confrontabili sono byte-identici ai sorgenti locali allegati. Nessun payload installer, log o file aziendale di eccezioni nel pacchetto; il modello JSON e distinto dalla policy attiva.
- Cleanup MSI: opera su logs/reports sotto INSTALLFOLDER; non contiene rimozione della cartella ProgramData delle eccezioni. Nell'audit dell'archivio la conservazione su un upgrade reale non era ancora provata; vedere l'aggiornamento documentale della prova MSI sotto riportato.

## Hash dei pacchetti pubblicati verificati sui byte allegati

- Launcher: F79C5A79EB9E34E02327B67C8870672AB4E96930A74B03B84700EA8F09AC8937
- MSI: 12158915F608EE9156049D1DC38F0037882B69CEE104E139229830D0CA5FA6B9
- ZIP: 742794571844AA182D17BC0CC2EA25186CD4C516A4D37E87CE91F23AF03D852E

Coincidono con gli hash verificati e pubblicati durante questa sessione. SignTool/firma e timestamp sono evidenze dei test Windows dell'utente, non test rieseguiti su Linux.

## Errori corretti nel pacchetto di documentazione

1. README principale: versione, download e stato di pubblicazione obsoleti (4.0.4/4.0.3); corretti alla release GitHub 4.0.6.
2. README e changelog: sezioni duplicate; eliminate. Changelog 4.0.5/4.0.6 promosso a pubblicato e ordinato cronologicamente.
3. Guide IT/EN OEM e README italiano: false diciture di pubblicazione pendente; corrette.
4. Documento NVIDIA: falsa pubblicazione pendente e manifest web confuso con stato GitHub; distinti.
5. Manifest kraugh_it/version.json: aggiornato a 4.0.6, data e URL corretti. Il caricamento sul sito e la risposta dell'endpoint sono ancora da verificare.
6. Packaging README: distingue i due checksum pubblici -msi.sha256/-zip.sha256 dal checksum generato localmente dal builder.
7. Schema descrittivo e roadmap: duplicati rimossi; storia di sviluppo esplicitamente marcata come storia.
8. Guide eccezioni: aggiunti esempio JSON completo, istruzioni di applicazione/permessi, variazione e rimozione, differenza tra pacchetti esportati e aggiornamenti disponibili. Corretto il testo che confondeva gli avvisi dell'export con un export invalido.
9. README: non sostiene piu che il pacchetto contenga soltanto runtime; include effettivamente script di validazione app/tools. Non attribuisce alla 4.0.6 i test MSI di installazione/disinstallazione svolti sulla 4.0.4.

## Difetti e limiti aperti nel runtime firmato (NON corretti di nascosto)

- DCU: nel catch Dell di app/modules/08_oem.ps1 la chiamata Set-ModuleResult ERROR non passa Status.rebootRequired. Dopo un codice nativo 1/5 e un errore della verifica/self-update, il JSON OEM puo conservare true mentre il riepilogo dice NO. Caso gia osservato sul pilota; richiede correzione runtime e test dedicato.
- DCU self-update: il wait richiede una versione diversa dal valore precedente e cerca un nome processo specifico. Un self-update/reinstallazione che non cambia FileVersion o termina oltre 900 secondi puo produrre timeout. Non aumentare soltanto il timeout senza verificare i segnali reali.
- Winget selective pass: RebootRequired accumulato puo essere perso nei rami timeout/failure del modulo. Nessun riavvio automatico viene richiesto dal codice esaminato, ma il riepilogo deve conservare l'evidenza.
- Localizzazione: parita dei JSON non equivale a completa localizzazione. Messaggi hardcoded confermati, per esempio in 06_microsoft_update.ps1, 03_network.ps1, core/Logging.ps1 e nel launcher C++. La conformita alla regola "tutte le stringhe UI da languages" non e completa.
- Windows Server: non esiste un blocco globale del runtime. Il filtro client della GPO e esterno al repository e non e stato validato da questo archivio.
- Eccezioni: non bloccano Microsoft Update, OEM, Winget esterno a MT o self-update delle applicazioni; non garantiscono immutabilita dei componenti da installer di altri prodotti. Le prove reali eseguite erano di sola lettura; il passaggio selettivo reale non e ancora validato.
- Normal WinGet pins: l'uso di upgrade per ID esplicito puo differire da upgrade --all per pin non bloccanti. Nessuna garanzia di preservazione di tali pin e stata dimostrata dai test presenti.
- BitLocker: encrypted e un dato di cifratura, non ProtectionStatus; non distingue sospensione della protezione. Nessuna chiave di recupero viene deliberatamente esportata dal collector esaminato.

## Script baseline

Il difetto e nella funzione Invoke-Git: $ErrorActionPreference Stop converte lo stderr informativo di fetch in un'eccezione prima del controllo del codice nativo. "From https://..." non prova divergenza. Il nuovo file conserva l'interfaccia -Sync/-OutputDirectory, usa Continue soltanto intorno al processo Git, controlla subito LASTEXITCODE, non sovrascrive ZIP, produce nomi univoci e gestisce l'errore degli appunti senza perdere il baseline. Output mostrato soltanto alla fine. Il vecchio script non viene sovrascritto.

## Non dimostrato / ancora da fare

Questa e una verifica statica e di integrita dell'archivio, non una certificazione di ogni comportamento Windows. Qui non sono disponibili Windows PowerShell, Windows Installer, autenticazione AD, hardware OEM o SignTool. Le prove Windows gia riportate dall'utente sono annotate separatamente. Il nuovo helper baseline e i Markdown corretti devono essere verificati sul PC di sviluppo; nessuna modifica al runtime o ai binari firmati e inclusa.

I pacchetti 4.0.6 gia pubblicati rimangono immutati e conservano la documentazione/manifest presenti al momento della build. Non sostituirli con byte diversi sotto lo stesso nome/versione. Le correzioni documentali possono essere committate su main; il riallineamento dei pacchetti richiede una successiva distribuzione identificata correttamente.

## Aggiornamento documentale — prova MSI 4.0.6

Evidenza riferita dall'utente, non prova rieseguita durante questo aggiornamento: upgrade remoto sotto SYSTEM completato con codice 0, versione 4.0.6 verificata, file delle otto eccezioni inalterato e configurazione del task GPO conservata. La precedente priorita di installazione e verifica della conservazione sul pilota risulta completata per questa prova. Il file eccezioni validato non viene letto dalle versioni precedenti.

Il passaggio Winget selettivo reale rimane da verificare. L'esito dell'upgrade non estende le garanzie delle eccezioni agli installer o agli aggiornamenti esterni a MT.
