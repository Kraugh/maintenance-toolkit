# Prova locale catalogo Windows — 14 ottobre 2026

Prova isolata autorizzata, eseguita sul branch `feature/4.1-self-update`. Windows PowerShell 5.1.26100.9711 e SignTool x64 del Windows SDK 10.0.26100.0 già disponibili. Nessuna dipendenza installata; nessun PIN o credenziale richiesto o salvato dall'agente.

## File e comandi

Cartella temporanea, relativa alla radice del progetto: `launcher/build/MaintenanceToolkit-CatalogTest-20261014-112409-e34275f3` (data/ora Europe/Rome). File creati: `payload/sample.txt`, `payload/sample.ps1`, `trial.cat`. Nessun task creato. Lo script contiene solo un commento e `Write-Output "catalog fixture"`; non è stato eseguito. Il catalogo è esterno a `payload`.

Comandi eseguiti, con `$Trial` che rappresenta la cartella temporanea e `$SignTool` il percorso `C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe`:

```powershell
New-FileCatalog -Path "$Trial\payload" -CatalogFilePath "$Trial\trial.cat" -CatalogVersion 2
& $SignTool sign /sha1 B5228D5E9A1CB84C10838146C10CA6C490C1A571 /s My /fd SHA256 /tr http://time.certum.pl /td SHA256 "$Trial\trial.cat"
& $SignTool verify /pa /all /tw /v "$Trial\trial.cat"
Get-AuthenticodeSignature -LiteralPath "$Trial\trial.cat"
Test-FileCatalog -Path "$Trial\payload" -CatalogFilePath "$Trial\trial.cat" -Detailed
[IO.File]::AppendAllText("$Trial\payload\sample.txt", " changed")
Test-FileCatalog -Path "$Trial\payload" -CatalogFilePath "$Trial\trial.cat" -Detailed
Get-AuthenticodeSignature -LiteralPath "$Trial\trial.cat"
```

`/sha1` seleziona il certificato tramite il thumbprint fornito; non è l'algoritmo della firma. Catalogo v2: SHA256 confermato da Test-FileCatalog. Firma e richiesta timestamp: SHA-256 tramite `/fd` e `/td`; RFC 3161 tramite `/tr`.

## Risultati verificati

- Creazione del catalogo riuscita; firma SignTool exit code 0.
- SignTool verify exit code 0: una firma verificata, zero avvisi e zero errori; timestamp verificato, riportato alle 11:24:22 del 14 ottobre 2026 nella sessione locale.
- Authenticode: `Valid`, firmatario con thumbprint esattamente `B5228D5E9A1CB84C10838146C10CA6C490C1A571`, certificato timestamp presente. Nomi personali e dettagli delle catene non riprodotti nel resoconto.
- File originali: `Test-FileCatalog` restituisce `Valid`, `HashAlgorithm=SHA256`.
- Dopo modifica di `sample.txt`: `ValidationFailed`; la firma del catalogo resta `Valid`. Firma del catalogo e corrispondenza dei file sono controlli distinti, entrambi necessari.
- SHA-256 del catalogo firmato: `BDBD4CA26A73BE3DE445F94FF354528F173FD9D5FA30CCFAC367303D5F3F2769`.

## Pulizia e limiti

La cartella temporanea e i tre file sono rimossi dopo verifica, controllando il percorso assoluto sotto `launcher/build`; conservato solo questo resoconto. Nessun runtime, versione, manifest o pacchetto reale modificato; nessun commit, push, tag o release.

La prova dimostra creazione, firma/timestamp e verifica del catalogo e rilevamento della modifica di un file fittizio. Non valida il futuro updater, il packaging MSI/ZIP, recovery, ripresa della manutenzione, rotazione certificati o comportamento offline/revoca. Non configura fiducia nel produttore sui client né installa il catalogo nel database Windows.
