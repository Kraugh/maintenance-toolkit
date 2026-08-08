# Maintenance Toolkit 4.0

Maintenance Toolkit è uno strumento gratuito e open source per la manutenzione,
la diagnostica e la raccolta di informazioni sui sistemi Microsoft Windows.

**Pre-release corrente:** `4.0.0-rc.1`  
**Release stabile corrente:** `3.7.2`

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

- `3.7.2` è la versione stabile.
- `4.0.0-rc.1` è la Release Candidate della nuova serie 4.0.

Per avviare il Toolkit:

1. scaricare lo ZIP della release;
2. verificare, quando opportuno, il file SHA-256 pubblicato insieme allo ZIP;
3. se Windows segnala che lo ZIP proviene da Internet, verificare che provenga
   dalla release ufficiale e usare **Proprietà → Sblocca** prima di estrarlo;
4. estrarre completamente l'archivio;
5. eseguire `Avvia_Manutenzione.bat`;
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
Unblock-File .\Maintenance-Toolkit-4.0.0-rc.1.zip
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
non aggiornati.

Nella RC1 il Toolkit non inibisce ancora la sospensione di Windows. Durante
manutenzioni lunghe è quindi consigliabile impostare temporaneamente il sistema
in modo che **non entri in sospensione**. Lo spegnimento del display può invece
rimanere attivo.

## Log e report

I log operativi sono organizzati per computer e sessione sotto `logs/`.
I report di Network Diagnostics vengono mantenuti separatamente sotto
`reports/`.

Prima di condividere log o report con terzi, verificarne sempre il contenuto e
rimuovere eventuali informazioni che non si desidera rendere pubbliche.

## Stato della RC1

La RC1 è stata verificata su Windows 10 e Windows 11, su hardware fisico e in
Hyper-V, con interfacce Ethernet e Wi-Fi e in scenari senza VPN attiva.

La validazione con una VPN realmente connessa resta un test desiderabile prima
della promozione a 4.0.0 stabile.

## Documentazione

- [Manuale tecnico italiano](manuale-tecnico.md)
- [Guida inglese per tecnici](../eng/field-technician-guide.md)
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
