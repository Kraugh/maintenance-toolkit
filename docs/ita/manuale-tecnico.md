# Manuale tecnico — Maintenance Toolkit 4.0

**Versione documento:** 2.1
**Compatibile con:** Maintenance Toolkit `4.0.0`
**Aggiornato:** 29 agosto 2026

## 1. Scopo

Maintenance Toolkit automatizza attività ripetitive di manutenzione, diagnosi e
raccolta dati sui sistemi Windows. È pensato per tecnici e amministratori di
sistema e non sostituisce la valutazione tecnica dell'operatore.

La serie 4.0 integra nello stesso menu sia i moduli di manutenzione tradizionali
sia il dominio Network Diagnostics.

## 2. Requisiti

- Windows 10 o Windows 11;
- Windows PowerShell 5.1 compatibile;
- privilegi amministrativi per le funzioni che li richiedono;
- connessione Internet per Winget, Microsoft Update, controllo aggiornamenti e
  SpeedTest;
- spazio libero sufficiente per aggiornamenti, log e report.

Prima di una manutenzione lunga è consigliabile chiudere le applicazioni non
necessarie.

## 3. Installazione

Maintenance Toolkit è portabile e non richiede installazione.

1. Scaricare il pacchetto ZIP dalla release ufficiale GitHub.
2. Verificare il SHA-256 quando richiesto dalle proprie procedure.
3. Su Windows 11, se il pacchetto è marcato come proveniente da Internet,
   verificare l'origine e utilizzare **Proprietà → Sblocca** sullo ZIP prima
   dell'estrazione.
4. Estrarre completamente il contenuto.
5. Avviare `MaintenanceToolkit.exe` (oppure `Avvia_Manutenzione.bat` come fallback).
6. Accettare l'elevazione amministrativa.

Non avviare direttamente `app/MaintenanceToolkit.ps1` o i singoli script sotto
`app/modules`, salvo attività di sviluppo o troubleshooting consapevole.

### Sblocco da PowerShell

Dopo avere verificato che lo ZIP provenga dalla release ufficiale:

```powershell
Unblock-File .\Maintenance-Toolkit-4.0.0.zip
```

Riestrarre quindi l'archivio.

## 4. Struttura runtime

La struttura essenziale della release è:

```text
Maintenance-Toolkit-4.0.0/
├── Avvia_Manutenzione.bat
├── app/
├── config/
├── docs/
├── languages/
├── rules/
└── themes/
```

`logs/` e `reports/` vengono creati durante l'uso. `external/` non viene
distribuita nel pacchetto pubblico.

## 5. Menu e moduli

Il launcher apre il menu principale di Maintenance Toolkit con privilegi
amministrativi.

I moduli di manutenzione possono essere eseguiti singolarmente oppure secondo
le modalità offerte dal menu. Tra le principali funzioni:

- connettività e inventario;
- Winget;
- Microsoft Update;
- Microsoft Defender;
- punto di ripristino;
- DISM e SFC;
- stato dischi;
- pulizie opzionali.

Le impostazioni più invasive sono disattivate di default.

## 6. Network Diagnostics

Il sottomenu Network Diagnostics offre:

- `N1` — Diagnosi rapida;
- `N2` — Report tecnico;
- `N3` — Diagnosi rapida + SpeedTest;
- `N4` — Report tecnico + SpeedTest.

La diagnostica analizza, quando disponibile:

- interfaccia logica e backend fisico;
- gateway e route predefinite;
- DNS e test di risoluzione;
- DHCP;
- APIPA;
- MTU;
- metrica interfaccia;
- velocità link;
- presenza e stato VPN;
- route VPN e modalità split/full tunnel;
- anomalie individuate dal Rules Engine.

Una mancata risposta ICMP del gateway viene segnalata come warning: non prova da
sola l'assenza di connettività, perché alcuni gateway possono filtrare ICMP.

## 7. SpeedTest opzionale

Le opzioni `N3` e `N4` possono utilizzare Ookla Speedtest CLI.

Percorso preferito:

```text
external\speedtest.exe
```

In alternativa l'eseguibile può essere disponibile nel `PATH`.

Maintenance Toolkit non scarica né distribuisce automaticamente SpeedTest. La
sua assenza deve produrre un avviso, non interrompere la diagnostica.

## 8. Report

I report di Network Diagnostics vengono salvati sotto `reports/`.

Una singola esecuzione può produrre:

```text
MT4-NET-N2-Technical-PC-YYYYMMDD-HHMMSS.txt
MT4-NET-N2-Technical-PC-YYYYMMDD-HHMMSS-Topology.json
MT4-NET-N2-Technical-PC-YYYYMMDD-HHMMSS-Rules.json
```

Le opzioni con SpeedTest aggiungono il relativo JSON.

Il TXT è pensato per la consultazione umana; i JSON conservano evidenze
strutturate utili per analisi successive.

## 9. Log operativi

I log della manutenzione tradizionale sono mantenuti sotto `logs/` e separati
per computer/sessione.

In caso di assistenza, è preferibile conservare l'intera cartella della
sessione. Prima di pubblicare log o report, verificarne il contenuto.

## 10. Operazioni lunghe

Winget, Microsoft Update, DISM e SFC possono richiedere da pochi minuti a
diverse ore su sistemi non aggiornati.

Il Toolkit mostra messaggi periodici per indicare che l'operazione è ancora in
corso.

### Gestione della sospensione

Durante una sessione Maintenance Toolkit richiede a Windows di mantenere attivo
il sistema, senza forzare il display a rimanere acceso. La richiesta resta valida
per la durata del processo MT.


## 11. Esecuzione non interattiva e pianificata

Maintenance Toolkit 4.0.0 supporta la modalità non interattiva `-RunAll`:

```powershell
.\MaintenanceToolkit.exe -RunAll
```

`-RunAll` è l'equivalente da riga di comando della scelta **[A] Esegui tutti i
moduli automatici**. Non esegue indiscriminatamente ogni modulo: seleziona i
moduli abilitati nella sezione `[Modules]` di `config\MaintenanceToolkit.ini`.
Al termine MT restituisce un exit code e chiude la sessione senza tornare al
menu interattivo.

Il launcher `MaintenanceToolkit.exe` richiede privilegi amministrativi. Per una
esecuzione pianificata è preferibile creare l'attività direttamente con
**Esegui con i privilegi più elevati**, così l'avvio non dipende da una conferma
UAC interattiva.

### Utilità di pianificazione di Windows

Per una workstation sempre aggiornata è normalmente preferibile una
pianificazione giornaliera in una finestra in cui il PC è acceso ma poco usato,
per esempio pausa pranzo, fine giornata o una finestra di manutenzione aziendale.
L'esecuzione a ogni avvio è possibile, ma in genere è meno opportuna: Winget,
Microsoft Update e gli altri controlli verrebbero ripetuti a ogni riavvio.

Configurazione consigliata:

1. creare una nuova attività in **Utilità di pianificazione**;
2. selezionare **Esegui con i privilegi più elevati**;
3. impostare un trigger giornaliero nell'orario scelto;
4. come programma indicare il percorso completo di `MaintenanceToolkit.exe`;
5. nel campo degli argomenti specificare `-RunAll`;
6. impostare **Avvia in** sulla cartella radice di Maintenance Toolkit;
7. verificare manualmente una prima esecuzione e controllare il riepilogo e i
   log prima di affidarsi alla pianificazione.

Se il computer può essere spento all'ora prevista, valutare nelle proprietà
dell'attività l'opzione per eseguirla appena possibile dopo un avvio pianificato
non riuscito. Evitare invece di forzare riavvii automatici: MT mantiene
`NeverReboot=1` per impostazione predefinita.

### Distribuzione centralizzata con Active Directory / GPO

In un dominio Active Directory `-RunAll` può essere usato come base per una
Scheduled Task distribuita tramite Group Policy Preferences. Il modello
consigliato è:

```text
GPO computer
  -> Scheduled Task con privilegi elevati
     -> MaintenanceToolkit.exe -RunAll
```

MT può essere mantenuto localmente sui client oppure richiamato da una share
SMB amministrata centralmente. La seconda soluzione richiede però una verifica
preventiva nel proprio ambiente. Se l'attività viene eseguita come `SYSTEM`,
l'accesso alla rete usa normalmente l'identità del computer di dominio; di
conseguenza permessi share e NTFS devono consentire la lettura ai computer
interessati (per esempio tramite un gruppo AD dedicato).

Per una distribuzione professionale:

- usare una share in sola lettura per i client e limitare la scrittura agli
  amministratori che pubblicano MT;
- mantenere `config\MaintenanceToolkit.ini` sotto controllo amministrativo;
- verificare prima il comportamento di Winget e degli altri moduli nel contesto
  scelto (`SYSTEM` o account di servizio);
- considerare che `logs\` è scritto nella radice di MT: l'esecuzione diretta da
  una share richiede quindi anche una strategia esplicita per i permessi e la
  raccolta dei log;
- effettuare un test pilota su pochi computer prima di estendere la GPO.

L'esecuzione da share SMB e il funzionamento di tutti i moduli come `SYSTEM`
sono scenari da validare nell'ambiente di destinazione: questa guida non li
considera automaticamente equivalenti a un'esecuzione locale interattiva.

## 12. Interpretazione degli esiti

Gli stati `OK`, `INFO`, `WARN` ed `ERROR` devono essere letti nel contesto.

Un warning non implica necessariamente un guasto. Per esempio:

- un gateway può non rispondere a ICMP ma continuare a instradare traffico;
- una VPN può usare DNS pubblici intenzionalmente;
- un tool opzionale può non essere presente.

Per il troubleshooting approfondito consultare sempre report ed evidenze JSON.

## 13. Troubleshooting rapido

### Il Toolkit non parte

- verificare di avere estratto tutto lo ZIP;
- avviare `Avvia_Manutenzione.bat`;
- verificare eventuali blocchi Smart App Control / Mark of the Web;
- non disattivare globalmente le protezioni di Windows solo per eseguire MT.

### Un modulo termina con errore

Consultare riepilogo e log della sessione. Quando possibile, gli altri moduli
continuano comunque.

### Network Diagnostics segnala il gateway

Verificare se il gateway risponde effettivamente a ICMP. Se DNS e traffico IP
funzionano, il warning può essere dovuto al filtraggio degli echo request.

### La manutenzione sembra ferma

Controllare i messaggi di avanzamento. Aggiornamenti Windows e installer
applicativi possono richiedere molto tempo.

## 14. Validazione 4.0.0

La serie 4.0 è stata provata su:

- Windows 11 fisico;
- Windows 10 22H2 con Windows PowerShell 5.1;
- Windows 11 in Hyper-V;
- Ethernet e Wi-Fi;
- scenari senza VPN attiva;
- Quick Diagnosis e Technical Report.


## 15. Supporto e aggiornamenti

Prima di segnalare un problema verificare la versione utilizzata e consultare
GitHub Releases.

Per una segnalazione tecnica allegare, quando possibile:

- versione MT;
- versione Windows;
- passaggi per riprodurre il problema;
- log/report pertinenti, dopo averli controllati per informazioni sensibili.

Repository: <https://github.com/Kraugh/maintenance-toolkit>
Sito: <https://www.kraugh.it>
