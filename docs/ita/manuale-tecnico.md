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


## 11. Riga di comando ed esecuzione pianificata

Il launcher firmato `MaintenanceToolkit.exe` inoltra al runtime PowerShell i
parametri ricevuti. Le opzioni disponibili in Maintenance Toolkit 4.0.0 sono:

| Parametro | Funzione |
|---|---|
| `-RunAll` | Esegue i moduli automatici abilitati in `[Modules]` dentro `config\MaintenanceToolkit.ini`, quindi termina. |
| `-Only <Key>` | Esegue soltanto il modulo indicato per chiave, quindi termina. |
| `-SelfTest` | Esegue l'autotest integrato del Toolkit e termina. |
| `-CheckUpdates` | Controlla il manifest pubblico degli aggiornamenti e termina. |
| `-Language auto|en-US|it-IT` | Forza la lingua per la singola esecuzione. |

Le chiavi valide per `-Only` sono `Connectivity`, `Inventory`,
`NetworkReport`, `RestorePoint`, `Winget`, `MicrosoftUpdate`, `Defender`,
`OEM`, `DISM`, `SFC`, `DiskHealth`, `TempCleanup` e `ComponentCleanup`.

Esempi:

```powershell
.\MaintenanceToolkit.exe -RunAll
.\MaintenanceToolkit.exe -Only Connectivity
.\MaintenanceToolkit.exe -SelfTest
.\MaintenanceToolkit.exe -CheckUpdates
.\MaintenanceToolkit.exe -Language it-IT
```

`-RunAll` è l'equivalente da riga di comando della scelta **[A] Esegui tutti i
moduli automatici**. Non significa “esegui ogni modulo”: vengono selezionati
soltanto i moduli abilitati nella sezione `[Modules]` del file INI.

Per `-RunAll`, `-Only` e `-SelfTest` gli exit code principali sono:

| Codice | Significato |
|---:|---|
| `0` | sessione completata senza warning o errori |
| `20` | uno o più warning, nessun errore |
| `1` | uno o più errori |

`-CheckUpdates` restituisce `10` quando è disponibile un aggiornamento, `0`
quando non risultano aggiornamenti e `20` se il controllo non può essere
completato normalmente.

### 11.1 Utilità di pianificazione di Windows

Per una workstation è normalmente preferibile una pianificazione giornaliera
in una finestra in cui il PC è acceso ma poco utilizzato, per esempio pausa
pranzo, fine giornata o una finestra di manutenzione aziendale. L'esecuzione a
ogni avvio è possibile, ma tende a ripetere inutilmente Winget, Microsoft
Update e gli altri controlli a ogni riavvio.

La configurazione seguente è stata collaudata il 29 agosto 2026:

1. creare una **Attività** completa, non una semplice Attività di base;
2. selezionare **Esegui indipendentemente dalla connessione dell'utente** per
   eseguire MT in background senza mostrare la console;
3. selezionare **Esegui con i privilegi più elevati**;
4. impostare un trigger giornaliero nell'orario desiderato;
5. come **Programma/script** indicare il percorso completo di
   `MaintenanceToolkit.exe`;
6. in **Aggiungi argomenti** specificare `-RunAll`;
7. in **Avvia in** indicare la cartella radice di Maintenance Toolkit;
8. su un portatile, valutare l'esecuzione solo con alimentazione da rete e
   l'interruzione al passaggio a batteria;
9. se sono abilitati moduli che richiedono Internet, richiedere una connessione
   di rete disponibile;
10. abilitare l'avvio appena possibile dopo una pianificazione mancata;
11. scegliere **Non avviare una nuova istanza** se MT è già in esecuzione.

Esempio:

```text
Programma/script:
C:\Percorso\Maintenance-Toolkit\MaintenanceToolkit.exe

Aggiungi argomenti:
-RunAll

Avvia in:
C:\Percorso\Maintenance-Toolkit
```

Windows può richiedere la password dell'account al salvataggio della task.

Con **Esegui solo se l'utente è connesso** MT funziona comunque, ma la finestra
console è visibile. Il comportamento in background è stato verificato usando
**Esegui indipendentemente dalla connessione dell'utente**.

Dopo la creazione, effettuare almeno un test reale lasciando che sia il trigger
pianificato ad avviare MT. Verificare:

1. data e ora dell'ultima esecuzione;
2. **Risultato ultima esecuzione**;
3. la nuova cartella di sessione sotto `logs\`;
4. il contenuto di `riepilogo.txt`;
5. eventuali report prodotti sotto `reports\`.

In Utilità di pianificazione l'exit code MT `20` viene mostrato in esadecimale
come `0x14`: indica una sessione conclusa con warning e nessun errore, non un
malfunzionamento dell'infrastruttura di pianificazione.

Il riepilogo finale si trova normalmente in:

```text
logs\NOME-PC\YYYYMMDD-HHMMSS_NOME-PC\riepilogo.txt
```

Dalla cartella radice di MT è possibile leggere rapidamente l'ultimo riepilogo:

```powershell
Get-Content (Get-ChildItem .\logs\$env:COMPUTERNAME -Directory |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 |
    ForEach-Object { Join-Path $_.FullName 'riepilogo.txt' })
```

MT mantiene `NeverReboot=1` per impostazione predefinita: non aggiungere un
riavvio forzato esterno salvo che faccia parte di una politica amministrativa
esplicita.

### 11.2 Nota su Winget

MT registra e interpreta l'esito restituito da Winget, ma non può certificare
autonomamente che ogni applicazione di terze parti abbia sostituito tutti i
propri binari. Durante il collaudo è stato osservato un caso in cui
l'applicazione aperta ha interferito con l'aggiornamento e lo stato registrato
da Winget non corrispondeva ancora alla versione del binario in esecuzione.

In caso di anomalie applicative, verificare il log Winget e la versione reale
dell'applicazione.

### 11.3 Più endpoint, Active Directory e GPO

In un dominio Active Directory `-RunAll` può essere usato come azione di una
Scheduled Task distribuita tramite Group Policy Preferences:

```text
GPO computer
  -> Scheduled Task con privilegi elevati
     -> MaintenanceToolkit.exe -RunAll
```

Su molti endpoint evitare, quando possibile, che tutte le macchine inizino
contemporaneamente aggiornamenti potenzialmente pesanti. Utilità di
pianificazione permette di applicare un **ritardo casuale** al trigger per
distribuire gli avvii nel tempo.

Una copia locale controllata sui client è il punto di partenza più semplice.
L'esecuzione diretta da share SMB e l'esecuzione come `SYSTEM` richiedono invece
test specifici nel proprio ambiente: permessi share/NTFS, identità del computer
di dominio, disponibilità della rete, strategia di scrittura/raccolta dei log e
comportamento di Winget nel contesto scelto devono essere validati prima della
distribuzione generale.

Per una distribuzione professionale mantenere il pacchetto e
`config\MaintenanceToolkit.ini` sotto controllo amministrativo, usare un
gruppo pilota prima del rollout e non concedere ai client diritti di modifica
sulla sorgente centrale.

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
