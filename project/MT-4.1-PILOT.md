# MT 4.1 — pilota VM / VM pilot

## Stato e autorizzazione — 15 ottobre 2026

L’utente ha confermato un checkpoint Hyper-V della VM e autorizzato le prove reali. Il computer fisico viene spostato di sede: attendere conferma della VM nuovamente operativa e connessa prima di installazioni, firma o controlli online. Nessun riavvio automatico. Nessun test esegue -RunAll o moduli di manutenzione; eventuali prove funzionali di manutenzione richiedono un ambito separato.

The user confirmed a Hyper-V checkpoint and authorized real VM pilot testing. Wait until the VM is operational and connected again before installation, signing or online checks. No automatic restart or maintenance module execution. The steps below are pending, not successful test evidence.

## Sequenza verificabile / Verifiable sequence

1. Registrare baseline di prodotti MT installati, file/configurazioni, opt-in protetto, hash delle eccezioni e XML dei task MT pertinenti. Non includere identita aziendali nei resoconti versionati. Non modificare task GPO; se la macchina o l’installazione e gestita, fermare il ramo standalone.
2. Preparare un nuovo candidato locale con i sorgenti e documenti correnti, in una nuova cartella privata. R02 resta immutato. Concordare/registrare la mappatura della versione privata e non modificare il manifest pubblico. Verificare hash, firma, timestamp, firmatario e revoca online; la nuova firma puo richiedere conferma SimplySign dell’utente.
3. MSI: installare la baseline 4.0.6 con CREATE_TASK=0 e REBOOT=ReallySuppress; eseguire upgrade al candidato privato. Acquisire log MSI, codice nativo, versione, hash/configurazioni prima/dopo e controllo assenza di riavvio. Separare questo test Windows Installer dall’autoaggiornamento: 4.0.6 non contiene l’updater applicativo 4.1. Non dichiarare provato il feed stabile dal solo upgrade manuale.
4. ZIP: usare una copia protetta dedicata; verificare staging, sostituzione reale, conservazione di settings/INI/log/report, eccezioni e opt-in. Applicare solo payload/cataloghi autenticati. Per la transazione updater serve metadata di prova firmato e coerente con la versione: nessuna sostituzione silenziosa del feed stabile o disattivazione del controllo di fiducia.
5. Pianificazione: creare il task standalone con modalita di sola rilevazione; ispezionare trigger, principal SYSTEM/highest, ultimo/prossimo avvio ed esito. Per verificare il contesto e il percorso UNC usare una sonda innocua e un task temporaneo distinto, con nomi/percorsi registrati. Non avviare manutenzione. Verificare aggiornamento/rimozione e assenza di task concorrenti residui.
6. Errori: checksum/firma invalidi, download interrotto, sostituzione fallita, applicazione MSI incerta e ripresa consumata una sola volta. Distinguere test simulati gia eseguiti da interruzioni reali ancora da eseguire; ripristinare il checkpoint tra scenari distruttivi concordati.
7. Verificare tutti i file/task temporanei prima della pulizia, mantenere log/evidenze necessari, aggiornare risultati IT/EN e criteri #27/#28. Il confronto del sito richiede ancora i sorgenti correnti dall’hosting. Nessun push/tag/release senza successiva autorizzazione.

## Evidenze gia disponibili / Existing evidence

[Validazione locale](MT-4.1-LOCAL-VALIDATION.md): 112 controlli isolati passati e 67 script senza errori di parsing. [Revisione issue](ISSUE-REVIEW-20261014.md). [Guida italiana](../docs/ita/MT-4.1-PROVE-LOCALI.md) e [English guide](../docs/eng/MT-4.1-LOCAL-TESTING.md).

## Stato aggiornato

VM nuovamente online, utente conferma SimplySign attivo. Il pilota MSI/SYSTEM e stato eseguito: [risultati e limiti](MT-4.1-VM-PILOT-20261015.md). La sequenza precedente resta il piano; non tutte le sue fasi sono completate.

## Esito della sequenza locale

MSI/ZIP, errori reali e rollback controllato, helper/ripresa unica, SYSTEM/UNC locale e interruzione HTTPS sono verificati. Il solo scenario mutex/1618 resta inconclusivo e non viene contato come test superato. Candidato normale R04/4.0.9006, fixture fallimento 4.0.9007 separata. Restano confronto hosting, finalizzazione/feed e copertura ambienti: [evidenze](MT-4.1-VM-PILOT-20261015.md). La VM conserva sequence=3 del pilota: prima della prima pubblicazione scegliere una sequenza coerente e crescente (superiore a 3 per questo pilota), senza azzerare silenziosamente lo stato antireplay.

## Windows 10 test waiver — user approved

15 October 2026: the user explicitly waived the Windows 10 test for this 4.1 phase. It is no longer a blocking test in this phase, but Windows 10 must not be described as validated by this pilot. Actual environment: Windows 11 Pro build 26200 / Windows PowerShell 5.1. Other release gates remain in force. See [release preparation](MT-4.1-RELEASE-PREPARATION.md).
