MAINTENANCE TOOLKIT 3.0.6.2
=========================

Autore:
    Luca Miselli
    https://www.kraugh.it

Sviluppato con l'indispensabile aiuto
di una Rubber Duck molto paziente.


SCOPO
-----
Maintenance Toolkit è un orchestratore interattivo per diagnosi,
inventario, manutenzione e aggiornamento di computer Windows.

AVVIO
-----
Estrarre l'intera cartella e lanciare:

    Avvia_Manutenzione.bat

Il BAT richiede automaticamente i privilegi amministrativi.

MENU
----
È possibile:
- eseguire tutti i moduli abilitati con A;
- scegliere uno o più moduli digitandone i numeri;
- aprire la configurazione INI;
- aprire la cartella dei log.

MODULI DISPONIBILI
------------------
1  Controllo connettività
2  Inventario hardware/software
3  Report rete
4  Crea punto di ripristino
5  Aggiornamenti Winget
6  Microsoft Update
7  Microsoft Defender
8  Aggiornamenti OEM
9  DISM RestoreHealth
10 SFC Scannow
11 Salute dischi
12 Pulizia TEMP
13 Pulizia componenti Windows

SIW
---
Il modulo SIW è temporaneamente escluso dalla versione 3.0.6.2.
Il relativo sorgente è conservato come:

    modules\12_siw.ps1.disabled

Non viene mostrato nel menu e non viene eseguito.

CONFIGURAZIONE PRUDENTE
-----------------------
Sono disattivati per impostazione iniziale:
- punto di ripristino automatico;
- DISM RestoreHealth;
- SFC Scannow;
- driver tramite Microsoft Update;
- pulizia TEMP;
- pulizia componenti Windows.

DISM e SFC restano disponibili nel menu e possono essere eseguiti
singolarmente quando serve una diagnosi o una riparazione approfondita.

Nessun modulo esegue automaticamente il riavvio del computer.

LOG
---
Ogni sessione crea:

    logs\AAAAMMGG_HHMMSS\sessione.log
    logs\AAAAMMGG_HHMMSS\riepilogo.txt
    logs\AAAAMMGG_HHMMSS\riepilogo.csv
    logs\AAAAMMGG_HHMMSS\riepilogo.html

Sono inoltre mantenuti:

    logs\aggiornamenti_script.log
    logs\errori_script.log

CORREZIONI 3.0.6.2
----------------
- Winget ripete automaticamente l'upgrade quando il primo passaggio
  aggiorna App Installer/Winget e interrompe il processo.
- Microsoft Update è stato riscritto con collection e indici separati.
- Le fasi di ricerca, download e installazione sono ora visibili.
- Corretto il rilevamento degli strumenti OEM.
- SIW escluso temporaneamente.
- Migliorata la lettura dell'output Unicode di SFC.
- Distinti dischi interni e dispositivi rimovibili.
- Aggiunta firma nei sorgenti, README e riepiloghi.
- Aggiornata la versione visualizzata in menu, TXT e HTML.

============================================================
                 Maintenance Toolkit 3.0.6.2
============================================================

Autore:
    Luca Miselli
    https://www.kraugh.it

Sviluppato con l'indispensabile aiuto
di una Rubber Duck molto paziente.

Grazie per aver utilizzato Maintenance Toolkit.

============================================================


NOVITÀ 3.0.6.2
------------
- Corretto il modulo Pulizia TEMP.
- "Punto di ripristino" rinominato in "Crea punto di ripristino".
- Il riepilogo iniziale elenca correttamente i moduli selezionati.
- Al termine di un'esecuzione è possibile tornare al menu principale
  oppure uscire.
- Ogni nuova esecuzione dal menu crea una sessione di log separata.
- Il BAT non forza più il pause al termine del normale flusso interattivo.





DISTRIBUZIONE E LICENZA
-----------------------
Maintenance Toolkit 3.0.6.2 è distribuito gratuitamente con licenza MIT.

Consultare:
    LICENSE.txt
    ABOUT.txt
    README.md
    CHANGELOG.md
    ROADMAP.md
    BACKLOG.md

La licenza consente uso, modifica e ridistribuzione, purché l'avviso
di copyright e il testo della licenza siano mantenuti.


NOVITÀ 3.0.6.2
------------
I log sono ora separati per computer.

Struttura:

    logs\NOME-PC\
        aggiornamenti_script.log
        errori_script.log
        YYYYMMDD-HHMMSS_NOME-PC\
            sessione.log
            riepilogo.txt
            riepilogo.csv
            riepilogo.html

Questa organizzazione evita di mescolare i log quando il toolkit viene
eseguito da una chiavetta USB o da una cartella condivisa di rete.


CORREZIONE 3.0.6.2
------------------
- Corretta l'inizializzazione dei log introdotta nella 3.0.5.
- I percorsi dei log vengono creati solo dopo la creazione della sessione.
- In caso di errore iniziale il BAT mantiene aperta la finestra e mostra
  il codice di uscita, invece di chiudersi immediatamente.


NOVITÀ 3.0.6.2
------------
- Logger resistente a lock temporanei di Dropbox, share e USB.
- Heartbeat ogni 15 secondi durante DISM e SFC.
- SFC distingue tra sistema integro, file riparati e file non riparati.
- Nome "Crea punto di ripristino" coerente nei riepiloghi.
- Elenco dettagliato dei file TEMP non eliminati.
- Riepilogo rapido con controlli eseguiti e non eseguiti.


CORREZIONE 3.0.6.2
------------------
- Corretto il modulo Report rete durante l'esecuzione da Dropbox o share.
- Il contenuto di rete.txt viene costruito interamente in memoria.
- Il file viene scritto una sola volta tramite il logger robusto.
- Nessun'altra modifica alla logica del Toolkit.


CORREZIONE 3.0.6.2
------------------
- Corretto l'errore di formattazione del modulo Pulizia TEMP.
- Gli elementi non eliminati vengono registrati in temp_non_eliminati.txt.
- Per ogni elemento sono indicati percorso e motivo dell'errore.
- Nessun'altra modifica alla logica del Toolkit.
