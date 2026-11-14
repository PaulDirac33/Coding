//
//  EntryView.swift
//
//  Pagina "Inserimento": una sola casella al centro (cifre grandi, cursore lampeggiante, data cliccabile),
//  freccia giù = sparate, freccia su = aggiunte, selettore ricaricate/comprate, tasto dell'arma
//  (il calibro è quello dell'arma), ultimo evento con "Annulla" e i saldi rispetto ai limiti.
//
//  Tastiera:  cifre   scrivono il numero        ↓  registra "sparate"     ↑  registra "aggiunte"
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

// MARK: - Vista

struct EntryView: View {
    @EnvironmentObject var store: DataStore

    /// true quando questa è la pagina visibile: solo allora la casella riceve i tasti.
    let isActive: Bool
    let onManageWeapons: () -> Void

    // L'ultima scelta resta in memoria: dopo un'uscita basta scrivere "50" e premere ↓.
    @AppStorage("entry.caliber") var storedCaliber = ""
    /// Vuota all'avvio: si parte sempre dal solo calibro (l'arma serve per gli spari, non per le aggiunte).
    @State var selectedWeapon = ""
    @AppStorage("entry.provenance") var storedProvenance = "ricaricate"

    // inserimento
    @State var inputText = ""
    @State var day: Date? = nil              // nil = oggi
    @State var showCalendar = false
    @State var pickerOpen = false
    @State var statusText = ""
    @State var statusKind: EntryStatus = .none
    @State var flash = false
    @State var keyMonitor: Any? = nil
    @State var gate = KeyGate()
    @FocusState var inputFocused: Bool

    let maxLength = 6        // cifre massime nella casella

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
    var provenance: Provenance {
        allowsReload ? (Provenance(rawValue: storedProvenance) ?? .reloaded) : .bought
    }

    var provenanceBinding: Binding<Provenance> {
        Binding(get: { provenance }, set: { setProvenance($0) })
    }

    var quantity: Int? {
        guard let q = Int(inputText), q > 0 else { return nil }
        return q
    }

    var canCommit: Bool { quantity != nil && !target.caliberID.isEmpty }
    /// Uno sparo vuole l'arma, tranne se il calibro non ne ha nessuna configurata.
    var canShoot: Bool {
        canCommit && (target.weaponID != nil || store.config.activeWeapons(for: target.caliberID).isEmpty)
    }

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

            VStack(spacing: 24) {
                Spacer(minLength: 0)
                weaponSlot
                entryRow
                provenanceRow
                statusRow
                Spacer(minLength: 0)
                BalanceCard()
                    .padding(.bottom, 14)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
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
    }

    // MARK: Arma

    /// Spazio fisso per il tasto dell'arma: quando si apre il pannello, questo sporge sopra il resto.
    var weaponSlot: some View {
        Color.clear
            .frame(width: 320, height: 52)
            .overlay(alignment: .top) {
                WeaponPicker(target: targetBinding, isOpen: $pickerOpen, onManage: onManageWeapons)
            }
            .zIndex(10)
    }

    // MARK: Casella e frecce

    var entryRow: some View {
        HStack(alignment: .center, spacing: 26) {
            directionButton(.shot)
            amountPill
            directionButton(.added)
        }
    }

    /// Freccia giù = sparate, freccia su = aggiunte. Hanno il colore della provenienza scelta (oro = ricaricate,
    /// rosso = comprate): direzione e provenienza restano due cose separate.
    func directionButton(_ kind: MovementKind) -> some View {
        let symbol = kind == .shot ? "arrow.down" : "arrow.up"
        let title = kind == .shot ? "Sparate" : "Aggiunte"
        return VStack(spacing: 8) {
            Button {
                commit(kind)
            } label: {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .bold))
                    .frame(width: 40, height: 40)
            }
            .buttonBorderShape(.circle)
            .glassProminentButton()
            .tint(provenance.color)
            .controlSize(.large)
            .disabled(kind == .shot ? !canShoot : !canCommit)

            Text(title)
                .font(.caption)
                .foregroundStyle(Palette.muted)
        }
        .frame(width: 84)
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
        .animation(.easeOut(duration: 0.25), value: inputFocused)
        .animation(.easeOut(duration: 0.25), value: flash)
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
                    .foregroundStyle(Color.white)
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
            if allowsReload {
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
            } else {
                HStack(spacing: 6) {
                    Image(systemName: Provenance.bought.symbol)
                        .foregroundStyle(Provenance.bought.color)
                    Text("\(caliberName) non si ricarica: solo comprate")
                        .foregroundStyle(Palette.muted)
                }
                .font(.caption)
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
