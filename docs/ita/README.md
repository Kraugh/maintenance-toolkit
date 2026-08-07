# Maintenance Toolkit 3.7.1

Maintenance Toolkit è uno strumento gratuito e open source per la manutenzione,
la diagnostica e la raccolta di informazioni sui sistemi Microsoft Windows.

Automatizza le operazioni più comuni, genera inventari e report e conserva log
dettagliati per facilitare il troubleshooting e documentare gli interventi.

## Autore

**Luca Miselli**  
<https://www.kraugh.it>

Sviluppato con l'indispensabile aiuto di una Rubber Duck molto paziente.

## Funzioni principali

- verifica della connettività;
- inventario hardware e software;
- report della configurazione di rete;
- creazione di un punto di ripristino;
- aggiornamenti applicativi tramite Winget;
- messaggi di stato durante le installazioni Winget più lunghe;
- aggiornamenti Microsoft Update;
- aggiornamento delle firme Microsoft Defender;
- integrazione opzionale con strumenti OEM già installati;
- DISM e SFC disponibili come controlli diagnostici;
- verifica dello stato dei dischi;
- pulizia opzionale delle cartelle TEMP;
- pulizia opzionale dei componenti Windows;
- log TXT, CSV e HTML per ogni sessione.

## Avvio

1. Estrarre l'intera cartella del Toolkit.
2. Eseguire `Avvia_Manutenzione.bat`.
3. Accettare la richiesta di elevazione amministrativa.
4. Scegliere uno o più moduli dal menu.

> **Attenzione**
>
> Non eseguire direttamente i singoli file presenti nella cartella `modules`.

## Impostazioni prudenti

Per impostazione predefinita sono disattivati:

- creazione automatica del punto di ripristino;
- DISM RestoreHealth;
- SFC Scannow;
- installazione dei driver tramite Microsoft Update;
- pulizia TEMP;
- pulizia dei componenti Windows.

Nessun modulo riavvia automaticamente il computer.

## Log

I log sono separati per computer, così il Toolkit può essere eseguito da una
chiavetta USB, da Dropbox o da una share di rete senza mescolare i risultati
provenienti da macchine diverse.

```text
logs/
└── NOME-PC/
    ├── aggiornamenti_script.log
    ├── errori_script.log
    └── YYYYMMDD-HHMMSS_NOME-PC/
        ├── sessione.log
        ├── riepilogo.txt
        ├── riepilogo.csv
        ├── riepilogo.html
        └── output dettagliati dei singoli strumenti
```

Ogni nuova operazione avviata dal menu crea una sessione distinta.

## Autotest e aggiornamenti

Dal menu principale sono disponibili:

- **T — Autotest del Toolkit**, per verificare integrità dei file, sintassi degli script, configurazione e raggiungibilità del manifest;
- **U — Cerca aggiornamenti**, per confrontare la versione installata con quella pubblicata su kraugh.it.

Da riga di comando:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\app\MaintenanceToolkit.ps1 -SelfTest
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\app\MaintenanceToolkit.ps1 -CheckUpdates
```

Il controllo aggiornamenti è accessorio: un errore di rete non impedisce l'utilizzo del Toolkit.

## Stato della versione 3.7.1

La versione corrente include:

- logger resistente ai lock temporanei di Dropbox, share e USB;
- report rete costruito in memoria e scritto una sola volta;
- heartbeat visibile durante DISM e SFC;
- classificazione dettagliata del risultato SFC;
- dettaglio degli elementi TEMP non eliminati;
- riepilogo rapido dei controlli eseguiti e non eseguiti.

Il core è stato collaudato su Windows 11 25H2. Autotest, controllo aggiornamenti
ed esecuzione del modulo Winget sono stati verificati anche su Windows 10.
I test come `SYSTEM`, Task Scheduler e Group Policy sono previsti nelle prossime fasi di sviluppo.

## Documentazione

La documentazione utente è organizzata per lingua:

- [Documentazione italiana](docs/ita/)
- [English documentation](docs/eng/)

Documenti di progetto:

- [Roadmap](project/roadmap.md)
- [Backlog](project/backlog.md)
- [Decisioni architetturali](project/decisions.md)
- [Changelog](CHANGELOG.md)

## Licenza

Maintenance Toolkit è distribuito con licenza **MIT**.

Consultare il file [LICENSE](LICENSE).

Il software viene fornito così com'è, senza garanzie. Prima di utilizzarlo su
sistemi critici o gestiti centralmente, verificarne il comportamento in un
ambiente di test e rispettare le policy dell'organizzazione.
