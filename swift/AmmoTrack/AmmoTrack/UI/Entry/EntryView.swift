//
//  EntryView.swift
//
//  Pagina "Inserimento": una sola casella al centro (cifre grandi, cursore lampeggiante, data cliccabile),
//  freccia giù = aggiunte, freccia su = sparate, selettore ricaricate/comprate, tasto dell'arma
//  (il calibro è quello dell'arma), ultimo evento con "Annulla" e i saldi rispetto ai limiti.
//
//  Tastiera:  cifre   scrivono il numero        ↓  registra "aggiunte"     ↑  registra "sparate"
//             ← →     ricaricate / comprate     ⌫  cancella l'ultima cifra   Esc  svuota (o chiude il selettore)
//
//  Il codice della tastiera e dell'inserimento è in EntryView+Input.swift.
//

import SwiftUI

// MARK: - Tipi di supporto

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

/// Interruttore letto dal monitor dei tasti (che non vede lo stato aggiornato della vista).
@MainActor
final class KeyGate {
    var active = false
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
    @State var keyMonitor: Any? = nil
    @State var gate = KeyGate()
    @State var syncToken = SyncToken()
    @FocusState var inputFocused: Bool
    @Namespace var buttonsNS      // per il morph del vetro fra i due tasti
    @State var addShown = true               // «Aggiunte» visibile: segue showsAddButton, ma solo a banner chiuso
    @State var look = ProvenanceLook(selector: true, bought: false, name: "")   // aspetto mostrato di selettore e tasti
    @State var pageHeight: CGFloat = 700     // altezza della pagina (misurata)
    @State var slotTop: CGFloat = 300        // distanza del tasto armi dall'alto della pagina (misurata)

    let maxLength = 6        // cifre massime nella casella
    /// Secondi fra l'inizio della chiusura del banner e il fondersi/dividersi dei tasti.
    /// 0 = partono insieme; alzalo se vuoi che il banner sia già quasi chiuso.
    let addButtonDelay: Double = 0.15
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

    var body: some View {
        ZStack {
            // Cliccando in un punto qualunque della pagina si chiude il selettore e si torna a scrivere.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    closePicker()
                    inputFocused = true
                }

            VStack(spacing: 0) {
                // In alto: provenienza, tasti, casella, banner armi.
                // Il banner è l'ultimo e si apre verso il basso: non copre più nessun controllo.
                // zIndex alto perché il banner aperto sporge sopra stato e saldi.
                VStack(spacing: 20) {
                    provenanceRow
                    actionButtons
                    amountPill
                    weaponSlot
                }
                .padding(.top, 8)
                .zIndex(10)

                Spacer(minLength: 24)

                // In basso: ultimo movimento attaccato ai saldi
                VStack(spacing: 10) {
                    statusRow
                    BalanceCard()
                }
                .padding(.bottom, 14)
            }
            .padding(.horizontal, 24)
        }
        .coordinateSpace(.named("entryPage"))
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pageHeight = $0 }
        .onAppear {
            addShown = showsAddButton
            look = lookWanted
            gate.active = isActive
            installKeyMonitor()
            DispatchQueue.main.async { inputFocused = isActive }
        }
        .onDisappear { removeKeyMonitor() }
        .onChange(of: isActive) { _, active in
            gate.active = active
            if active {
                DispatchQueue.main.async { inputFocused = true }
            } else {
                inputFocused = false
                pickerOpen = false
                showCalendar = false
            }
        }
        .onChange(of: inputText) {
            // Avvisi ed errori spariscono quando riprendi a scrivere;
            // l'ultimo evento (con l'orario) resta visibile.
            if statusKind != .none && !inputText.isEmpty {
                statusText = ""
                statusKind = .none
            }
        }
        .onChange(of: showsAddButton) { _, _ in
            if !pickerOpen { syncControls() }                       // cambio a banner chiuso (es. arma archiviata)
        }
        .onChange(of: pickerOpen) { _, open in
            if !open { syncControls(after: addButtonDelay) }        // il banner si è chiuso
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
    var actionButtons: some View {
        GlassContainer(spacing: 24) {
            HStack(spacing: 24) {
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
        .frame(width: 300, height: 92)
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
        .focusable(isActive, interactions: .edit)
        .focused($inputFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: [.down, .repeat]) { press in handleKey(press) }
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
            HStack(spacing: 5) {
                Text(dateTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(day == nil ? Palette.muted : Palette.reloaded)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 12)
            .padding(.top, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showCalendar, arrowEdge: .bottom) { calendarPopover }
    }

    var dayBinding: Binding<Date> {
        Binding(get: { day ?? Date() },
                set: { new in day = Cal.cal.isDateInToday(new) ? nil : new })
    }

    var calendarPopover: some View {
        VStack(spacing: 10) {
            DatePicker("Data", selection: dayBinding, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
            HStack {
                Button("Oggi") {
                    day = nil
                    showCalendar = false
                }
                .glassButton()
                Spacer()
                Button("Fine") {
                    showCalendar = false
                    inputFocused = true
                }
                .glassProminentButton()
            }
        }
        .padding(14)
        .frame(width: 290)
    }

    // MARK: Provenienza

    /// Ricaricate / comprate. Per il .22 non c'è scelta: compare solo la nota.
    var provenanceRow: some View {
        ZStack {
            if look.selector {
                GlassSegmented(options: Provenance.allCases,
                               selection: provenanceBinding,
                               segmentWidth: 124,
                               walls: .horizontal) { p, selected in
                    HStack(spacing: 7) {
                        Image(systemName: p.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(p.color)
                        Text(p.label)
                            .font(.system(size: 13, weight: selected ? .semibold : .medium))
                            .foregroundStyle(selected ? Color.white : Color.white.opacity(0.68))
                    }
                }
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
        .frame(height: 36)
    }

    // MARK: Stato e ultimo evento

    var canUndo: Bool {
        guard let id = store.lastAddedID else { return false }
        return store.movements.contains { $0.id == id }
    }

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
        HStack(spacing: 10) {
            statusLine
            if canUndo {
                Button {
                    undo()
                } label: {
                    Label("Annulla", systemImage: "arrow.uturn.backward")
                }
                .controlSize(.small)
                .glassButton()
            }
        }
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
