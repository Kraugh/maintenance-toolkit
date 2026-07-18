# Maintenance Toolkit 3.0.6.2

Maintenance Toolkit è uno strumento gratuito e open source pensato per
sistemisti e tecnici Windows.

Automatizza le operazioni di manutenzione più comuni, genera inventari e
report e conserva log dettagliati per facilitare il troubleshooting.

## Autore

**Luca Miselli**  
https://www.kraugh.it

Sviluppato con l'indispensabile aiuto di una Rubber Duck molto paziente.

## Funzioni principali

- verifica della connettività;
- inventario hardware e software;
- report della configurazione di rete;
- creazione di un punto di ripristino;
- aggiornamenti applicativi tramite Winget;
- aggiornamenti Microsoft Update;
- aggiornamento delle firme Microsoft Defender;
- integrazione opzionale con strumenti OEM già installati;
- DISM e SFC disponibili come controlli diagnostici;
- verifica dello stato dei dischi;
- log TXT, CSV e HTML per ogni sessione.

## Avvio

1. Estrarre l'intera cartella.
2. Eseguire `Avvia_Manutenzione.bat`.
3. Accettare la richiesta di elevazione amministrativa.
4. Scegliere uno o più moduli dal menu.

Non eseguire singoli file della cartella `modules` direttamente.

## Impostazioni prudenti

Per impostazione predefinita sono disattivati:

- creazione automatica del punto di ripristino;
- DISM RestoreHealth;
- SFC Scannow;
- driver tramite Microsoft Update;
- pulizia TEMP;
- pulizia dei componenti Windows.

Nessun modulo riavvia automaticamente il computer.

## Log

I log sono separati per computer, così il toolkit può essere eseguito
da una chiavetta USB o da una share di rete senza mescolare le macchine.

La struttura è:

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

## Stato del progetto

- Core operativo: collaudato su Windows 11 25H2.
- Distribuzione GPO e Task Scheduler: prevista in un progetto separato.
- Driver e firmware OEM: sviluppo futuro.
- Diagnostica avanzata: sviluppo futuro.

## Licenza

Maintenance Toolkit è distribuito con licenza **MIT**.

Consultare [LICENSE.txt](LICENSE.txt).

Il software viene fornito così com'è, senza garanzie. Prima di utilizzarlo
su sistemi critici o gestiti centralmente, verificarne il comportamento in
un ambiente di test e rispettare le policy dell'organizzazione.


## Correzione 3.0.6.2

La versione 3.0.6.2 corregge un errore di inizializzazione dei log presente
nella 3.0.5. In caso di errore iniziale il launcher mantiene ora visibile
la finestra con il codice di uscita.


## Novità 3.0.6.2

- logger resistente ai lock temporanei di Dropbox, share e USB;
- heartbeat visibile durante DISM e SFC;
- interpretazione dettagliata del risultato SFC;
- dettaglio dei file TEMP non eliminati;
- riepilogo rapido dei controlli eseguiti e mancanti.


## Correzione 3.0.6.2

Il modulo **Report rete** costruisce ora il contenuto interamente in memoria e scrive `rete.txt` una sola volta. Questo evita lock transitori durante l'esecuzione da Dropbox o da una share di rete.


## Correzione 3.0.6.2

Il modulo **Pulizia TEMP** non genera più l'errore di formattazione.
Quando alcuni elementi non possono essere rimossi, crea il file
`temp_non_eliminati.txt` con percorso e motivo dell'errore.
