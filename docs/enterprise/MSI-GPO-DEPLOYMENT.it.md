# Distribuzione enterprise — MSI e Group Policy

Questa guida descrive il percorso supportato per installare Maintenance Toolkit 4.0.2 manualmente o tramite Active Directory. Rimane volutamente concentrata sul percorso corretto, senza raccogliere tutti i possibili casi di troubleshooting specifici di un ambiente.

## 1. Modello di distribuzione

Maintenance Toolkit utilizza lo stesso runtime in entrambi i formati:

- ZIP portabile per uso manuale e sul campo;
- MSI x64 per-machine per installazione locale e distribuzione centralizzata.

L'MSI installa MT in:

```text
C:\Program Files\Kraugh\Maintenance Toolkit
```

La pianificazione deve avere un solo proprietario:

- MSI standalone: l'MSI può creare `\Kraugh\Maintenance Toolkit - MSI Managed`;
- Active Directory: installare con `CREATE_TASK=0` e affidare a Group Policy Preferences un'attività separata.

Maintenance Toolkit non deve essere eseguito come Domain Administrator e non riavvia mai automaticamente il computer.

## 2. Prerequisiti

- Windows x64 supportato dall'organizzazione;
- diritti amministrativi locali oppure distribuzione software assegnata al computer;
- `MaintenanceToolkit-4.0.2-x64.msi` firmato e proveniente dalla release ufficiale;
- accesso di rete richiesto dai moduli MT abilitati;
- per la pubblicazione dell'inventario, una destinazione SMB dedicata e scrivibile dagli account computer.

Prima della produzione, validare MSI, policy, account di esecuzione e permessi della share su un computer o una OU pilota.

## 3. Verificare il pacchetto

In Esplora file aprire **Proprietà → Firme digitali** e verificare che la firma sia valida e appartenga all'editore previsto.

Verifica PowerShell:

```powershell
$r = Get-AuthenticodeSignature '.\MaintenanceToolkit-4.0.2-x64.msi' | Select-Object Status,StatusMessage,@{N='Signer';E={$_.SignerCertificate.Subject}},@{N='Timestamp';E={$_.TimeStamperCertificate.Subject}} | Format-List | Out-String -Width 500; $r | Set-Clipboard; $r
```

Verifica SHA-256:

```powershell
$r = Get-FileHash '.\MaintenanceToolkit-4.0.2-x64.msi' -Algorithm SHA256 | Format-List | Out-String -Width 500; $r | Set-Clipboard; $r
```

Confrontare il risultato con il checksum pubblicato insieme all'asset della release.

## 4. Installazione manuale e silenziosa

Per l'installazione interattiva avviare l'MSI con privilegi amministrativi.

Installazione silenziosa per-machine senza attività gestita dall'MSI:

```powershell
msiexec.exe /i ".\MaintenanceToolkit-4.0.2-x64.msi" /qn /norestart CREATE_TASK=0 /L*v "$env:TEMP\MaintenanceToolkit-4.0.2-install.log"
```

Installazione standalone con attività giornaliera opzionale:

```powershell
msiexec.exe /i ".\MaintenanceToolkit-4.0.2-x64.msi" /qn /norestart CREATE_TASK=1 TASK_TIME=03:00 INVENTORY_SHARE="\\SERVER\MT" /L*v "$env:TEMP\MaintenanceToolkit-4.0.2-install.log"
```

| Proprietà | Predefinito | Funzione |
|---|---:|---|
| `CREATE_TASK` | `0` | Impostare a `1` soltanto per l'attività standalone gestita dall'MSI. |
| `TASK_TIME` | `03:00` | Ora giornaliera dell'attività gestita dall'MSI. |
| `INVENTORY_SHARE` | vuoto | Destinazione UNC opzionale degli snapshot Inventory. |

## 5. Verificare l'installazione

La versione canonica installata proviene da `config\version.json`, non da un inesistente parametro `-Version` né dai metadati del launcher:

```powershell
$r = "MT " + (Get-Content 'C:\Program Files\Kraugh\Maintenance Toolkit\config\version.json' -Raw | ConvertFrom-Json).Version; $r | Set-Clipboard; $r
```

Verificare la presenza di `MaintenanceToolkit.exe`. Se è stato usato `CREATE_TASK=1`, verificare anche `\Kraugh\Maintenance Toolkit - MSI Managed` e la prossima esecuzione.

## 6. Aggiornamento

Maintenance Toolkit mantiene stabile l'`UpgradeCode` MSI. Distribuire la nuova versione approvata come normale major upgrade:

```powershell
msiexec.exe /i ".\MaintenanceToolkit-NUOVAVERSIONE-x64.msi" /qn /norestart CREATE_TASK=0 /L*v "$env:TEMP\MaintenanceToolkit-upgrade.log"
```

Per GPO usare cartelle sorgente versionate:

```text
\\SERVER\Software\MaintenanceToolkit\
    4.0.2\MaintenanceToolkit-4.0.2-x64.msi
    NUOVAVERSIONE\MaintenanceToolkit-NUOVAVERSIONE-x64.msi
```

Eseguire un pilot prima di modificare l'assegnazione in produzione. Non sostituire silenziosamente il file MSI già assegnato nella stessa posizione.

## 7. Disinstallazione

Usare **App installate**, lo strumento aziendale di gestione software oppure l'MSI originale:

```powershell
msiexec.exe /x ".\MaintenanceToolkit-4.0.2-x64.msi" /qn /norestart /L*v "$env:TEMP\MaintenanceToolkit-4.0.2-uninstall.log"
```

La disinstallazione rimuove soltanto l'attività con nome univoco gestita dall'MSI. L'attività GPO resta di proprietà della Group Policy e deve essere rimossa o disabilitata nella policy.

## 8. Distribuzione MSI tramite Active Directory

1. Copiare l'MSI approvato in una cartella UNC versionata leggibile dagli account computer destinatari.
2. Aprire Gestione Criteri di gruppo e creare o modificare la policy computer destinata alla OU pilota.
3. Aprire **Configurazione computer → Criteri → Impostazioni del software → Installazione software**.
4. Selezionare **Nuovo → Pacchetto**, indicare il percorso UNC dell'MSI e scegliere **Assegnato**.
5. Collegare la GPO soltanto alla OU o al gruppo di computer pilota previsto.
6. Mantenere `CREATE_TASK=0`: la pianificazione sarà gestita separatamente dalla GPO.
7. Applicare le policy e riavviare il client pilota quando richiesto dal normale flusso di installazione software dell'organizzazione.

Non selezionare il pacchetto mediante un percorso locale: tutti i client devono raggiungere la stessa sorgente UNC.

## 9. Scheduled Task tramite Group Policy Preferences

Creare un'attività lato computer in:

**Configurazione computer → Preferenze → Impostazioni Pannello di controllo → Operazioni pianificate**.

| Impostazione | Valore |
|---|---|
| Azione | Aggiorna |
| Nome attività | `Maintenance Toolkit - GPO Managed` |
| Account | `NT AUTHORITY\SYSTEM` |
| Opzione di sicurezza | Esegui indipendentemente dalla connessione dell'utente |
| Privilegi | Esegui con i privilegi più elevati |
| Programma | `C:\Program Files\Kraugh\Maintenance Toolkit\MaintenanceToolkit.exe` |
| Argomenti | `-RunAll -InventoryShare "\\SERVER\MT"` |
| Avvia in | `C:\Program Files\Kraugh\Maintenance Toolkit` |
| Trigger | Giornaliero, all'orario approvato dall'organizzazione |

Usare la normale identità `SYSTEM` supportata da Group Policy Preferences. Non eseguire MT come Domain Administrator. Orario e argomenti possono essere modificati in GPO senza reinstallare l'MSI.

## 10. Destinazione SMB dell'inventario

L'architettura generica è:

```text
Client MT -> \\DMT-SERVER\MT -> DMT
```

Quando MT viene eseguito come `SYSTEM`, l'accesso SMB remoto usa l'identità del computer di dominio, per esempio `CONTOSO\CLIENT01$`.

Configurare sia i permessi della share sia quelli del filesystem affinché gli account computer selezionati, oppure un gruppo controllato come `Domain Computers`, possano creare e aggiornare i file Inventory. Concedere soltanto i diritti necessari. Non usare un account amministrativo personale come identità dell'attività.

Provare la scrittura usando lo stesso account e lo stesso contesto di policy previsti in produzione.

## 11. Verifica sui client

Dopo l'applicazione delle policy e l'eventuale riavvio, verificare su un client pilota:

- installazione in Program Files;
- versione approvata in `config\version.json`;
- presenza di `Maintenance Toolkit - GPO Managed` con `SYSTEM` e privilegi più elevati;
- percorso dell'eseguibile e argomenti esatti;
- completamento dell'attività con il risultato previsto;
- creazione di una nuova sessione di log locale;
- se configurato, arrivo di un nuovo JSON in `\\SERVER\MT`;
- assenza dell'attività MSI-managed quando è stato usato `CREATE_TASK=0`.

Il risultato `0` di Utilità di pianificazione indica successo. L'exit code MT `20` indica esecuzione completata con warning e non deve essere interpretato come errore d'installazione. MT non esegue mai riavvii automatici.

Per i controlli operativi mirati consultare [Comandi diagnostici](DIAGNOSTIC-COMMANDS.md).
