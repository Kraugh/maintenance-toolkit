MAINTENANCE TOOLKIT 3.7.0
===========================

Strumento gratuito e open source per la manutenzione, la diagnostica
e la raccolta di informazioni sui sistemi Microsoft Windows.

AUTORE
------
Luca Miselli
https://www.kraugh.it

Sviluppato con l'indispensabile aiuto
di una Rubber Duck molto paziente.


SCOPO
-----
Maintenance Toolkit automatizza operazioni ripetitive di manutenzione,
inventario, aggiornamento e diagnosi dei computer Windows.

Ogni esecuzione produce log dettagliati e un riepilogo consultabile
in formato TXT, CSV e HTML.


AVVIO
-----
1. Estrarre l'intera cartella.
2. Eseguire:

       Avvia_Manutenzione.bat

3. Accettare la richiesta di elevazione amministrativa.
4. Scegliere uno o più moduli dal menu.

Non eseguire direttamente i singoli script della cartella "modules".


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
Il modulo SIW è temporaneamente escluso dalla versione 3.7.0.

Il relativo sorgente è conservato come:

    modules\12_siw.ps1.disabled


CONFIGURAZIONE PRUDENTE
-----------------------
Sono disattivati per impostazione predefinita:

- creazione automatica del punto di ripristino;
- DISM RestoreHealth;
- SFC Scannow;
- installazione dei driver tramite Microsoft Update;
- pulizia TEMP;
- pulizia dei componenti Windows.

Nessun modulo riavvia automaticamente il computer.


LOG
---
I log sono separati per computer:

    logs\NOME-PC\
        aggiornamenti_script.log
        errori_script.log
        YYYYMMDD-HHMMSS_NOME-PC\
            sessione.log
            riepilogo.txt
            riepilogo.csv
            riepilogo.html
            output dettagliati dei singoli strumenti

Questa struttura consente di usare il Toolkit da USB, Dropbox o share
senza mescolare i risultati provenienti da computer diversi.


STATO DELLA VERSIONE 3.7.0
----------------------------
- Logger resistente ai lock temporanei di Dropbox, share e USB.
- Report rete costruito in memoria e scritto una sola volta.
- Heartbeat visibile durante DISM e SFC.
- Classificazione dettagliata del risultato SFC.
- Dettaglio degli elementi TEMP non eliminati.
- Riepilogo rapido dei controlli eseguiti e non eseguiti.

Il core è stato collaudato su Windows 11 25H2.
I test su Windows 10, SYSTEM, Task Scheduler e Group Policy
sono previsti nelle prossime fasi di sviluppo.


DOCUMENTAZIONE
--------------
Consultare:

    README.md
    CHANGELOG.md
    ROADMAP.md
    BACKLOG.md
    DECISIONS.md
    docs\ita\
    docs\eng\


DISTRIBUZIONE E LICENZA
-----------------------
Maintenance Toolkit è distribuito gratuitamente con licenza MIT.

Consultare:

    LICENSE
    ABOUT.txt

Il software viene fornito così com'è, senza garanzie.
Prima dell'uso su sistemi critici, verificarne il comportamento
in un ambiente di test e rispettare le policy dell'organizzazione.
