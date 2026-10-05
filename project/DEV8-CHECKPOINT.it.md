# 4.0.4-dev.8 — sorgenti di sviluppo

Estrarre lo ZIP dopo Unblock-File e copiare l'albero maintenance-toolkit nel repository. Lo ZIP contiene i sorgenti del baseline aggiornati; non include EXE o MSI compilati e non effettua firma digitale. Un EXE già presente nel repository locale non viene aggiornato da questo pacchetto. Lo ZIP non contiene log, driver scaricati o dati aziendali.

Da KraughDev: C:\Projects\Open-Source\maintenance-toolkit. Conservare baseline e stash già creati. Non eseguire il vecchio Publish-MTNvdokWorkingTree.ps1: è specifico del checkpoint dev.7-NVDOK.

Validare Test-MTNvidia.ps1, Test-MTNvidiaAdvisory.ps1, Test-MTDev8Outcomes-R01.ps1 e Invoke-MT4FoundationAutotest.ps1 con Windows PowerShell 5.1. Poi test reale SYSTEM Dell e una sessione -Only Inventory,NVIDIA su una macchina con GPU supportata. Nessuna pubblicazione della release 4.0.4 finché questi controlli non sono completati. Gli output ZIP diagnostici vanno in C:\temp oppure sul Desktop dell'utente.
