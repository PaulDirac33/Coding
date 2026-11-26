//
//  EntryView.swift
//
//  Pagina "Inserimento": una sola casella al centro (cifre grandi, cursore lampeggiante, data cliccabile),
//  freccia giù = aggiunte, freccia su = sparate, selettore ricaricate/comprate, tasto dell'arma
//  (il calibro è quello dell'arma), ultimo evento con "Annulla" e i saldi rispetto ai limiti.
//
//  Cifre:  toccando la casella compare la tastiera (DigitsInput.swift); si chiude toccando fuori. Non compare mai da sola.
//  ↓ registra «aggiunte», ↑ registra «sparate» (i due tasti tondi).
//  In alto i saldi e l'ultimo movimento (restano visibili anche con la tastiera aperta), sotto i comandi.
//  Il codice dell'inserimento è in EntryView+Input.swift.
import SwiftUI

// MARK: - Tipi di supporto
/// Larghezza del selettore ricaricate/comprate (2 voci da 124 pt + 2 margini da 3 pt).
/// La casella di inserimento e il banner armi aperto hanno la stessa larghezza.
enum EntryLayout {
    static let controlWidth: CGFloat = 254
    /// Larghezza della colonna dei comandi: lascia ai lati del selettore lo spazio per Annulla e Ripeti.
    static let columnWidth: CGFloat = 340
}

/// Che cosa si sta per registrare: il calibro (che è quello dell'arma) e l'arma, se indicata.
struct EntryTarget: Equatable {
    var caliberID: String
    var weaponID: String?
}
/// Come appaiono il selettore ricaricate/comprate e i tasti. Segue la scelta, ma sincronizzato con la chiusura del banner armi.
struct ProvenanceLook: Equatable {
    var selector: Bool      // true = selettore visibile, false = scritta «non si ricarica»
    var bought: Bool        // colore dei tasti: false = oro (ricaricate), true = rosso (comprate)
    var name: String        // calibro nominato nella scritta
}

enum EntryStatus {
    case none
    case hint
    case warning
    case error
}

/// Numero dell'ultima sincronizzazione richiesta: chi arriva dopo annulla quelle ancora in attesa.
@MainActor
final class SyncToken {
    var value = 0
}
/// Tremolio orizzontale, come quando si sbaglia la password.
/// `shakes` va aumentato di 1 per ogni scossa: parte e finisce a riposo.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 9          // ampiezza in punti
    var oscillations: CGFloat = 3    // avanti e indietro per scossa
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: travel * sin(shakes * .pi * 2 * oscillations), y: 0))
    }
}

// MARK: - Vista

struct EntryView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.horizontalSizeClass) var sizeClass

    /// true quando questa è la pagina visibile: solo allora la casella riceve i tasti.
    let isActive: Bool
    // L'ultima scelta resta in memoria: dopo un'uscita basta scrivere "50" e premere ↓.
    @AppStorage("entry.caliber") var storedCaliber = ""
    @AppStorage("entry.weapon") var selectedWeapon = ""
    @AppStorage("entry.provenance") var storedProvenance = "ricaricate"

    // inserimento
    @State var inputText = ""
    @State var day: Date? = nil              // nil = oggi
    @State var showCalendar = false
    @State var pickerOpen = false
    @State var statusText = ""
    @State var statusKind: EntryStatus = .none
    @State var flash = false
    @State var flashError = false            // lampo rosso: inserimento rifiutato
    @State var shakes: CGFloat = 0           // contatore del tremolio
    @State var syncToken = SyncToken()
    @State var inputFocused = false          // la tastiera è su (campo di testo in DigitsInput.swift)
    @Namespace var buttonsNS      // per il morph del vetro fra i due tasti
    @State var addShown = true               // «Aggiunte» visibile: segue showsAddButton, ma solo a banner chiuso
    @State var look = ProvenanceLook(selector: true, bought: false, name: "")   // aspetto mostrato di selettore e tasti
    @State var pageHeight: CGFloat = 700     // altezza della pagina (misurata)
    @State var slotTop: CGFloat = 300        // distanza del tasto armi dall'alto della pagina (misurata)

    let maxLength = 6        // cifre massime nella casella
    /// Secondi fra l'inizio della chiusura del banner e il fondersi/dividersi dei tasti.
    /// 0 = partono insieme; alzalo se vuoi che il banner sia già quasi chiuso.
    let addButtonDelay: Double = 0.45
    /// Animazione del colore dei tasti e della sfumatura del selettore ricaricate/comprate.
    /// Durata della sfumatura del colore dei tasti e del selettore ricaricate/comprate.
    /// Serve anche a far partire la fusione dei tasti solo a sfumatura finita.
    let lookDuration: Double = 0.25
    var lookAnimation: Animation { .easeInOut(duration: lookDuration) }
    /// Pausa fra la fine della sfumatura del colore e l'inizio della fusione/divisione del vetro.
    let glassPause: Double = 0.06

    // MARK: Scelta corrente

    var target: EntryTarget {
        let cfg = store.config
        if let w = cfg.weapons.first(where: { $0.id == selectedWeapon && !$0.isArchived }) {
            return EntryTarget(caliberID: w.caliberID, weaponID: w.id)
        }
        guard let cal = cfg.calibers.first(where: { $0.id == storedCaliber }) ?? cfg.calibers.first else {
            return EntryTarget(caliberID: "", weaponID: nil)
        }
        return EntryTarget(caliberID: cal.id, weaponID: nil)   // niente più "propongo la prima arma"
    }

    var targetBinding: Binding<EntryTarget> {
        Binding(get: { target }, set: { select($0) })
    }

    func select(_ t: EntryTarget) {
        storedCaliber = t.caliberID
        selectedWeapon = t.weaponID ?? ""
    }

    var caliber: Caliber? { store.config.caliber(target.caliberID) }
    var caliberName: String { caliber?.name ?? "—" }
    var currentWeapon: Weapon? { store.config.weapon(target.weaponID) }
    var allowsReload: Bool { caliber?.allowsReload ?? true }

    /// Il .22 non si ricarica: è sempre "comprate".
    /// La scelta fatta nel selettore, anche se il calibro attuale non si ricarica.
    var storedChoice: Provenance {
        Provenance(rawValue: storedProvenance) ?? .reloaded
    }

    /// Il .22 non si ricarica: è sempre "comprate".
    var provenance: Provenance {
        allowsReload ? storedChoice : .bought
    }

    /// Il selettore mostra la scelta memorizzata e non quella effettiva: scegliendo il .22 la bolla non
    /// scivola su «Comprate» mentre il banner si chiude, il selettore sfuma e basta.
    var provenanceBinding: Binding<Provenance> {
        Binding(get: { storedChoice }, set: { setProvenance($0) })
    }

    /// Come dovrebbero apparire selettore e tasti secondo la scelta attuale.
    var lookWanted: ProvenanceLook {
        ProvenanceLook(selector: allowsReload, bought: provenance == .bought, name: caliberName)
    }

    var quantity: Int? {
        guard let q = Int(inputText), q > 0 else { return nil }
        return q
    }

    var canCommit: Bool { quantity != nil && !target.caliberID.isEmpty }
    /// «Aggiunte» esiste solo senza arma: con un'arma scelta viene assorbito dal tasto «Sparate».
    var showsAddButton: Bool { target.weaponID == nil }
    /// Altezza massima del banner armi aperto: dal tasto fino al fondo della pagina,
    /// con lo stesso margine (14 pt) della scheda dei saldi.
    var pickerRoom: CGFloat { max(160, pageHeight - slotTop - 14) }

    // MARK: Corpo

    /// iPad: saldi a sinistra e comandi a destra. iPhone: tutto in una colonna.
    var twoColumns: Bool { sizeClass == .regular }

    /// In alto: saldi e ultimo movimento. Restano visibili anche con la tastiera aperta.
    var dashboard: some View {
        VStack(spacing: 10) {
            BalanceCard()
            statusRow
        }
    }

    /// Provenienza, tasti, casella, tasto dell'arma. Il banner armi è l'ultimo e si apre verso il basso:
    /// non copre nessun controllo. zIndex alto perché il banner aperto sporge sopra lo spazio vuoto.
    var controls: some View {
        VStack(spacing: 14) {
            provenanceRow
            actionButtons
            amountPill
            weaponSlot
        }
        .zIndex(10)
    }

    var body: some View {
        ZStack {
            // Toccando un punto qualunque della pagina si chiudono il banner armi e la tastiera.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    closePicker()
                    inputFocused = false
                }

            Group {
                if twoColumns {
                    HStack(alignment: .top, spacing: 40) {
                        dashboard
                            .frame(width: 390)
                        controls
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 24)
                } else {
                    VStack(spacing: 14) {
                        dashboard
                        controls
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 16)
        }
        .coordinateSpace(.named("entryPage"))
        .ignoresSafeArea(.keyboard, edges: .bottom)        // la tastiera copre il fondo ma non sposta niente
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pageHeight = $0 }
        .onAppear {
            addShown = showsAddButton
            look = lookWanted
        }
        .onChange(of: isActive) { _, active in
            if !active {                                    // cambio pagina: la tastiera si chiude
                inputFocused = false
                pickerOpen = false
                showCalendar = false
            }
        }
        .onChange(of: inputText) { _, new in
            sanitizeInput(new)
            // Avvisi ed errori spariscono quando riprendi a scrivere;
            // l'ultimo evento (con l'orario) resta visibile.
            if statusKind != .none && !new.isEmpty {
                statusText = ""
                statusKind = .none
            }
        }
        .onChange(of: showsAddButton) { _, _ in
            if !pickerOpen { syncControls() }                       // cambio a banner chiuso (es. arma archiviata)
        }
        .onChange(of: pickerOpen) { _, open in
            if open {
                inputFocused = false                        // il banner ha bisogno di tutto lo schermo
            } else {
                syncControls(after: addButtonDelay)        // il banner si è chiuso
            }
        }
        .onChange(of: showCalendar) { _, open in
            if open { inputFocused = false }                // il calendario si sceglie senza tastiera davanti
        }
        .onChange(of: storedProvenance) { _, _ in
            syncLook()                                              // selettore mosso: il colore segue subito, anche a banner aperto
        }
        .onChange(of: lookWanted) { _, _ in
            if !pickerOpen { syncControls() }                       // cambio a banner chiuso
        }
    }

    // MARK: Arma

    /// Spazio fisso per il tasto dell'arma: quando si apre il pannello, questo sporge sopra il resto.
    var weaponSlot: some View {
        Color.clear
            .frame(width: 320, height: 52)
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("entryPage")).minY } action: { slotTop = $0 }
            .overlay(alignment: .top) {
                WeaponPicker(target: targetBinding, isOpen: $pickerOpen, maxPanelHeight: pickerRoom)
            }
            .zIndex(10)
    }

    // MARK: Tasti (sotto il selettore ricaricate/comprate)

    /// I due tasti stanno nello stesso contenitore di vetro. Con un'arma scelta «Aggiunte» sparisce
    /// e il suo vetro viene assorbito da «Sparate». Spacing del container = spacing dell'HStack:
    /// a riposo non si fondono, si fondono solo quando uno dei due compare o scompare.
    /// Distanza fra i due tasti (56 pt ciascuno) perché ognuno stia al centro della sua voce del selettore:
    /// ogni voce è larga (controlWidth − 2 margini da 3 pt) / 2 = 124 pt, quindi 124 pt da centro a centro.
    var buttonGap: CGFloat { (EntryLayout.controlWidth - 6) / 2 - 56 }

    var actionButtons: some View {
        GlassEffectContainer(spacing: buttonGap) {
            HStack(spacing: buttonGap) {
                if addShown {
                    directionButton(.added)
                }
                directionButton(.shot)
            }
        }
    }
    /// Porta «Aggiunte», colore dei tasti e selettore alla scelta corrente, UNO ALLA VOLTA:
    /// prima colore e selettore, poi (a sfumatura finita) il vetro che si fonde o si divide.
    /// Colore e vetro in movimento insieme fanno sfarfallare i tasti e possono far saltare la goccia.
    /// Ogni chiamata annulla quelle ancora in attesa; cosa fare si decide al momento di partire.
    func syncControls(after delay: Double = 0) {
        syncToken.value += 1
        let ticket = syncToken.value
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard syncToken.value == ticket, !pickerOpen else { return }

            // 1. colore dei tasti e selettore
            let tintChanges = look.bought != lookWanted.bought
            let lookChanges = look != lookWanted
            syncLook()

            // 2. vetro: solo quando il passo 1 ha finito
            guard addShown != showsAddButton else { return }
            let gap: Double = tintChanges ? lookDuration + glassPause : (lookChanges ? glassPause : 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + gap) {
                guard syncToken.value == ticket, !pickerOpen else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    addShown = showsAddButton
                }
            }
        }
    }

    /// Porta subito selettore e colore dei tasti alla scelta corrente (non tocca «Aggiunte»).
    func syncLook() {
        guard look != lookWanted else { return }
        withAnimation(lookAnimation) { look = lookWanted }
    }

    func directionButton(_ kind: MovementKind) -> some View {
        let symbol = kind == .shot ? "arrow.up" : "arrow.down"
        let title = kind == .shot ? "Sparate" : "Aggiunte"
        return VStack(spacing: 8) {
            Button {
                commit(kind)
            } label: {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 56, height: 56)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .provenanceGlassCircle(look.bought ? 1 : 0)
            .glassMorphID(kind == .shot ? "shotButton" : "addButton", in: buttonsNS)
            .disabled(!canCommit)
            .opacity(canCommit ? 1 : 0.45)

            Text(title)
                .font(.caption)
                .foregroundStyle(Palette.muted)
                .fixedSize()
        }
        .frame(width: 56)
    }

    var amountFont: Font {
        Font.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit()
    }

    /// Riquadro di inserimento in stile "importo": cifre grandi che compaiono una a una
    /// con una piccola animazione, cursore lampeggiante, lampo verde quando il valore è stato scritto nel file.
    var amountPill: some View {
        VStack(spacing: 0) {
            dateButton
            amountDigits
                .frame(height: 50)
        }
        .frame(width: EntryLayout.controlWidth, height: 92)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .liquidGlass(cornerRadius: 26)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.green, lineWidth: 1.5)
                .opacity(flash ? 1 : 0)          // solo il lampo verde dopo l'inserimento
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Palette.danger, lineWidth: 1.5)
                .opacity(flashError ? 1 : 0)
        )
        .animation(.easeOut(duration: 0.25), value: inputFocused)
        .animation(.easeOut(duration: 0.25), value: flash)
        .modifier(ShakeEffect(shakes: shakes))
        .background { amountField }
        .onTapGesture {
            closePicker()
            inputFocused = true
        }
    }

    var amountDigits: some View {
        HStack(spacing: 1) {
            ForEach(Array(inputText.enumerated()), id: \.offset) { _, ch in
                Text(String(ch))
                    .font(amountFont)
                    .foregroundStyle(flashError ? Palette.danger : Color.white)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3)
                            .combined(with: .opacity)
                            .combined(with: .offset(y: 14)),
                        removal: .scale(scale: 0.3).combined(with: .opacity)))
            }
            if inputFocused {
                BlinkingCaret(height: 38)
            }
            if inputText.isEmpty {
                Text("0")
                    .font(amountFont)
                    .foregroundStyle(Color.white.opacity(0.25))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: inputText)   // le cifre entrano/escono a molla
    }

    /// Il campo di testo vero, invisibile: porta la tastiera (vedi DigitsInput.swift). Compare solo toccando la casella.
    /// Le cifre le disegna la casella; qui dentro c'è solo il testo digitato.
    var amountField: some View {
        DigitsInputField(text: $inputText, isFocused: $inputFocused)
            .frame(width: 1, height: 1)
            .opacity(0.02)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: Data

    var dateTitle: String {
        if let d = day {
            return d.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
        }
        return "Oggi · \(Date().formatted(.dateTime.day().month(.abbreviated)))"
    }

    /// La riga della data è un pulsante: apre un piccolo calendario. Se scegli un giorno passato
    /// la scritta diventa oro, così non lo dimentichi (i movimenti con giorno passato non hanno l'ora).
    var dateButton: some View {
        Button {
            showCalendar = true
        } label: {
            Text(dateTitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(day == nil ? Palette.muted : Palette.reloaded)
                .padding(.horizontal, 12)
                .padding(.top, 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showCalendar) {
            calendarPopover
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.visible)
        }
    }

    var dayBinding: Binding<Date> {
        Binding(get: { day ?? Date() },
                set: { new in day = Cal.cal.isDateInToday(new) ? nil : new })
    }

    /// Contenuto del foglio del calendario (il nome è rimasto "popover" per non toccare altro).
    var calendarPopover: some View {
        VStack(spacing: 6) {
            DatePicker("Data", selection: dayBinding, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .dynamicTypeSize(...DynamicTypeSize.large)       // il testo del calendario non supera la misura standard

            HStack(spacing: 12) {
                Button {
                    day = nil
                    showCalendar = false
                } label: {
                    Text("Oggi").fontWeight(.semibold).frame(width: 64)               // larghezza del testo: la pillola si stringe attorno
                }
                .glassButton()
                .buttonBorderShape(.capsule)

                Button {
                    showCalendar = false
                } label: {
                    Text("Fine").fontWeight(.semibold).frame(width: 64)
                }
                .keyboardShortcut(.defaultAction)
                .glassProminentButton()
                .buttonBorderShape(.capsule)
            }
            .controlSize(.small)
            .focusEffectDisabled()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)                                       // spazio per la barretta di trascinamento
        .padding(.bottom, 6)
        .frame(maxWidth: 420)                                    // iPad: il foglio è più largo, il calendario no
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Provenienza

    /// Ricaricate / comprate. Per il .22 non c'è scelta: compare solo la nota.
    var provenanceRow: some View {
        ZStack {
            if look.selector {
                Picker("Provenienza", selection: provenanceBinding) {
                    ForEach(Provenance.allCases) { p in
                        Text(p.label).tag(p)
                    }
                }
                .pickerStyle(.segmented)                  // quello di sistema: Liquid Glass vero, la lente scorre
                .frame(width: EntryLayout.controlWidth)
                .transition(.opacity)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: Provenance.bought.symbol)
                        .foregroundStyle(Provenance.bought.color)
                    Text("\(look.name) non si ricarica: solo comprate")
                        .foregroundStyle(Palette.muted)
                }
                .font(.caption)
                .id(look.name)              // fra due calibri non ricaricabili il nome sfuma
                .transition(.opacity)
            }
        }
        .frame(width: EntryLayout.columnWidth, height: 40)
        .overlay(alignment: .leading) { undoButton }
        .overlay(alignment: .trailing) { redoButton }
    }

    /// Annulla l'ultimo movimento (sul Mac è ⌘Z).
    var undoButton: some View {
        Button {
            _ = store.undo()
        } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 38, height: 38)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassCircle(interactive: true)
        .disabled(store.undoName == nil)
        .opacity(store.undoName == nil ? 0.35 : 1)
        .accessibilityLabel(store.undoName.map { "Annulla \($0)" } ?? "Annulla")
    }

    /// Ripete l'ultimo movimento annullato (sul Mac è ⇧⌘Z).
    var redoButton: some View {
        Button {
            _ = store.redo()
        } label: {
            Image(systemName: "arrow.uturn.forward")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 38, height: 38)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassCircle(interactive: true)
        .disabled(store.redoName == nil)
        .opacity(store.redoName == nil ? 0.35 : 1)
        .accessibilityLabel(store.redoName.map { "Ripeti \($0)" } ?? "Ripeti")
    }

    // MARK: Stato e ultimo evento
    
    /// L'ultimo movimento presente nel file (anche se aggiunto da fuori o in una sessione precedente).
    var lastEventText: String? {
        guard let m = store.movements.last else { return nil }
        let what: String
        switch m.kind {
        case .shot: what = "Sparate \(m.quantity)"
        case .added: what = "Aggiunte \(m.quantity)"
        case .opening: what = "Saldo iniziale \(m.quantity)"
        case .adjustment: what = "Rettifica \(m.quantity)"
        }
        let who = store.config.weapon(m.weaponID)?.name ?? store.config.caliberName(m.caliberID)
        let when: String
        if m.hasTime {
            when = m.date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        } else {
            when = m.date.formatted(.dateTime.day().month(.abbreviated).year())
        }
        return "Ultimo: \(what) · \(m.provenance.label.lowercased()) · \(who) · \(when)"
    }

    var statusRow: some View {
        statusLine
            .frame(height: 30)
    }

    /// Priorità: errore o avviso di questa pagina, poi problemi di lettura del file (rosso), poi l'ultimo evento.
    var statusLine: some View {
        let text: String
        let color: Color
        let icon: String
        if !statusText.isEmpty {
            text = statusText
            switch statusKind {
            case .error: color = Palette.danger
            case .warning: color = Palette.warning
            default: color = Palette.muted
            }
            icon = statusKind == .hint ? "info.circle" : "exclamationmark.triangle.fill"
        } else if let m = store.message {
            text = m
            color = Palette.danger
            icon = "exclamationmark.triangle.fill"
        } else if let last = lastEventText {
            text = last
            color = Palette.muted
            icon = "clock.arrow.circlepath"
        } else {
            text = ""
            color = Palette.muted
            icon = "clock.arrow.circlepath"
        }
        return HStack(spacing: 5) {
            if !text.isEmpty {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(text)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .font(.caption)
        .frame(maxWidth: 560)
        .animation(.easeOut(duration: 0.25), value: text)
    }
}
