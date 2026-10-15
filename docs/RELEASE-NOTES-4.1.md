# Maintenance Toolkit 4.1.0

## Italiano

- **V — Aggiorna MT:** aggiornamento MSI/ZIP con conferma per installazioni esplicitamente standalone; metadati autenticati, catalogo firmato dei file ZIP, verifica produttore, integrità e recupero transazionale.
- **G:** gestione e consenso protetto all’automatismo, disabilitato per default. GPO e gestione sconosciuta: sola rilevazione. Nessuna interferenza con task GPO; nessun riavvio automatico.
- **P:** crea, ispeziona, modifica o rimuove un’attività SYSTEM. Manutenzione completa consigliata, analisi o rilevazione aggiornamenti; trigger e condizioni configurabili, destinazione JSON locale/UNC opzionale.
- **H — Languages:** italiano, inglese, francese, spagnolo, tedesco, cinese semplificato e giapponese. Le cinque nuove traduzioni sono parziali, con fallback inglese. Documentazione IT/EN.

**Dalla 4.0.6 il primo upgrade è manuale:** [istruzioni](https://github.com/Kraugh/maintenance-toolkit/blob/v4.1.0/docs/ita/AGGIORNAMENTO-MT.md). Conservare configurazione, eccezioni, InventoryShare e task. Per GPO installazione affidata all’organizzazione, CREATE_TASK=0.

## English

- **V — Update MT:** confirmed MSI/ZIP updates for explicitly standalone installations, authenticated metadata, signed ZIP file catalog, publisher/integrity verification and transactional recovery.
- **G:** protected management and automatic-update opt-in, default off. GPO/unknown management detect only. GPO tasks remain untouched; no automatic restart.
- **P:** create, inspect, modify or remove a SYSTEM schedule. Full maintenance recommended, analysis or update detection alternatives; configurable triggers/conditions and optional local/UNC JSON destination.
- **H — Languages:** Italian, English, French, Spanish, German, Simplified Chinese and Japanese. The five additional translations are partial with English fallback. Documentation is IT/EN.

**The first upgrade from 4.0.6 is manual:** [instructions](https://github.com/Kraugh/maintenance-toolkit/blob/v4.1.0/docs/eng/UPGRADING-MT.md). Preserve configuration, exceptions, InventoryShare and tasks. GPO owns enterprise installation, CREATE_TASK=0.

## Verification / Verifiche

117 regressions and Foundation passed. Final MSI/ZIP integrity, catalog/script membership, certificate/timestamp and MSI identity verified; ZIP SelfTest has zero errors and the expected non-elevation warning. Real application/recovery/SYSTEM tests used private candidates on Windows 11/PowerShell 5.1. Windows 10 testing was explicitly waived; loopback UNC does not certify corporate SMB access. Live selective Winget installation remains unverified; OEM/DCU known limitations remain documented. NVIDIA advisory only; BIOS not automatic.

Download MSI or ZIP with its distinct SHA-256 sidecar. For ZIP also download **MaintenanceToolkit-4_1_0-payload.cat**; verify its Authenticode signature/publisher and Test-FileCatalog membership before running/unblocking extracted scripts. Expected signer: Open Source Developer Luca Miselli, certificate SHA-1 B5228D5E9A1CB84C10838146C10CA6C490C1A571.

Website/API deployment follows this GitHub release separately. version.json detects releases; update-v1.json and its signed update-v1.cat authenticate installation metadata. Sequence 4 expires on 14 November 2026 and needs an explicitly signed refresh before expiry. Website rendering was not verified because the browser blocked local-file preview; static links and final download/hash references were checked.
