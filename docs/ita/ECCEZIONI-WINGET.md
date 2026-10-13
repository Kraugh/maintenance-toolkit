# Eccezioni Winget locali — 4.0.6

Percorso fisso: `C:\ProgramData\Kraugh\MaintenanceToolkit\exceptions\winget-exception.json`.

Il file aziendale non deve essere inserito nel repository o nelle distribuzioni pubbliche. Usare `docs/examples/winget-exception.example.json` come modello, sostituendo il nome del PC e gli ID esatti. Schema `1.0`; `computerName` deve coincidere con il nome locale, senza dominio; `excludedPackageIds` è un array di ID, senza wildcard o duplicati. Identificazione senza distinzione tra maiuscole/minuscole. Modalità `exclude_packages` oppure `block_module` (nessuna operazione Winget).

La cartella e il file devono avere proprietario Administrators o SYSTEM e permessi di scrittura riservati a questi due soggetti; i collegamenti/reparse point non sono ammessi. Il file è esterno all'albero installato: gli script MSI attuali non lo distribuiscono e non lo eliminano. L'utente ha riferito un upgrade MSI remoto sotto SYSTEM completato con codice 0: versione 4.0.6 verificata, file delle otto eccezioni inalterato e configurazione del task GPO conservata. Questa prova pilota non valida il passaggio Winget selettivo reale, che rimane da verificare.

File assente: flusso Winget normale. File invalido, non leggibile, con ACL non conformi o relativo a un altro PC: modulo Winget in errore, nessun ripiego su upgrade globale.

Con eccezioni: export JSON dell'inventario, validazione dell'intero piano prima di installare, esclusione degli ID dichiarati, aggiornamenti individuali con --id e --exact, gestione dipendenze Winget disabilitata con --skip-dependencies. Nessun pin permanente creato o rimosso. Esportazioni strutturalmente invalide o con codice di errore bloccano l'installazione; gli avvisi per programmi non riconosciuti non invalidano un export con codice 0 e quei programmi non vengono aggiornati. Una scadenza complessiva limita il passaggio selettivo. I pacchetti elaborati non sono dichiarati individualmente installati senza verifica aggiuntiva.

Limite: non controlla dipendenze incorporate negli installer, autoaggiornamento dei software, Microsoft Update, OEM o operazioni amministrative esterne. Per un requisito assoluto di immutabilità scegliere block_module e valutare separatamente gli altri motori.

La presenza di eccezioni produce WARN e copertura partial; log e inventario maintenance.data.wingetExceptions conservano gli ID esclusi e gli esiti del passaggio. I futuri windows_update-exception.json o altri file non sono interpretati nella 4.0.6.

## Esempio completo e applicazione

```json
{
  "schemaVersion": "1.0",
  "computerName": "TARGET-PC",
  "mode": "exclude_packages",
  "excludedPackageIds": [
    "Vendor.ProtectedPackage"
  ]
}
```

1. Sul PC destinatario, in PowerShell amministrativa, creare il file nel percorso fisso. Non salvarlo nella cartella del repository o accanto all'EXE.
2. Sostituire TARGET-PC con `$env:COMPUTERNAME` e Vendor.ProtectedPackage con gli ID realmente riconosciuti dall'export Winget della macchina.
3. Assegnare alla cartella e al file proprietario Administrators (SID S-1-5-32-544), rimuovere l'ereditarietà dei permessi e concedere FullControl soltanto a questo SID e SYSTEM (S-1-5-18). Verificare accesso sotto SYSTEM.
4. Con `exclude_packages` l'array non può essere vuoto. Per `block_module` usare lo stesso schema con `mode` uguale a `block_module` e `excludedPackageIds: []`.
5. Verificare il piano in sola lettura prima di abilitare la manutenzione. EXE, BAT e PS1 della 4.0.6 leggono la medesima policy; le versioni precedenti la ignorano.
6. Controllare log e `maintenance.data.wingetExceptions`: `excluded` non significa aggiornato. I 37 o altri pacchetti "ammessi" non sono necessariamente tutti aggiornamenti disponibili; sono candidati installati associati all'export.
7. Un export con codice 0 può avere avvisi per programmi non riconosciuti: quei programmi sono fuori dal piano. Il file deve rimanere sul PC durante aggiornamenti e riavvii.

Per cambiare gli ID, conservare un backup prima della modifica e rivalidare la policy. Per rimuovere volontariamente tutte le eccezioni, archiviare il file fuori dalla cartella exceptions; non lasciare un file vuoto o invalido. Alla successiva esecuzione riprende il flusso globale.
