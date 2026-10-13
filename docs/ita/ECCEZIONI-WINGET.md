# Eccezioni Winget locali — 4.0.6

Percorso fisso: `C:\ProgramData\Kraugh\MaintenanceToolkit\exceptions\winget-exception.json`.

Il file aziendale non deve essere inserito nel repository o nelle distribuzioni pubbliche. Usare `docs/examples/winget-exception.example.json` come modello, sostituendo il nome del PC e gli ID esatti. Schema `1.0`; `computerName` deve coincidere con il nome locale, senza dominio; `excludedPackageIds` e un array di ID, senza wildcard o duplicati. Identificazione senza distinzione tra maiuscole/minuscole. Modalita `exclude_packages` oppure `block_module` (nessuna operazione Winget).

La cartella e il file devono avere proprietario Administrators o SYSTEM e permessi di scrittura riservati a questi due soggetti; i collegamenti/reparse point non sono ammessi. Il file e esterno all'albero installato: gli script MSI attuali non lo distribuiscono e non lo eliminano. Verificare la conservazione su un pilota durante l'upgrade MSI.

File assente: flusso Winget normale. File invalido, non leggibile, con ACL non conformi o relativo a un altro PC: modulo Winget in errore, nessun ripiego su upgrade globale.

Con eccezioni: export JSON dell'inventario, validazione dell'intero piano prima di installare, esclusione degli ID dichiarati, aggiornamenti individuali con --id e --exact, gestione dipendenze Winget disabilitata con --skip-dependencies. Nessun pin permanente creato o rimosso. Esportazioni incomplete o fallite bloccano l'installazione; programmi non riconosciuti dall'export non vengono aggiornati. Una scadenza complessiva limita il passaggio selettivo. I pacchetti elaborati non sono dichiarati individualmente installati senza verifica aggiuntiva.

Limite: non controlla dipendenze incorporate negli installer, autoaggiornamento dei software, Microsoft Update, OEM o operazioni amministrative esterne. Per un requisito assoluto di immutabilita scegliere block_module e valutare separatamente gli altri motori.

La presenza di eccezioni produce WARN e copertura partial; log e inventario maintenance.data.wingetExceptions conservano gli ID esclusi e gli esiti del passaggio. I futuri windows_update-exception.json o altri file non sono interpretati nella 4.0.6.
