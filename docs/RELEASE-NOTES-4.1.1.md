# Maintenance Toolkit 4.1.1

**Current distribution / Distribuzione corrente:** 4.1.0 has been withdrawn from public releases; take 4.1.1 directly. Original 4.1.0 assets and source tag are preserved. La 4.1.0 e ritirata: usare direttamente la 4.1.1, senza passaggi intermedi. No 4.1.1 package bytes have changed.

## Italiano

Corregge l’errore HTTP 403 dell’updater sull’hosting: le richieste inviano ora uno User-Agent identificativo di MT, senza dati macchina/utente. Verificato con il downloader reale su Windows PowerShell 5.1 contro i file API pubblicati, con verifica di firma/catalogo e download MSI/ZIP da GitHub.

**La 4.1.0 può richiedere il passaggio manuale alla 4.1.1**, perché il vecchio downloader può fallire prima di recuperare la patch. Usare i nuovi pacchetti ufficiali verificati, conservando configurazione, eccezioni, InventoryShare, log/report e task. GPO mantiene la proprietà della distribuzione; nessun riavvio automatico. [Istruzioni](https://github.com/Kraugh/maintenance-toolkit/blob/v4.1.1/docs/ita/AGGIORNAMENTO-MT.md).

## English

Fixes updater HTTP 403 errors on hosting: requests now send an MT product User-Agent without machine/user information. Verified with the actual Windows PowerShell 5.1 production downloader against deployed API files, signed metadata authentication and GitHub MSI/ZIP downloads.

**4.1.0 may need a manual upgrade to 4.1.1** because its old downloader can fail before retrieving this patch. Use verified new official packages, preserving settings, exceptions, InventoryShare, logs/reports and tasks. GPO retains deployment ownership; no automatic restart. [Instructions](https://github.com/Kraugh/maintenance-toolkit/blob/v4.1.1/docs/eng/UPGRADING-MT.md).

## Verification / Verifiche

118 regressions; Foundation zero errors/warnings. New MSI, signed ZIP payload catalog and signed update metadata; unchanged signed native launcher reused. Signature, publisher, timestamp, MSI identity, payload membership and hashes checked. Published 4.1.0 assets are unchanged. Download the matching MSI/ZIP SHA-256 sidecar and ZIP payload catalog.

New metadata sequence 5 has 30-day validity and requires an explicitly signed refresh before expiry. Website/API upload follows GitHub separately. Windows 10 was waived in the 4.1 phase; corporate SMB and live selective Winget installation remain outside these transport tests. All existing installation-consent, GPO and recovery safeguards remain in place.
