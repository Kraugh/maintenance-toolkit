# Maintenance Toolkit 4.0

Maintenance Toolkit è uno strumento gratuito e open source per la manutenzione,
la diagnostica e la raccolta di informazioni sui sistemi Microsoft Windows.

**Release stabile corrente:** `4.0.0`

La serie 4.0 integra il nuovo core bilingue, Network Diagnostics, regole
automatiche di analisi, diagnostica VPN avanzata e report tecnici di rete,
mantenendo i moduli di manutenzione già validati nella serie 3.7.x.

## Funzioni principali

- verifica della connettività;
- inventario hardware e software;
- aggiornamenti applicativi tramite Winget;
- Microsoft Update;
- aggiornamenti Microsoft Defender;
- creazione di punti di ripristino;
- DISM e SFC;
- verifica dello stato dei dischi;
- pulizie TEMP e componenti Windows opzionali;
- diagnostica di rete con topologia, route, gateway, DNS, DHCP, APIPA, MTU,
  metriche e velocità del link;
- analisi automatica mediante regole con severità;
- diagnostica VPN per indirizzi tunnel, DNS, route, split/full tunnel e
  riconoscimento delle tecnologie VPN più comuni;
- report tecnici TXT con JSON correlati di topologia e regole;
- integrazione opzionale con Ookla Speedtest CLI;
- log separati per computer e sessione;
- interfaccia bilingue italiano/inglese.

## Download e primo avvio

Scaricare il pacchetto dalla pagina **Releases** del repository ufficiale.

Per avviare il Toolkit:

1. scaricare lo ZIP della release;
2. verificare, quando opportuno, il file SHA-256 pubblicato insieme allo ZIP;
3. se Windows segnala che lo ZIP proviene da Internet, verificare che provenga
   dalla release ufficiale e usare **Proprietà → Sblocca** prima di estrarlo;
4. estrarre completamente l'archivio;
5. eseguire `MaintenanceToolkit.exe` (`Avvia_Manutenzione.bat` resta disponibile come fallback);
6. accettare l'elevazione amministrativa.

> Non eseguire direttamente gli script presenti in `app/modules`.

### Windows 11: Smart App Control e file scaricati da Internet

Su alcuni sistemi Windows 11 Smart App Control può bloccare il launcher
estratto da uno ZIP scaricato da Internet.

Non è necessario disattivare Smart App Control. Dopo avere verificato origine e
integrità del pacchetto ufficiale, sbloccare **lo ZIP prima dell'estrazione** e
riestrarre il contenuto.

Da PowerShell:

```powershell
Unblock-File .\Maintenance-Toolkit-4.0.0.zip
```

## Impostazioni prudenti

Le operazioni potenzialmente invasive restano disattivate per impostazione
predefinita, tra cui:

- creazione automatica del punto di ripristino;
- DISM RestoreHealth;
- SFC Scannow;
- installazione driver tramite Microsoft Update;
- pulizia TEMP;
- pulizia componenti Windows.

Il Toolkit non riavvia intenzionalmente il computer in modo automatico.

## Network Diagnostics

Il sottomenu di rete di MT4 comprende:

- `N1` — Diagnosi rapida;
- `N2` — Report tecnico;
- `N3` — Diagnosi rapida + SpeedTest;
- `N4` — Report tecnico + SpeedTest.

I report vengono salvati in `reports/`.

SpeedTest è opzionale. L'eseguibile Ookla può essere collocato in
`external\speedtest.exe` oppure reso disponibile nel `PATH`; non viene
scaricato né distribuito automaticamente da Maintenance Toolkit.

## Operazioni lunghe e sospensione

Microsoft Update, Winget, DISM e SFC possono richiedere molto tempo su sistemi
non aggiornati. Durante una sessione MT richiede a Windows di mantenere attivo
il sistema; il display può comunque spegnersi normalmente.

## Log e report

I log operativi sono organizzati per computer e sessione sotto `logs/`.
I report di Network Diagnostics vengono mantenuti separatamente sotto
`reports/`.

Prima di condividere log o report con terzi, verificarne sempre il contenuto e
rimuovere eventuali informazioni che non si desidera rendere pubbliche.

## Esecuzione automatizzata

La release 4.0.0 supporta `MaintenanceToolkit.exe -RunAll`, equivalente non
interattivo della voce `[A]`: esegue i moduli automatici abilitati nel file INI
e termina. Il manuale tecnico descrive anche l’uso con Utilità di pianificazione
e gli scenari Active Directory / GPO.

## Documentazione

- [Manuale tecnico italiano](manuale-tecnico.md)
- [Guida inglese per tecnici](../eng/field-technician-guide.md)
- [System Administrator Guide](../eng/System-Administrator-Guide.md)
- [Changelog](../CHANGELOG.md)
- [About](../ABOUT.txt)
- [Repository principale](../../README.md)

## Licenza

Maintenance Toolkit è distribuito con licenza MIT. Consultare
[`LICENSE`](../../LICENSE).

## Autore

**Luca Miselli**
<https://www.kraugh.it>

Sviluppato con l'indispensabile aiuto di una Rubber Duck molto paziente.
