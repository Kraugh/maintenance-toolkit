# Controllo driver NVIDIA — 4.0.4-dev.7-NVDOK

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

Artefatti: logs/<computer>/<sessione>/NVIDIA/nvidia-status.json (schema 2),
risposte XML del catalogo e JSON di ricerca. Nessun EXE viene scaricato.
I vecchi log FNV e i pacchetti già scaricati vengono lasciati intatti.

Validazione: ricerca FNV03 della P620 riuscita; test di installazione FNV04
confermato dopo riavvio, 528.89 -> 582.78. NVDOK estende la ricerca oltre la
P620, ma ciascun modello aggiuntivo richiede prove reali. Eseguire il test
app/tools/Test-MTNvidia.ps1 e una scansione read-only su KRAUGHHQ prima del
checkpoint GitHub. La 4.0.4 non è ancora una release pubblica: stabile 4.0.3.
