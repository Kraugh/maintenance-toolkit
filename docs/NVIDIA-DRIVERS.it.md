# Controllo driver NVIDIA — 4.0.4

Modalità esclusivamente informativa, come la segnalazione BIOS: non scarica
pacchetti, non estrae file, non installa, non crea punti di ripristino e non
richiede né esegue riavvii. Gli switch sperimentali NvidiaInstall e
NvidiaUseCachedOnly sono stati rimossi dal runtime.

Eseguire `-Only NVIDIA -Language it-IT` per questo solo controllo. La configurazione
INI fornita include `NVIDIA=1` in RunAll. Nessuna GPU NVIDIA presente: SKIP.
Per le GPU NVIDIA presenti si registrano modello e versione del driver da PnP/CIM.
Per Windows 11 x64 il modulo interroga il catalogo professionale NVIDIA;
confronta modelli esatti, distingue desktop/notebook, richiede Windows 11,
x64, WHQL, non beta/preview e ramo Enterprise Production. Con più GPU il
risultato viene conservato separatamente per ciascun dispositivo.

La versione più alta nella risposta del ramo selezionato viene confrontata
numericamente con quella installata. Una versione più recente produce WARN,
versioni attuale/proposta e pagina ufficiale. Questo non certifica la compatibilità
con le applicazioni professionali/ISV. Catalogo irraggiungibile, modello non
univoco, OS o ramo non supportati: WARN/verifica non completata, mai un falso OK.
GeForce, AMD e Intel restano fuori da questo controllo online.

Artefatti: logs/<computer>/<sessione>/NVIDIA/nvidia-status.json (schema 3),
risposte XML del catalogo e JSON di ricerca. Nessun EXE viene scaricato.
I vecchi log FNV e i pacchetti già scaricati vengono lasciati intatti.

Validazione 4.0.4: test di selezione catalogo, corrispondenza desktop/mobile e scenari corrente, disponibile, sconosciuto, multiplo, offline e assente superati. Prove reali informative su Quadro P620, T1000 e RTX A1000; nessun download o installazione nel flusso attuale. Ulteriori modelli richiedono hardware rappresentativo. Pubblicazione 4.0.4 in attesa; endpoint pubblico ancora alla 4.0.3.

## Risultati per DMT

Con Inventario e NVIDIA nella stessa sessione, il JSON di inventario locale e quello pubblicato sulla share includono `maintenance.data.gpuDrivers`. NVIDIA da solo produce `NVIDIA/nvidia-status.json` nella sessione: non aggiorna inventari di sessioni precedenti.

Per ogni GPU: `name`, `windowsDriverVersion`, `installedVersion`, `candidate` (versione, ramo, prodotto, URL ufficiale, data di pubblicazione), `checkedAt`, `updateAvailable` e `status`. `updateAvailable=true` evidenzia un candidato più recente compatibile; `false` significa nessun candidato più recente nel ramo verificato; `null` significa verifica non completata. Nessun downgrade viene proposto. DMT dovrà mostrare separatamente aggiornamenti disponibili e verifiche incomplete, con data e ramo della verifica.

Il controllo è limitato al catalogo professionale NVIDIA Enterprise Production per Windows 11 x64 e richiede corrispondenza esatta del modello e del formato desktop/mobile. Modelli o risposte ambigui rimangono non verificati. Non si promette il massimo numero di versione fra tutti i rami NVIDIA. GeForce, AMD e Intel rimangono lavoro futuro. La certificazione di applicazioni CAD è una nota opzionale per le utenze interessate e non blocca la segnalazione.

L'audit ufficio tecnico ha fornito casi anonimizzati: Quadro P2200 (538.95/582.67), RTX A1000 e RTX 4500 Ada Generation (553.62), RTX 500 Ada Generation Laptop GPU (553.62/596.71), T1000 (596.71). Sono dati installati osservati, non versioni online correnti. Non si includono nomi macchina, utenti o dominio.
