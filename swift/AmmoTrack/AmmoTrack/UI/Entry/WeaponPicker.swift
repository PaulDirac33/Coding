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

struct WeaponPicker: View {
    @EnvironmentObject var store: DataStore

    @Binding var target: EntryTarget
    @Binding var isOpen: Bool
    var maxPanelHeight: CGFloat = 360     // la decide EntryView: dal tasto fino al fondo della pagina

    @Namespace private var ns

    private let buttonWidth: CGFloat = 320
    private let panelWidth: CGFloat = 340
    private let compactHeight: CGFloat = 44             // altezza del tasto quando c'è solo il calibro
    private let compactCartridgeLength: CGFloat = 64    // lunghezza della cartuccia orizzontale (in punti)

    /// Spazio di coordinate in cui le righe dicono dove stanno (serve alla bolla).
    private let rowsSpace = "pickerRows"

    /// Chiusura del banner dopo la scelta di una voce: più lenta dell'apertura (che resta 0,42 / 0,82).
    private static var closeAnimation: Animation {
        .spring(response: 0.5, dampingFraction: 0.88)
    }
    /// Separatore fra calibro e matricola. Il trattino «–» (en dash) è un unico segno, come il "--" di LaTeX.
    /// Alternative: " • " oppure " - ".
    private static let separator = "  •  "

    /// Posizione di ogni riga, raccolta dalle righe stesse.
    @State private var rowFrames: [String: CGRect] = [:]
    /// Altezza che le righe avrebbero senza scorrimento (misurata quando il banner è aperto).
    @State private var rowsHeight: CGFloat = 0

    /// Altezza del puntatore mentre premi o trascini (nil = a riposo).
    /// Si azzera con una molla poco smorzata: è il rimbalzo, come in GlassSegmented.
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.50, dampingFraction: 0.48)))
    private var drag: CGFloat? = nil

    private static var morphs: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }

    var body: some View {
        if WeaponPicker.morphs {
            morphing
        } else {
            classic
        }
    }

    // MARK: Le due versioni

    /// macOS 26: il tasto e il banner sono lo stesso pezzo di vetro, che si trasforma.
    private var morphing: some View {
        GlassContainer(spacing: 12) {
            if isOpen {
                panel
                    .liquidGlass(cornerRadius: 26)
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
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { isOpen = true }
        } label: {
            if isCaliberOnly {
                compactLabel
            } else {
                fullLabel
            }
        }
        .buttonStyle(.plain)
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

    private var panel: some View {
        // Spazio per le righe: altezza massima del banner meno i 10 pt di margine sopra e sotto.
        let room = max(120, maxPanelHeight - 20)
        // Altezza naturale delle righe: misurata; la prima volta, una stima.
        let natural = rowsHeight > 0
            ? rowsHeight
            : CGFloat(rowCount) * 46 + CGFloat(store.config.calibers.count) * 24
        return Group {
            if natural > room {
                ScrollView { rows }
                    .scrollIndicators(.hidden)
                    .frame(height: room)
            } else {
                rows
            }
        }
        .padding(10)
        .frame(width: panelWidth)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(store.config.calibers) { cal in
                caliberSection(cal)
            }
        }
        .coordinateSpace(.named(rowsSpace))
        .onPreferenceChange(RowFramesKey.self) { rowFrames = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowsHeight = $0 }
        .background(alignment: .topLeading) { lens }
        .contentShape(Rectangle())
        .gesture(pickGesture)
    }

    @ViewBuilder
    private func caliberSection(_ cal: Caliber) -> some View {
        let weapons = store.config.activeWeapons(for: cal.id)
        let balance = store.ledger.balance(for: cal.id)

        HStack {
            Text(cal.name.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.muted)
            Spacer()
            Text("\(numText(balance.total)) cartucce")
                .font(.caption2)
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)

        PickerRow(rowKey: key(EntryTarget(caliberID: cal.id, weaponID: nil)),
                  space: rowsSpace,
                  weapon: nil,
                  title: cal.displayName,
                  subtitle: "Senza arma",
                  cartridge: cal.cartridgeStyle)
        ForEach(weapons) { w in
            PickerRow(rowKey: key(EntryTarget(caliberID: cal.id, weaponID: w.id)),
                      space: rowsSpace,
                      weapon: w,
                      title: w.name,
                      subtitle: w.serial.isEmpty ? cal.name : "\(cal.name)\(Self.separator)\(w.serial)")
        }
    }

    // MARK: Bolla e selezione

    private func key(_ t: EntryTarget) -> String {
        "\(t.caliberID)|\(t.weaponID ?? "")"
    }

    private var selectedKey: String { key(target) }

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
                // Al primo tocco la bolla raggiunge il punto con una molla, poi segue senza ritardo.
                transaction.animation = (state == nil)
                    ? Animation.spring(response: 0.30, dampingFraction: 0.62)
                    : nil
                state = g.location.y
            }
            .onEnded { g in finish(at: g.location) }
    }

    private func finish(at point: CGPoint) {
        guard let hit = rowFrames.first(where: { $0.value.insetBy(dx: 0, dy: -1).contains(point) })?.key,
              let t = targets[hit] else { return }      // rilasciato fuori dalle righe: non succede nulla

        let changed = t != target
        if changed {
            // La bolla rimbalza fino alla nuova riga...
            withAnimation(.spring(response: 0.50, dampingFraction: 0.55)) { target = t }
        }
        // ...e il banner si richiude dopo, più lentamente, così il movimento si vede.
        DispatchQueue.main.asyncAfter(deadline: .now() + (changed ? 0.30 : 0)) {
            withAnimation(Self.closeAnimation) { isOpen = false }
        }
    }

    /// Dove sta la bolla: sulla riga scelta; mentre premi, sul puntatore (con l'altezza che si adatta alle righe).
    private func lensRect() -> CGRect? {
        guard let full = rowFrames[selectedKey] else { return nil }
        let rest = full.insetBy(dx: lensInset, dy: 0)
        guard let y = drag else { return rest }

        let ordered = rowFrames.values.sorted { $0.midY < $1.midY }
        guard let first = ordered.first, let last = ordered.last else { return rest }
        let cy = min(max(y, first.midY), last.midY)

        var h = last.height
        if cy <= first.midY {
            h = first.height
        } else {
            for i in 1..<ordered.count where cy <= ordered[i].midY {
                let a = ordered[i - 1]
                let b = ordered[i]
                let t = (cy - a.midY) / (b.midY - a.midY)
                h = a.height + (b.height - a.height) * t
                break
            }
        }
        let height = h + 6                                  // premuta, si ingrandisce un po'
        return CGRect(x: rest.minX - 4, y: cy - height / 2, width: rest.width + 8, height: height)
    }

    /// I muri della bolla: bordo alto della prima riga e basso dell'ultima, con 2 pt di respiro (come in GlassSegmented).
    /// Quanto la bolla può uscire ai lati dai bordi delle righe. Il pannello ha 10 pt di margine:
    /// sotto 10 la bolla resta dentro il banner, sopra sporge. Alza o abbassa a gusto.
    private let sideRoom: CGFloat = 5
    /// Quanto stringere la bolla per lato rispetto alla riga (0 = larga come la riga).
    private let lensInset: CGFloat = 3

    /// I muri della bolla: in alto e in basso i bordi della prima e dell'ultima riga (+2 pt di respiro),
    /// ai lati i bordi delle righe più `sideRoom`.
    private var wallRange: (top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat)? {
        guard let top = rowFrames.values.map({ $0.minY }).min(),
              let bottom = rowFrames.values.map({ $0.maxY }).max(),
              let left = rowFrames.values.map({ $0.minX }).min(),
              let right = rowFrames.values.map({ $0.maxX }).max() else { return nil }
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
        if #available(macOS 26.0, *) {
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
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
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

    var body: some View {
        HStack(spacing: 10) {
            iconView
            textView
            Spacer(minLength: 8)
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
    }
}
