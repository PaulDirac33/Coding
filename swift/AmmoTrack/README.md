# AmmoTrack — registro cartucce per macOS

App SwiftUI (macOS 14+, Liquid Glass su macOS 26) per tenere il conto delle cartucce: quante ne spari, quante ne
compri o ricarichi, di quale calibro e con quale arma. Solo framework di sistema (SwiftUI + Swift Charts).

Il codice è nello stesso stile dell'altra tua app (GlassSegmented, caselle con cifre animate, ecc.) ed è diviso in
tre strati pensati per portarlo su iOS: **Core** (solo Foundation, testabile), **UI** condivisa, **Platform**.

> **Stato:** il codice è stato scritto senza poterlo compilare (non c'era Xcode). La logica di import e i saldi sono
> stati verificati sui tuoi due CSV reali con una riproduzione in Python, e i test Swift (`Tests/`) rifanno la stessa
> verifica. Se Xcode segnala errori di compilazione, incollali nella chat e si correggono.

---

## 1. Installazione

1. Nella cartella del progetto Xcode (quella con `ContentView.swift`):
   - **sostituisci** `AmmoTrackApp.swift` con quello di questo pacchetto;
   - **elimina** `ContentView.swift` (non serve più);
   - **copia** le cartelle `Core/`, `Platform/`, `Store/`, `UI/`.
   I progetti Xcode recenti includono da soli i file messi nella cartella. Se non li vedi nel navigatore, trascinali dentro.
2. **Test** (facoltativo ma consigliato): copia `Tests/AmmoTrackTests.swift` nella cartella del target di test
   (`AmmoTrackTests`). Se il target non esiste: File ▸ New ▸ Target ▸ Unit Testing Bundle (Swift Testing). Poi ⌘U.
3. **Signing & Capabilities ▸ App Sandbox**: la via più semplice è **rimuoverlo**, come nell'altra app.
   Senza sandbox l'app usa direttamente `~/Documents/ARMI` (macOS ti chiederà una volta il permesso di accedere a Documenti).
   Se invece lo tieni attivo: File Access ▸ *User Selected File* = **Lettura/Scrittura**, e nel file `.entitlements`
   aggiungi `com.apple.security.files.bookmarks.app-scope = YES`; al primo avvio scegli la cartella ARMI.
4. Deployment target: macOS 14 o successivo (con 26 usa il vetro vero, prima ripiega sui materiali).
5. `.gitignore`: copialo **nella cartella del progetto** (non in quella globale), vedi sotto.
6. ⌘R.

## 2. Primo avvio: portare dentro i due fogli Numbers

1. In Numbers: File ▸ Esporta ▸ CSV, uno per il 9x21 e uno per il .22.
2. Nell'app: pagina **Dati** → icona ⤓ (oppure Impostazioni ⌘, ▸ Importa) → scegli il calibro e il file.
3. L'app mostra i movimenti che ricava e **controlla riga per riga** che rifacciano la colonna TOTALE del foglio.
   Con i tuoi dati deve dire: 9x21 → 25 righe, 26 movimenti, saldo finale 54 ricaricate / 0 comprate;
   .22 → 4 righe, 3 movimenti, saldo finale 370 comprate. Poi premi *Importa*.
4. Importare di nuovo lo stesso foglio sostituisce la precedente importazione (niente duplicati).

Dal foglio si usano solo la data e le colonne AGGIUNTE/SPARATE; RICARICATE, COMPRATE e TOTALE servono al controllo.
Il saldo di partenza della prima riga (nel 9x21: 4 ricaricate + 85 comprate) diventa il "saldo iniziale".

## 3. Usare l'app

**Inserimento** — scrivi il numero con la tastiera, poi:

| Tasto | Azione |
|---|---|
| cifre | scrivono il numero (solo interi) |
| ↓ | registra **sparate** |
| ↑ | registra **aggiunte** (comprate o ricaricate) |
| ← → | ricaricate / comprate |
| ⌫ | cancella l'ultima cifra |
| Esc | svuota la casella (o chiude il selettore dell'arma) |

- Le frecce hanno il colore della provenienza scelta (oro = ricaricate, rosso = comprate).
- Il **tasto dell'arma** apre il banner di vetro: il calibro è quello dell'arma. Senza armi compare "Senza arma" per calibro.
  L'ultima scelta viene ricordata.
- La riga **Oggi · 14 nov** è cliccabile: apre il calendario per registrare a posteriori (diventa oro).
- **Annulla** toglie l'ultimo movimento inserito in questa sessione.
- Il .22 non si ricarica: la scelta ricaricate/comprate sparisce.
- Avvisi (non bloccanti): saldo negativo per una provenienza, limite denunciato superato.

**Dati** — *Registro* (come il foglio, con i saldi calcolati; doppio clic = modifica, clic destro = elimina) e *Grafici*
(giacenza con linea del limite, spari e entrate per mese, colpi per arma, distribuzione per uscita, autonomia).
Filtri per calibro, periodo e arma; ⤒ esporta in CSV quello che vedi.

**Armi** — una scheda per arma con foto (clic o trascina un file), matricola, calibro, colpi sparati. Un'arma con movimenti
non si elimina: si archivia.

**Impostazioni (⌘,)** — cartella dei dati, limiti (9x21 600, .22 400, totale 1000), calibri, importazione.

## 4. Dove stanno i dati

Una cartella (di norma `~/Documents/ARMI`, in iCloud Drive):

```
ARMI/
  movimenti.csv   il registro
  armi.json       calibri, limiti, armi, matricole
  Immagini/       foto delle armi
  Backup/         copie di sicurezza datate
```

`movimenti.csv` (le colonne si leggono **per nome**: ordine libero, se ne possono aggiungere):

```
id,data,ora,tipo,provenienza,calibro,quantita,arma,arma_nome,nota
```

- `tipo`: `iniziale` | `aggiunta` | `sparo` | `rettifica` (quantità con segno)
- `provenienza`: `ricaricate` | `comprate`
- `ora` vuota = si conosce solo il giorno; `arma` = id dell'arma (`arma_nome` è solo per leggere il file in Numbers;
  se scrivi a mano il nome dell'arma lo riconosce lo stesso)
- **i saldi non si salvano**: si ricalcolano dai movimenti (correggere una riga vecchia aggiorna tutto)

### Regole di calcolo
- Stesso giorno: prima il saldo iniziale, poi le entrate, poi le uscite; i movimenti con ora vera si ordinano per ora.
- Movimenti registrati in app oggi: data e ora di adesso. Con giorno passato: solo la data.
- Un'**uscita** (per le statistiche) è un giorno con almeno uno sparo.
- Autonomia = giacenza ÷ ritmo medio di colpi al mese nel periodo scelto.

### Scrittura atomica e copie di sicurezza
- **Atomica**: il nuovo contenuto va in un file temporaneo che poi sostituisce l'originale in un colpo solo; se l'app o il Mac
  si bloccano a metà resta il file vecchio intero o quello nuovo intero, mai uno a metà.
- **Backup**: prima di ogni modifica, cancellazione o importazione il file attuale viene copiato in `Backup/` con data e ora
  (ultime 60 copie); per i semplici inserimenti una copia al giorno.
- Se un file non si riesce a leggere (es. modificato a mano con un errore) l'app **non lo sovrascrive** e te lo dice.
- Ogni scrittura rilegge prima il file da disco, quindi righe aggiunte altrove nel frattempo (iCloud, terminale) non si perdono.

## 5. Git

`.gitignore` va nella cartella del progetto (accanto a `AmmoTrack.xcodeproj`): vale solo lì e nelle sottocartelle, gli altri
progetti del repository non sono toccati. Ignora `*.csv`, `*.json`, `*.dat` ma **tiene** i `Contents.json` di Xcode
(Assets.xcassets), che altrimenti sparirebbero dal repository.
La cartella ARMI sta fuori dal repository; nei test ci sono solo numeri, niente matricole.
Se hai già committato per sbaglio dei CSV/JSON: `git rm --cached <file>`.

## 6. Mappa dei file

| Cartella / file | Contenuto |
|---|---|
| `AmmoTrackApp.swift` | punto di ingresso, finestra, scena Impostazioni |
| **Core/** (solo Foundation) | |
| `Models.swift` | movimento, calibro, arma, configurazione |
| `DateHelpers.swift` | calendario, formati, lettura date ("1 Mar 26", "18 December 2022", ISO…) |
| `CSV.swift` | lettura/scrittura CSV, numeri tolleranti |
| `MovementCSV.swift` | movimenti.csv ↔ movimenti, esportazione con i saldi |
| `Ledger.swift` | ordinamento e saldi (ricaricate / comprate / totale) |
| `Statistics.swift` | giacenza nel tempo, mesi, uscite, armi, istogramma, autonomia |
| `NumbersImport.swift` | import dal foglio Numbers con controllo sui TOTALE |
| `ArchiveFiles.swift` | file dell'archivio, scrittura atomica, backup |
| `ImageTools.swift` | foto delle armi (ImageIO) |
| **Platform/** | |
| `FolderAccess.swift` | dove stanno i dati (cartella scelta, segnalibro, ~/Documents/ARMI) |
| **Store/** | |
| `DataStore.swift` | legge/scrive i file, rilegge da solo ogni secondo, espone registro e configurazione |
| **UI/** | |
| `RootView.swift`, `FolderSetupView.swift` | finestra, selettore di pagina, scelta cartella |
| `Style/` | GlassSegmented (invariato), GlassStyle, Palette, BlinkingCaret, AppBackground, utilità |
| `Entry/` | pagina Inserimento: `EntryView`, `EntryView+Input`, `WeaponPicker`, `BalanceCard` |
| `Data/` | pagina Dati: `DataView`, `RegistryView`, `MovementEditor`, `ChartsView`, `ChartCards`, `CSVDocument` |
| `Weapons/` | pagina Armi: `WeaponsView`, `WeaponEditor` |
| `Settings/` | `SettingsView`, `ImportSheet` |
| **Tests/** | `AmmoTrackTests.swift` (import dei tuoi due fogli, saldi, CSV, statistiche, backup) |

## 7. Verso iOS

Il Core e quasi tutta la UI sono già condivisi; le parti solo Mac stanno in `#if os(macOS)` (sfocatura della finestra,
monitor dei tasti, scena Impostazioni). Da fare su iOS: tastierino a schermo al posto dei tasti, barra a schede al posto
del selettore in alto, scelta della cartella ARMI dal selettore file (stesso `FolderAccess`).
Con l'account Apple gratuito puoi installare sul tuo iPhone da Xcode (la firma scade dopo 7 giorni); TestFlight e App Store
richiedono l'Apple Developer Program a pagamento. La sincronizzazione passa dalla cartella in iCloud Drive: se due
dispositivi scrivono offline possono nascere copie in conflitto (ogni movimento ha un id, quindi si potranno fondere).
