# Aggiornamenti OEM

**Compatibile con:** Maintenance Toolkit `4.0.3` e versioni successive

Il modulo OEM installa gli aggiornamenti idonei del produttore mantenendo tre vincoli di sicurezza: il BIOS non viene mai installato automaticamente, Windows non viene mai riavviato automaticamente e gli aggiornamenti non-BIOS non possono iniziare senza un punto di ripristino verificato.

## Produttori supportati

| Produttore | Integrazione | Comportamento |
|---|---|---|
| Dell | CLI Dell Command Update con firma Authenticode valida, installata automaticamente tramite Winget quando assente | Controlla separatamente il BIOS; installa soltanto le categorie non-BIOS. |
| HP | Pacchetto HP Image Assistant firmato e acquisito da HP | Analizza le raccomandazioni e installa gli aggiornamenti non-BIOS idonei. Il BIOS richiede una conferma esplicita e interattiva. |

Un produttore non supportato viene indicato come `SKIP`, non come errore.

## Prerequisito Ripristino configurazione di sistema

Prima di applicare driver, firmware, applicazioni o utilità, MT crea oppure riutilizza un punto di ripristino della sessione e verifica che sia stato realmente registrato. Se Ripristino configurazione di sistema è disabilitato o il punto non può essere verificato, il modulo OEM si arresta senza installare aggiornamenti.

Sui computer gestiti dal dominio configurare nella stessa GPO computer usata per Maintenance Toolkit:

**Configurazione computer → Criteri → Modelli amministrativi → Sistema → Ripristino configurazione di sistema → Disattiva Ripristino configurazione di sistema = Disabilitata**

`Disabilitata` significa che viene disabilitata la policy che spegnerebbe Ripristino configurazione di sistema. La GPO deve prevalere su eventuali policy ereditate che impostano **Disattiva Ripristino configurazione di sistema** su `Abilitata`: collegarla alla OU figlia interessata oppure assegnarle l'ordine di collegamento vincente. Dopo l'aggiornamento delle policy, verificare il criterio risultante su un computer pilota prima di abilitare gli aggiornamenti OEM in produzione.

MT prova ad abilitare la protezione dell'unità di sistema, ma non aggira una policy di dominio che vieta Ripristino configurazione di sistema.

## Flusso Dell

1. Rileva l'hardware Dell indipendentemente dalla presenza di Dell Command Update.
2. Se DCU manca, crea e verifica il punto di ripristino, installa silenziosamente il pacchetto esatto `Dell.CommandUpdate` dalla sorgente Winget, quindi individua la CLI e ne convalida la firma Authenticode Dell. Se Winget non è disponibile o la verifica fallisce, si arresta senza controllare né applicare aggiornamenti.
3. Esegue un controllo riservato al BIOS e segnala un BIOS disponibile come azione urgente senza installarlo.
4. Esegue un controllo separato non-BIOS per driver, firmware, applicazioni, utilità e altre categorie supportate.
5. Se esistono aggiornamenti idonei e nella sessione non esiste ancora un punto di ripristino, lo crea e lo verifica.
6. Applica l'esatta selezione non-BIOS con il riavvio automatico disabilitato.
7. Se Dell Command Update aggiorna sé stesso tramite un installer separato, attende fino a 15 minuti e convalida firma e versione del nuovo eseguibile.
8. Esegue un nuovo controllo; se DCU sta ancora finalizzando il proprio aggiornamento e non produce il report XML, riprova per un massimo di 15 minuti.
9. Classifica ogni aggiornamento tentato come installato, ancora applicabile oppure non verificabile e registra separatamente l'eventuale riavvio richiesto.

I codici DCU `0`, `1` e `500` vengono interpretati in base all'operazione. Il codice `500` durante un controllo indica che non è stato trovato alcun aggiornamento applicabile. Altri codici e report XML mancanti o non validi non vengono considerati un successo.

## Flusso HP

HP Image Assistant viene scaricato soltanto dalla sorgente HP attendibile configurata e la firma viene convalidata. Gli aggiornamenti non-BIOS idonei possono essere installati dopo il controllo del punto di ripristino. L'installazione del BIOS è bloccata nelle sessioni pianificate, GPO, `SYSTEM` e in ogni esecuzione non interattiva. In una console interattiva, una raccomandazione BIOS HP critica usa una conferma guidata separata e verifica riavvio pendente e disponibilità della chiave di ripristino BitLocker.

## Esecuzione e verifica del pilot

Da una console elevata eseguire soltanto il modulo OEM:

```powershell
.\MaintenanceToolkit.exe -Only OEM
```

Iniziare da un computer di test o da una OU pilota. Collegare l'alimentazione, chiudere le applicazioni di lavoro e lasciare terminare gli installer del produttore. Non interrompere il processo soltanto perché rimane senza output per alcuni minuti.

Controllare il riepilogo finale, il log dettagliato della sessione e `oem-status.json`. L'exit code del processo non sostituisce l'esito della verifica successiva all'installazione. Un riavvio richiesto viene registrato, ma non viene mai eseguito automaticamente.

Prima di un pilot in produzione verificare che il dispositivo abbia un backup, che la chiave BitLocker sia depositata, che non vi siano riavvii pendenti e che sia attiva una finestra di manutenzione.

Dopo l'installazione di driver o firmware, il riavvio può lasciare il computer senza rete e non raggiungibile da RDP per diversi minuti. Non interrompere l'alimentazione durante questa fase. Se viene richiesto un aggiornamento BIOS, eseguirlo separatamente in una finestra controllata, con alimentazione stabile e chiave di ripristino BitLocker disponibile.

## Canali di rilascio

`4.0.3` è la release stabile che introduce il flusso OEM protetto. È distribuita come archivio portabile e come MSI x64 firmato; entrambi gli artefatti pubblici sono accompagnati dal relativo checksum SHA-256.
