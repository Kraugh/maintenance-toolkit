# Manuale tecnico — Maintenance Toolkit 4.0

**Versione documento:** 2.0  
**Compatibile con:** Maintenance Toolkit `4.0.0-rc.1`  
**Aggiornato:** 8 agosto 2026

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
5. Avviare `Avvia_Manutenzione.bat`.
6. Accettare l'elevazione amministrativa.

Non avviare direttamente `app/MaintenanceToolkit.ps1` o i singoli script sotto
`app/modules`, salvo attività di sviluppo o troubleshooting consapevole.

### Sblocco da PowerShell

Dopo avere verificato che lo ZIP provenga dalla release ufficiale:

```powershell
Unblock-File .\Maintenance-Toolkit-4.0.0-rc.1.zip
```

Riestrarre quindi l'archivio.

## 4. Struttura runtime

La struttura essenziale della release è:

```text
Maintenance-Toolkit-4.0.0-rc.1/
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

### Limite noto della RC1: sospensione

La RC1 non impedisce ancora a Windows di entrare in sospensione. Prima di
operazioni lunghe impostare temporaneamente il sistema affinché non vada in
sleep. Il display può spegnersi normalmente.

## 11. Interpretazione degli esiti

Gli stati `OK`, `INFO`, `WARN` ed `ERROR` devono essere letti nel contesto.

Un warning non implica necessariamente un guasto. Per esempio:

- un gateway può non rispondere a ICMP ma continuare a instradare traffico;
- una VPN può usare DNS pubblici intenzionalmente;
- un tool opzionale può non essere presente.

Per il troubleshooting approfondito consultare sempre report ed evidenze JSON.

## 12. Troubleshooting rapido

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

## 13. Validazione RC1

La RC1 è stata provata su:

- Windows 11 fisico;
- Windows 10 22H2 con Windows PowerShell 5.1;
- Windows 11 in Hyper-V;
- Ethernet e Wi-Fi;
- scenari senza VPN attiva;
- Quick Diagnosis e Technical Report.

La validazione di una VPN realmente connessa resta desiderabile prima della
release stabile 4.0.0.

## 14. Supporto e aggiornamenti

Prima di segnalare un problema verificare la versione utilizzata e consultare
GitHub Releases.

Per una segnalazione tecnica allegare, quando possibile:

- versione MT;
- versione Windows;
- passaggi per riprodurre il problema;
- log/report pertinenti, dopo averli controllati per informazioni sensibili.

Repository: <https://github.com/Kraugh/maintenance-toolkit>  
Sito: <https://www.kraugh.it>
