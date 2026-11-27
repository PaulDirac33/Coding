# AmmoTrack per iPhone e iPad — versione 3 (solo iOS / iPadOS 26)

Solo iOS: nessun codice del Mac. Parte dal tuo codice Mac **aggiornato** (stessi modelli, stessi file `movimenti.csv` /
`armi.json`, stessa logica; pagina Dati con filtro armi e menù azioni, registro, editor, bordo sfumato della pagina Armi).

## Cosa è cambiato rispetto alla versione 2

| Tu | Come è fatto |
|---|---|
| **La tastiera non compare da sola** | Si apre solo toccando la casella dell'importo (e si chiude toccando fuori o cambiando pagina). Dopo una registrazione resta com'era. |
| **Senza casella vuota, con lo 0 e il cancella accanto** | La tastiera dell'app (`DigitsInput.swift`) è un vero *input view*: compare come una tastiera di sistema e copre la barra delle pagine. Righe `1 2 3`, `4 5 6`, `7 8 9`, poi `0` largo e il cancella subito a destra. Per tornare a quella di sistema: `entryKeyboardStyle = .system` in `AppearanceSettings.swift`. |
| **Mai frecce su/giù né «Fine»** | La barra sopra la tastiera non esiste più (né in codice né per il sistema). |
| **Ricaricate / comprate** | Selettore di sistema, senza colori: la lente di vetro scorre col dito come negli altri. |
| **Banner armi** | Nuovo: si sceglie con un tocco e **si scorre col dito** (prima il gesto di trascinamento sulle righe bloccava lo scorrimento). Apertura e chiusura con una dissolvenza al posto della trasformazione del vetro, e senza altro vetro dentro. Il tasto «Aggiunte» si fonde/divide solo a banner chiuso. |
| **Pagina Dati** | Tutti i controlli in basso, sopra la barra delle pagine: Registro/Grafici + calibri, periodo, e sull'ultima riga il filtro armi con a destra il contatore `#N`, che apre il menù (nuovo movimento, importa, esporta). Sono selettori e menù di sistema. Su iPad i tre selettori stanno su una riga. |
| **Tasto «+» delle armi (e tutti i tasti principali)** | Verde militare (`Palette.militaryGreen`, più chiaro della mimetica) con la scritta chiara. È anche la tinta generale dell'app (`militaryGreenLight`: barra delle pagine, interruttori). |

## Cartelle

```
App/       AmmoTrackApp, RootView (barra delle pagine in basso)
Core/      logica pura: modelli, saldi, CSV, import, statistiche, annulla/ripeti
Storage/   DataStore, ArchiveFiles, FolderAccess
Design/    GlassStyle, sfondo + mimetica, icone Beretta/cartucce, IconCache, Layout, Palette
Features/  Entry (anche DigitsInput, WeaponPicker) · Data · Weapons · Settings
```

## Da regolare

- `AppearanceSettings.swift`: `appBackgroundStyle` (mimetica / nero), `entryKeyboardStyle` (la tua / di sistema), `weaponPickerMorphs` (apertura del banner con trasformazione del vetro, di default spenta).
- `Palette.swift`: `militaryGreen` e `militaryGreenLight`. `CamoBackground.swift`: colori e dimensioni della mimetica.

## In Xcode

Stesso progetto di prima: elimina i gruppi vecchi (`App`, `Core`, `Design`, `Features`, `Storage`: *Move to Trash*), trascina le
cartelle di questo zip (*Copy items if needed*, *Create groups*, target spuntato). Impostazioni come prima: solo iPhone e iPad,
iOS 26.0, iPhone in verticale. Per giudicare la fluidità usa **Release** (Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Build
Configuration ▸ Release): in Debug SwiftUI è molto più lento.

## Note

- Non l'ho potuto compilare (nel mio ambiente non c'è Xcode): controllati parentesi, nomi e file. Se Xcode segnala errori, copia il primo (file e riga).
- La tastiera dell'app è l'unica parte che passa da UIKit (un campo di testo invisibile con un *input view* personalizzato).
