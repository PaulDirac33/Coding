//
//  WeaponPicker.swift
//
//  Tasto di vetro con l'arma scelta (il calibro è quello dell'arma). Cliccandolo si apre un banner di vetro
//  con le armi preimpostate, raggruppate per calibro: su macOS 26 il tasto si trasforma nel banner
//  (GlassEffectContainer + glassEffectID); sui sistemi precedenti è un popover.
//
//  Nel banner la scelta è una "bolla" di vetro che scorre in verticale come la lente di GlassSegmented:
//  premi e trascini, rilasci sulla voce che vuoi. Le armi si aggiungono dalla pagina Armi.
//
//  Se un calibro non ha ancora armi compare la voce "Senza arma": serve anche per le entrate
//  (acquisti e ricariche non hanno un'arma) e per lo storico importato.
//

import SwiftUI

/// Tasti che EntryView manda al banner armi.
enum PickerKey: Equatable {
    case open       // ⌘↓
    case up         // ↑
    case down       // ↓
    case confirm    // ↩
    case toggle     // ⌘↩
}

/// Un comando per il banner. `id` aumenta a ogni invio, così lo stesso tasto premuto due volte
/// è comunque un cambiamento per onChange.
struct PickerCommand: Equatable {
    var id = 0
    var key: PickerKey = .open
}

struct WeaponPicker: View {
    @EnvironmentObject var store: DataStore

    @Binding var target: EntryTarget
    @Binding var isOpen: Bool
    var maxPanelHeight: CGFloat = 360     // la decide EntryView: dal tasto fino al fondo della pagina
    var command = PickerCommand()         // comandi da tastiera mandati da EntryView

    @Namespace private var ns

    private let buttonWidth: CGFloat = 320
    private let panelWidth: CGFloat = EntryLayout.controlWidth
    private let compactHeight: CGFloat = 44             // altezza del tasto quando c'è solo il calibro
    private let compactCartridgeLength: CGFloat = 64    // lunghezza della cartuccia orizzontale (in punti)

    /// Spazio di coordinate in cui le righe dicono dove stanno (serve alla bolla).
    private let rowsSpace = "pickerRows"
    /// Spazio di coordinate dell'area visibile del banner (serve a sapere quali righe si vedono).
    private let viewportSpace = "pickerViewport"
    /// Margine sopra e sotto le righe dentro l'area che scorre: lascia posto alla bolla premuta, che sporge di 3 pt.
    private let scrollPad: CGFloat = 4
    /// Altezza riservata ai pallini "ci sono altre voci" in alto o in basso.
    private let moreStrip: CGFloat = 18

    /// Chiusura del banner dopo la scelta di una voce: più lenta dell'apertura (che resta 0,42 / 0,82).
    private static var closeAnimation: Animation {
        .spring(response: 0.5, dampingFraction: 0.88)
    }
    /// Separatore fra calibro e matricola. Il trattino «–» (en dash) è un unico segno, come il "--" di LaTeX.
    /// Alternative: " • " oppure " - ".
    private static let separator = "  •  "
    /// Animazione di assorbimento e comparsa delle armi: la stessa per righe e altezza del banner.
    private static var absorbAnimation: Animation {
        .spring(response: 0.42, dampingFraction: 0.86)
    }

    /// Come entrano ed escono le righe delle armi: sfumano in fretta e si restringono verso la riga del calibro.
    private static var absorbTransition: AnyTransition {
        AnyTransition.opacity.animation(.easeOut(duration: 0.18))
            .combined(with: .scale(scale: 0.92, anchor: .top))
    }

    /// Posizione di ogni riga, raccolta dalle righe stesse.
    @State private var rowFrames: [String: CGRect] = [:]
    /// Altezza che le righe avrebbero senza scorrimento (misurata quando il banner è aperto).
    @State private var rowsHeight: CGFloat = 0
    /// Calibri con le armi assorbite (id separati da virgola). Si ricorda anche fra un avvio e l'altro.
    @AppStorage("picker.collapsedCalibers") private var collapsedRaw = ""
    /// Posizione delle bolle piccole (una per calibro che ha armi), raccolta dalle righe.
    @State private var toggleFrames: [String: CGRect] = [:]
    /// false = il banner appena aperto mostra le righe senza ScrollView; diventa true a trasformazione finita.
    @State private var scrollReady = false
    /// Numero dell'ultima apertura: i timer delle aperture precedenti non fanno più nulla.
    @State private var scrollToken = SyncToken()
    /// Posizione in alto delle righe rispetto all'area visibile del banner (cambia quando scorri).
    @State private var contentTop: CGFloat = 0
    /// Voce evidenziata con la tastiera (↑ ↓), nella forma "calibro|arma". nil = la voce già scelta.
    @State private var highlightKey: String? = nil
    /// Altezza del puntatore mentre premi o trascini (nil = a riposo).
    /// Si azzera con una molla poco smorzata: è il rimbalzo, come in GlassSegmented.
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.36, dampingFraction: 0.65)))
    private var drag: CGFloat? = nil
    /// Calibro la cui bolla piccola è premuta in questo momento (nil = nessuna).
    @GestureState private var pressedToggle: String? = nil

    private static var morphs: Bool {
        if #available(iOS 26.0, macOS 26.0, *) { return true }
        return false
    }

    var body: some View {
        Group {
            if WeaponPicker.morphs {
                morphing
            } else {
                classic
            }
        }
        .onChange(of: command) { _, c in handle(c) }
        .onChange(of: isOpen) { _, _ in highlightKey = nil }     // a ogni apertura/chiusura riparte dalla voce scelta
    }

    // MARK: Le due versioni

    /// macOS 26: il tasto e il banner sono lo stesso pezzo di vetro, che si trasforma.
    private var morphing: some View {
        GlassContainer(spacing: 12) {
            if isOpen {
                panel
                    .liquidGlass(cornerRadius: 26)
                    .animation(Self.absorbAnimation, value: collapsedRaw)
                    .glassMorphID("weaponPicker", in: ns)
            } else {
                pickerButton
                    .glassCapsule(interactive: true)
                    .glassMorphID("weaponPicker", in: ns)
            }
        }
    }

    /// Sistemi precedenti: tasto in materiale traslucido e popover.
    private var classic: some View {
        pickerButton
            .glassCapsule()
            .popover(isPresented: $isOpen, arrowEdge: .bottom) {
                panel
                    .padding(6)
                    .keepsPopover()
            }
    }

    // MARK: Tasto

    private var currentWeapon: Weapon? { store.config.weapon(target.weaponID) }
    /// Solo il calibro, nessuna arma: il tasto si riduce.
    private var isCaliberOnly: Bool {
        currentWeapon == nil && !target.caliberID.isEmpty
    }

    private var cartridgeStyle: CartridgeStyle {
        store.config.caliber(target.caliberID)?.cartridgeStyle ?? .pistol
    }

    /// Con un'arma: il suo nome. Senza arma: il nome esteso del calibro.
    private var titleText: String {
        if target.caliberID.isEmpty { return "Nessun calibro" }
        if let w = currentWeapon { return w.name.isEmpty ? "Senza nome" : w.name }
        return store.config.caliberLongName(target.caliberID)
    }

    /// Con un'arma: calibro e matricola. Senza arma: "Senza arma".
    private var subtitleText: String {
        guard !target.caliberID.isEmpty else { return "Aggiungi un calibro dalle Impostazioni" }
        guard let w = currentWeapon else { return "Senza arma" }
        var parts = [store.config.caliberName(target.caliberID)]
        if !w.serial.isEmpty { parts.append(w.serial) }
        return parts.joined(separator: Self.separator)
    }

    private var pickerButton: some View {
        Button {
            openPicker()
        } label: {
            if isCaliberOnly {
                compactLabel
            } else {
                fullLabel
            }
        }
        .buttonStyle(.plain)
    }
    /// Apre il banner. Prima di aprire azzera lo scorrimento, così il banner nasce già senza ScrollView;
    /// la ScrollView arriva a trasformazione finita. Ogni apertura invalida i timer delle precedenti.
    private func openPicker() {
        scrollReady = false
        scrollToken.value += 1
        let ticket = scrollToken.value
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { isOpen = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            guard scrollToken.value == ticket, isOpen else { return }
            scrollReady = true
        }
    }

    /// Con un'arma: miniatura, nome e calibro/matricola sulla seconda riga. Nessuna larghezza fissa:
    /// il tasto si stringe attorno al contenuto, come nel caso del solo calibro.
    private var fullLabel: some View {
        HStack(spacing: 10) {
            WeaponThumb(weapon: currentWeapon, caliberID: target.caliberID, size: 32)
            VStack(alignment: .center, spacing: 1) {
                Text(titleText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                    .offset(y: 2)
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.muted)
                .padding(.leading, 4)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .contentShape(Capsule())
    }

    /// Solo il calibro: cartuccia orizzontale grande + nome. Nessuna larghezza fissa, quindi il tasto
    /// si stringe attorno al contenuto (e resta centrato, perché lo slot in EntryView centra il tasto).
    private var compactLabel: some View {
        HStack(spacing: 14) {
            CartridgeIcon(style: cartridgeStyle, height: compactCartridgeLength, horizontal: true)
                .foregroundStyle(Palette.muted)
            Text(titleText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 18)
        .frame(height: compactHeight)
        .contentShape(Capsule())
    }

    // MARK: Banner

    private var rowCount: Int {
        store.config.calibers.reduce(0) { total, cal in
            total + store.config.activeWeapons(for: cal.id).count + 1   // +1 = "Senza arma"
        }
    }

    private var roomForRows: CGFloat { max(120, maxPanelHeight - 20) }
    private var fullEstimate: CGFloat {
        CGFloat(rowCount) * 50 + CGFloat(store.config.calibers.count) * 24
    }
    /// true = le righe non entrano nel banner: servono ritaglio o scorrimento.
    private var isLimited: Bool { fullEstimate > roomForRows }
    /// Altezza dell'area visibile quando le righe non entrano.
    private var viewportHeight: CGFloat {
        min(roomForRows, (rowsHeight > 0 ? rowsHeight : fullEstimate) + scrollPad * 2)
    }
    /// Altezza che il banner mostra davvero. Se in basso c'è una voce nascosta, il banner finisce subito
    /// sotto l'ultima voce visibile (più la fascia dei pallini). Altrimenti è l'altezza piena.
    private var shownHeight: CGFloat {
        let v = visibility
        guard v.below else { return viewportHeight }
        let lastBottom = rowFrames
            .filter { !v.hidden.contains($0.key) }
            .values.map { $0.maxY }.max()
        guard let lastBottom else { return viewportHeight }
        // 3 pt = quanto sporge la bolla premuta sull'ultima voce.
        return min(viewportHeight, lastBottom + contentTop + 3 + moreStrip)
    }
    /// Zona occupata da una riga: per la riga di un calibro include la sua intestazione, che sta sopra.
    private func rowSpan(_ key: String, _ r: CGRect) -> (minY: CGFloat, maxY: CGFloat) {
        (key.hasSuffix("|") ? r.minY - 16 : r.minY, r.maxY)
    }

    /// Di quanto salgono tutte le voci per chiudere lo spazio fra i pallini in alto e la prima voce visibile.
    /// È 0 se in alto non ci sono voci nascoste.
    private var topShift: CGFloat {
        let v = visibility
        guard v.above else { return 0 }
        let firstTop = rowFrames
            .filter { !v.hidden.contains($0.key) }
            .map { rowSpan($0.key, $0.value).minY }
            .min()
        guard let firstTop else { return 0 }
        // La prima voce deve stare a 3 pt (margine della bolla) + la fascia dei pallini dal bordo alto.
        return max(0, firstTop + contentTop - (3 + moreStrip))
    }

    private var panel: some View {
        let shift = topShift
        return Group {
            if isLimited {
                Group {
                    if scrollReady {
                        ScrollViewReader { proxy in
                            ScrollView { rows.padding(.horizontal, 10).padding(.vertical, scrollPad) }
                                .scrollIndicators(.never)
                                .onChange(of: highlightKey) { _, new in
                                    // Voce fuori vista (o sotto i pallini): la porto al centro.
                                    guard let new, visibility.hidden.contains(new) else { return }
                                    withAnimation(Self.absorbAnimation) { proxy.scrollTo(new, anchor: .center) }
                                }
                        }
                    } else {
                        rows
                            .padding(.horizontal, 10)
                            .padding(.vertical, scrollPad)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(height: viewportHeight, alignment: .top)       // altezza piena: lo scorrimento non cambia
                .coordinateSpace(.named(viewportSpace))               // PRIMA dello spostamento, sennò la misura si morde la coda
                .offset(y: -shift)                                    // le voci salgono
                .frame(height: max(shownHeight - shift, 0), alignment: .top)   // il banner si accorcia dal basso
                .clipped()
                .animation(Self.absorbAnimation, value: visibility.hidden)
            } else {
                rows
                    .padding(.horizontal, 10)
                    .coordinateSpace(.named(viewportSpace))
            }
        }
        .overlay(alignment: .top) { moreDots(visibility.above, top: true) }
        .overlay(alignment: .bottom) { moreDots(visibility.below, top: false) }
        .padding(.vertical, 10)
        .frame(width: panelWidth)
    }
    /// Tre bollicine: dicono che sopra o sotto ci sono altre voci (scorri, o alza la finestra).
    private func moreDots(_ shown: Bool, top: Bool) -> some View {
        ZStack {
            if shown {
                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { _ in
                        AbsorbGlass().frame(width: 8, height: 8)
                    }
                }
                .frame(height: moreStrip)
                .transition(.opacity.combined(with: .offset(y: top ? -10 : 10)))
            }
        }
        .animation(Self.absorbAnimation, value: shown)
        .allowsHitTesting(false)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(store.config.calibers) { cal in
                caliberSection(cal)
            }
        }
        .animation(Self.absorbAnimation, value: collapsedRaw)
        .coordinateSpace(.named(rowsSpace))
        .onPreferenceChange(RowFramesKey.self) { rowFrames = $0 }
        .onPreferenceChange(ToggleFramesKey.self) { toggleFrames = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowsHeight = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(viewportSpace)).minY } action: { contentTop = $0 }
        .background(alignment: .topLeading) { lens }
        .contentShape(Rectangle())
        .gesture(pickGesture)
    }

    @ViewBuilder
    private func caliberSection(_ cal: Caliber) -> some View {
        let all = store.config.activeWeapons(for: cal.id)
        let isAbsorbed = absorbed.contains(cal.id)
        let shown = isAbsorbed ? all.filter { $0.id == target.weaponID } : all
        let hidden = all.count - shown.count
        let balance = store.ledger.balance(for: cal.id)
        let unseen = visibility.hidden
        let caliberKey = key(EntryTarget(caliberID: cal.id, weaponID: nil))

        HStack(spacing: 6) {
            Text(cal.name.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.muted)
            if hidden > 0 {
                Text("· \(hidden) \(hidden == 1 ? "arma nascosta" : "armi nascoste")")
                    .font(.caption2)
                    .foregroundStyle(Palette.muted)
            }
            Spacer()
            Text("\(numText(balance.total)) cartucce")
                .font(.caption2)
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .opacity(unseen.contains(caliberKey) ? 0 : 1)
        .animation(.easeOut(duration: 0.15), value: unseen.contains(caliberKey))

        PickerRow(rowKey: caliberKey,
                  space: rowsSpace,
                  weapon: nil,
                  title: cal.displayName,
                  subtitle: "Senza arma",
                  cartridge: cal.cartridgeStyle,
                  toggleID: all.isEmpty ? nil : cal.id,
                  absorbed: isAbsorbed,
                  togglePressed: pressedToggle == cal.id,
                  faded: unseen.contains(caliberKey))
        ForEach(shown) { w in
            PickerRow(rowKey: key(EntryTarget(caliberID: cal.id, weaponID: w.id)),
                      space: rowsSpace,
                      weapon: w,
                      title: w.name,
                      subtitle: w.serial.isEmpty ? cal.name : "\(cal.name)\(Self.separator)\(w.serial)",
                      faded: unseen.contains(key(EntryTarget(caliberID: cal.id, weaponID: w.id))))
                .transition(Self.absorbTransition)
        }
    }

    // MARK: Armi assorbite (bolla piccola dei calibri)

    private var absorbed: Set<String> {
        Set(collapsedRaw.split(separator: ",").map(String.init))
    }

    private func toggleAbsorbed(_ id: String) {
        var set = absorbed
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
        withAnimation(Self.absorbAnimation) {
            collapsedRaw = set.sorted().joined(separator: ",")
        }
    }

    /// Calibro la cui bolla piccola contiene il punto (area un po' più larga della bolla).
    private func toggleHit(_ p: CGPoint) -> String? {
        let hidden = visibility.hidden
        return toggleFrames.first {
            !hidden.contains("\($0.key)|")
                && $0.value.insetBy(dx: -AbsorbBubble.hitSlop, dy: -AbsorbBubble.hitSlop).contains(p)
        }?.key
    }
    /// Sceglie una voce: la bolla si assesta, poi il banner si richiude (più lentamente).
       private func choose(_ t: EntryTarget) {
           let changed = t != target
           if changed {
               withAnimation(.spring(response: 0.36, dampingFraction: 0.65)) { target = t }
           }
           DispatchQueue.main.asyncAfter(deadline: .now() + (changed ? 0.30 : 0)) {
               withAnimation(Self.closeAnimation) { isOpen = false }
           }
       }

       // MARK: Tastiera (comandi mandati da EntryView)

       private func handle(_ c: PickerCommand) {
           switch c.key {
           case .open:
               if !isOpen { openPicker() }
           case .up:
               moveHighlight(-1)
           case .down:
               moveHighlight(1)
           case .confirm:
               confirmHighlight()
           case .toggle:
               toggleHighlighted()
           }
       }

       /// Le voci del banner dall'alto in basso, come le mostra: il calibro, poi le sue armi
       /// (con le armi assorbite, solo quella scelta).
       private var orderedKeys: [String] {
           var keys: [String] = []
           for cal in store.config.calibers {
               keys.append(key(EntryTarget(caliberID: cal.id, weaponID: nil)))
               var shown = store.config.activeWeapons(for: cal.id)
               if absorbed.contains(cal.id) { shown = shown.filter { $0.id == target.weaponID } }
               for w in shown {
                   keys.append(key(EntryTarget(caliberID: cal.id, weaponID: w.id)))
               }
           }
           return keys
       }

       /// ↑ ↓: sposta la bolla di una voce. Agli estremi si ferma (la bolla sbatte contro il muro).
       private func moveHighlight(_ delta: Int) {
           guard isOpen else { return }
           let keys = orderedKeys
           guard !keys.isEmpty else { return }
           let current = keys.firstIndex(of: selectedKey) ?? (delta > 0 ? -1 : keys.count)
           let next = min(max(current + delta, 0), keys.count - 1)
           guard keys[next] != selectedKey else { return }
           withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) { highlightKey = keys[next] }
       }

       /// ↩: sceglie la voce su cui sta la bolla e chiude il banner.
       private func confirmHighlight() {
           guard isOpen, let t = targets[selectedKey] else { return }
           choose(t)
       }

       /// ⌘↩: se la bolla sta su un calibro che ha armi, assorbe o espande le sue armi (come la bolla piccola).
       private func toggleHighlighted() {
           guard isOpen, selectedKey.hasSuffix("|") else { return }      // le righe dei calibri finiscono con "|"
           let id = String(selectedKey.dropLast())
           guard !store.config.activeWeapons(for: id).isEmpty else { return }
           toggleAbsorbed(id)
       }
    // MARK: Bolla e selezione

    private func key(_ t: EntryTarget) -> String {
        "\(t.caliberID)|\(t.weaponID ?? "")"
    }

    /// La voce su cui sta la bolla: quella evidenziata con la tastiera, altrimenti quella scelta.
    private var selectedKey: String { highlightKey ?? key(target) }

    /// Tutte le scelte possibili, per chiave.
    private var targets: [String: EntryTarget] {
        var map: [String: EntryTarget] = [:]
        for cal in store.config.calibers {
            let c = EntryTarget(caliberID: cal.id, weaponID: nil)
            map[key(c)] = c
            for w in store.config.activeWeapons(for: cal.id) {
                let t = EntryTarget(caliberID: cal.id, weaponID: w.id)
                map[key(t)] = t
            }
        }
        return map
    }

    /// Premi = la bolla corre dal puntatore; trascini = lo segue; rilasci = sceglie la riga sotto il puntatore.
    private var pickGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(rowsSpace))
            .updating($drag) { g, state, transaction in
                // Pressione iniziata sulla bolla piccola: la bolla grande non si muove.
                guard toggleHit(g.startLocation) == nil else { return }
                // Al primo tocco la bolla raggiunge il punto con una molla, poi segue senza ritardo.
                transaction.animation = (state == nil)
                ? Animation.spring(response: 0.28, dampingFraction: 0.7)                    : nil
                state = g.location.y
            }
            .updating($pressedToggle) { g, state, _ in
                state = toggleHit(g.startLocation)
            }
            .onEnded { g in
                if let id = toggleHit(g.startLocation) {
                    // Inizia e finisce sulla stessa bolla piccola: assorbe o espande. Selezione e banner restano com'erano.
                    if toggleHit(g.location) == id { toggleAbsorbed(id) }
                } else {
                    finish(at: g.location)
                }
            }
    }

    private func finish(at point: CGPoint) {
            // Sceglie la riga più vicina al punto di rilascio: è quella su cui la bolla si è già fermata,
            // anche se rilasci fra due righe o su un'intestazione di calibro.
            guard let hit = selectableFrames.min(by: { abs($0.value.midY - point.y) < abs($1.value.midY - point.y) })?.key,
                  let t = targets[hit] else { return }
            choose(t)
        }

    /// Chiavi delle righe dei calibri che hanno la bolla piccola.
    private var shortKeys: Set<String> {
        Set(store.config.calibers
            .filter { !store.config.activeWeapons(for: $0.id).isEmpty }
            .map { key(EntryTarget(caliberID: $0.id, weaponID: nil)) })
    }
    /// Bolla grande a riposo su una riga: larga come la riga, meno lo spazio della bolla piccola sui calibri che ne hanno una.
    private func restRect(_ key: String, _ frame: CGRect) -> CGRect {
        var r = frame.insetBy(dx: lensInset, dy: 0)
        if shortKeys.contains(key) { r.size.width -= AbsorbBubble.slot }
        return r
    }

    /// Bolla grande a riposo su una riga: larga come la riga, meno lo spazio della bolla piccola sui calibri che ne hanno una.
    private func lensRect() -> CGRect? {
        guard let full = rowFrames[selectedKey] else { return nil }
        let rest = restRect(selectedKey, full)
        guard let y = drag else { return rest }

        let ordered = selectableFrames.sorted { $0.value.midY < $1.value.midY }
        guard let first = ordered.first, let last = ordered.last else { return rest }
        let p = min(max(y, first.value.midY), last.value.midY)     // il puntatore, fra la prima e l'ultima riga

        // Partenza: la prima riga. Se il puntatore è più in basso, il ciclo sostituisce i valori.
        var cy = first.value.midY
        var h = first.value.height
        var w = restRect(first.key, first.value).width

        // Fra le due righe sopra e sotto il puntatore la bolla non segue il dito alla pari:
        // vicino al centro di una riga rallenta (ne viene catturata), a metà strada accelera verso l'altra.
        // Altezza e larghezza usano lo stesso avanzamento, così la forma resta coerente con la riga.
        for i in 1..<ordered.count {
            let a = ordered[i - 1]
            let b = ordered[i]
            guard p <= b.value.midY else { continue }
            let t = (p - a.value.midY) / (b.value.midY - a.value.midY)     // 0 = su a, 1 = su b
            let smooth = t * t * (3 - 2 * t)
            let m = t + (smooth - t) * magnet
            cy = a.value.midY + (b.value.midY - a.value.midY) * m
            h = a.value.height + (b.value.height - a.value.height) * m
            let wa = restRect(a.key, a.value).width
            let wb = restRect(b.key, b.value).width
            w = wa + (wb - wa) * m
            break
        }

        let height = h + 6                                  // premuta, si ingrandisce un po'
        return CGRect(x: rest.minX - 4, y: cy - height / 2, width: w + 8, height: height)
    }

    /// I muri della bolla: bordo alto della prima riga e basso dell'ultima, con 2 pt di respiro (come in GlassSegmented).
    /// Quanto la bolla può uscire ai lati dai bordi delle righe. Il pannello ha 10 pt di margine:
    /// sotto 10 la bolla resta dentro il banner, sopra sporge. Alza o abbassa a gusto.
    private let sideRoom: CGFloat = 5
    /// Quanto stringere la bolla per lato rispetto alla riga (0 = larga come la riga).
    private let lensInset: CGFloat = 3
    /// Quanto la bolla viene attirata dal centro delle righe mentre trascini (0 = segue il dito alla pari).
    /// Sopra 0,8 si "appiccica" troppo.
    private let magnet: CGFloat = 0.3
    /// Righe visibili per intero (con 3 pt di margine per la bolla premuta): le sole su cui la bolla può andare.
    /// Se le righe entrano tutte nel banner, sono tutte.
    /// Quali righe non si vedono per intero nel banner, e se ce ne sono sopra o sotto.
    /// Quando ci sono, riservo una striscia ai pallini e nascondo anche le righe che ci finirebbero sopra.
    private var visibility: (hidden: Set<String>, above: Bool, below: Bool) {
        guard isLimited, !rowFrames.isEmpty else { return ([], false, false) }
        let top = -contentTop + 3
        let bottom = -contentTop + viewportHeight - 3

        // La riga di un calibro porta con sé la sua intestazione, che sta sopra.
        func span(_ key: String, _ r: CGRect) -> (minY: CGFloat, maxY: CGFloat) {
            (key.hasSuffix("|") ? r.minY - 16 : r.minY, r.maxY)
        }

        var above = false
        var below = false
        for (k, r) in rowFrames {
            let s = span(k, r)
            if s.minY < top { above = true }
            if s.maxY > bottom { below = true }
        }
        guard above || below else { return ([], false, false) }

        let topLimit = top + (above ? moreStrip : 0)
        let bottomLimit = bottom - (below ? moreStrip : 0)
        var hidden = Set<String>()
        for (k, r) in rowFrames {
            let s = span(k, r)
            if s.minY < topLimit || s.maxY > bottomLimit { hidden.insert(k) }
        }
        // Banner così basso da non mostrare nemmeno una voce: meglio non nascondere nulla.
        if hidden.count == rowFrames.count { return ([], false, false) }
        return (hidden, above, below)
    }

    /// Le righe su cui la bolla può andare: quelle che si vedono per intero.
    private var selectableFrames: [String: CGRect] {
        let hidden = visibility.hidden
        return rowFrames.filter { !hidden.contains($0.key) }
    }

    private var wallFrames: [CGRect] { Array(selectableFrames.values) }

    /// A riposo la bolla grande non si vede se la sua riga è nascosta.
    private var lensHidden: Bool { drag == nil && visibility.hidden.contains(selectedKey) }
    /// I muri della bolla: in alto e in basso i bordi della prima e dell'ultima riga (+2 pt di respiro),
    /// ai lati i bordi delle righe più `sideRoom`.
    private var wallRange: (top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat)? {
        let rects = wallFrames
        guard let top = rects.map({ $0.minY }).min(),
              let bottom = rects.map({ $0.maxY }).max(),
              let left = rects.map({ $0.minX }).min(),
              let right = rects.map({ $0.maxX }).max() else { return nil }
        return (top - 0, bottom + 2, left - sideRoom, right + sideRoom)
    }

    @ViewBuilder
    private var lens: some View {
        if let r = lensRect(), let walls = wallRange {
            PickerLens(pressed: drag != nil)
                .frame(width: r.width, height: r.height)
                .modifier(PickerLensEffect(minX: r.minX, width: r.width,
                                           minY: r.minY, height: r.height,
                                           wallTop: walls.top, wallBottom: walls.bottom,
                                           wallLeft: walls.left, wallRight: walls.right))
                .animation(.spring(response: 0.42, dampingFraction: 0.82), value: rowFrames)
                .opacity(lensHidden ? 0 : 1)
                .animation(.easeOut(duration: 0.15), value: lensHidden)
        }
    }
}

// MARK: - Supporto

/// Ogni riga scrive qui la propria posizione.
private nonisolated struct RowFramesKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
/// Ogni bolla piccola scrive qui la propria posizione (chiave = id del calibro).
private nonisolated struct ToggleFramesKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Misure della bolla piccola (a destra dei calibri che hanno armi).
private enum AbsorbBubble {
    static let size: CGFloat = 22           // diametro con le armi visibili
    static let smallScale: CGFloat = 0.64   // con le armi assorbite: 14 pt
    static let slot: CGFloat = 30           // spazio che toglie alla bolla grande su quelle righe
    static let edge: CGFloat = 3            // distanza dal bordo destro della riga (come lensInset)
    static let hitSlop: CGFloat = 5         // area cliccabile oltre il bordo della bolla
}
/// Il vetro delle bolle piccole: stessi ingredienti della bolla grande quando è premuta
/// (glassEffect, riflesso, bordo), con un'ombra più leggera perché il cerchio è piccolo.
private struct AbsorbGlass: View {
    @ViewBuilder
    private var base: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Color.clear
                .glassEffect(.clear.tint(Color.white.opacity(0.12)), in: Circle())
        } else {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().fill(Color.white.opacity(0.14)))
        }
    }

    var body: some View {
        base
            .overlay(Circle().fill(LinearGradient(
                colors: [Color.white.opacity(0.16), Color.clear, Color.white.opacity(0.05)],
                startPoint: .top, endPoint: .bottom)))
            .overlay(Circle().strokeBorder(LinearGradient(
                colors: [Color.white.opacity(0.80), Color.white.opacity(0.10), Color.white.opacity(0.45)],
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.40), radius: 6, y: 2)
    }
}

/// Posiziona e deforma la bolla del banner. Conosce la posizione a ogni fotogramma, compreso lo "sfondamento"
/// della molla: se supera un muro (in alto o in basso), il bordo si ferma lì e il resto si schiaccia contro di esso.
/// È la versione verticale di LensEffect in GlassSegmented.
private struct PickerLensEffect: GeometryEffect {
    var minX: CGFloat
    var width: CGFloat
    var minY: CGFloat
    var height: CGFloat
    let wallTop: CGFloat
    let wallBottom: CGFloat
    let wallLeft: CGFloat
    let wallRight: CGFloat

    /// Schiacciamento massimo (frazione dell'altezza) e quanto la bolla si allarga ai lati.
    /// Qui sono molto più bassi che nel selettore: le righe sono alte ~46 pt e il pannello ha poco margine ai lati.
    private static let maxSquash: CGFloat = 1
    private static let bulge: CGFloat = 0.08

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(minX, width), AnimatablePair(minY, height)) }
        set {
            minX = newValue.first.first
            width = newValue.first.second
            minY = newValue.second.first
            height = newValue.second.second
        }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard size.width > 0, size.height > 0, height > 0 else { return ProjectionTransform() }

        var top = minY
        var bottom = minY + height
        var squash: CGFloat = 0

        // di quanto sfonderebbe ciascun muro
        let hitTop = max(0, wallTop - top)
        let hitBottom = max(0, bottom - wallBottom)
        let hit = max(hitTop, hitBottom)

        if hit > 0 {
            let limit = Self.maxSquash * height
            let c = limit * tanh(hit / limit)          // compressione morbida: segue lo sfondamento, poi satura
            squash = c / height
            if hitTop >= hitBottom {
                top = wallTop
                bottom = wallTop + height - c
            } else {
                bottom = wallBottom
                top = wallBottom - (height - c)
            }
        }

        let grow = width * squash * Self.bulge          // più si schiaccia, più si allarga
        var left = minX - grow / 2
        var right = minX + width + grow / 2
        left = max(left, wallLeft)                      // muri laterali: l'allargamento si ferma qui
        right = min(right, wallRight)

        return ProjectionTransform(
            CGAffineTransform(a: (right - left) / size.width, b: 0,
                              c: 0, d: (bottom - top) / size.height,
                              tx: left, ty: top))
    }
}

/// La bolla: a riposo una capsula chiara (come la lente di GlassSegmented), premuta diventa vetro vero.
/// Le due versioni esistono sempre e cambiano solo opacità, così si muovono insieme (niente "doppione").
private struct PickerLens: View {
    let pressed: Bool

    var body: some View {
        ZStack {
            // A riposo
            Capsule()
                .fill(Color.white.opacity(0.14))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                .opacity(pressed ? 0 : 1)

            // Premuta: sempre presente, cambia solo opacità e scala
            glass
                .opacity(pressed ? 1 : 0)
                .scaleEffect(pressed ? 1 : 0.92)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var glassBase: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Color.clear
                .glassEffect(.clear.tint(Color.white.opacity(0.12)), in: Capsule())
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Color.white.opacity(0.14)))
        }
    }

    private var glass: some View {
        glassBase
            .overlay(Capsule().fill(LinearGradient(
                colors: [Color.white.opacity(0.16), Color.clear, Color.white.opacity(0.05)],
                startPoint: .top, endPoint: .bottom)))
            .overlay(Capsule().strokeBorder(LinearGradient(
                colors: [Color.white.opacity(0.80), Color.white.opacity(0.10), Color.white.opacity(0.45)],
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2))
            .shadow(color: Color.black.opacity(0.40), radius: 12, y: 4)
    }
}

/// Una riga del banner: miniatura, nome, dettaglio. Non è un Button: la selezione la gestisce il gesto
/// del pannello, così la bolla può scorrere. La riga si limita a dire dove si trova.
private struct PickerRow: View {
    let rowKey: String
    let space: String
    let weapon: Weapon?
    let title: String
    let subtitle: String
    var cartridge: CartridgeStyle? = nil     // se c'è, è la riga del solo calibro: si disegna la cartuccia
    var toggleID: String? = nil      // se c'è, è un calibro con armi: a destra compare la bolla piccola
    var absorbed = false             // true = armi assorbite (bolla piccola)
    var togglePressed = false        // la bolla è premuta in questo momento
    var faded = false                // la riga non si vede per intero nel banner: sfuma via

    /// true per la riga del solo calibro (nessuna arma, con la cartuccia).
    private var isCaliberRow: Bool {
        weapon == nil && cartridge != nil
    }

    /// A sinistra: foto dell'arma, oppure cartuccia orizzontale (solo calibro).
    @ViewBuilder
    private var iconView: some View {
        if weapon != nil {
            WeaponThumb(weapon: weapon, size: 34)
        } else if let cartridge {
            // Lunga 34 pt come la miniatura rotonda, così i testi restano allineati a quelli delle armi.
            CartridgeIcon(style: cartridge, height: 34, horizontal: true)
                .foregroundStyle(Palette.muted)
                .frame(width: 34, height: 26)
        }
    }

    /// Solo calibro: nome e «Senza arma» sulla stessa riga. Altre righe: nome sopra, dettaglio sotto.
    @ViewBuilder
    private var textView: some View {
        if isCaliberRow {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
        }
    }
    /// Bolla piccola di vetro: 22 pt con le armi visibili, 14 pt con le armi assorbite.
    /// Cambia il diametro vero e non una scala, così il vetro resta nitido. L'area misurata per il clic
    /// è sempre quella da 22 pt: la bolla rimpicciolita si preme comunque facilmente.
    /// Il clic lo gestisce il pannello.
    @ViewBuilder
    private var absorbBubble: some View {
        if let toggleID {
            let d = AbsorbBubble.size
                * (absorbed ? AbsorbBubble.smallScale : 1)
                * (togglePressed ? 0.9 : 1)
            AbsorbGlass()
                .frame(width: d, height: d)
                .frame(width: AbsorbBubble.size, height: AbsorbBubble.size)
                .animation(.spring(response: 0.42, dampingFraction: 0.82), value: absorbed)
                .animation(.easeOut(duration: 0.12), value: togglePressed)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: ToggleFramesKey.self,
                                               value: [toggleID: geo.frame(in: .named(space))])
                    }
                )
                .padding(.trailing, AbsorbBubble.edge)
                .allowsHitTesting(false)
        }
    }
    var body: some View {
        HStack(spacing: 10) {
            iconView
            textView
            Spacer(minLength: toggleID == nil ? 8 : AbsorbBubble.slot)    // lascia posto alla bolla piccola
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: RowFramesKey.self,
                                       value: [rowKey: geo.frame(in: .named(space))])
            }
        )
        .overlay(alignment: .trailing) { absorbBubble }
        .opacity(faded ? 0 : 1)
        .animation(.easeOut(duration: 0.15), value: faded)
        .id(rowKey)
    }
}
