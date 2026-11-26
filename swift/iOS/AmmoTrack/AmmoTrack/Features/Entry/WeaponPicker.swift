//
//  WeaponPicker.swift
//
//  Tasto di vetro con l'arma scelta (il calibro è quello dell'arma). Toccandolo si apre un banner di vetro
//  con le armi preimpostate, raggruppate per calibro. Si sceglie con un tocco e SI SCORRE COL DITO
//  (il banner è alto quanto servono le righe, ma mai più dello spazio che c'è sotto il tasto).
//  Le armi si aggiungono dalla pagina Armi.
//
//  Se un calibro non ha ancora armi compare la voce "Senza arma": serve anche per le entrate
//  (acquisti e ricariche non hanno un'arma) e per lo storico importato.
//
//  FLUIDITÀ: nessun gesto di trascinamento sulle righe (bloccava lo scorrimento e costringeva a ricalcolare
//  le posizioni di continuo), nessun vetro dentro al banner oltre al banner stesso, cartucce e Beretta come
//  immagini già disegnate (IconCache.swift). Il banner si apre con una dissolvenza; la trasformazione del
//  vetro (tasto → banner) è disattivata di proposito: vedi `weaponPickerMorphs` in AppearanceSettings.swift.
//

import SwiftUI

struct WeaponPicker: View {
    @EnvironmentObject var store: DataStore

    @Binding var target: EntryTarget
    @Binding var isOpen: Bool
    var maxPanelHeight: CGFloat = 360     // la decide EntryView: dal tasto fino al fondo della pagina

    @Namespace private var ns

    /// Altezza delle righe (misurata); finché non c'è si usa una stima.
    @State private var rowsHeight: CGFloat = 0
    /// Calibri con le armi nascoste (id separati da virgola). Si ricorda anche fra un avvio e l'altro.
    @AppStorage("picker.collapsedCalibers") private var collapsedRaw = ""

    private let compactHeight: CGFloat = 44             // altezza del tasto quando c'è solo il calibro
    private let compactCartridgeLength: CGFloat = 64    // lunghezza della cartuccia orizzontale (in punti)
    private let panelWidth: CGFloat = 300
    private static let openAnimation = Animation.smooth(duration: 0.32)
    private static let closeAnimation = Animation.smooth(duration: 0.28)
    /// Separatore fra calibro e matricola.
    private static let separator = "  •  "

    var body: some View {
        if weaponPickerMorphs {
            morphing
        } else {
            fading
        }
    }

    // MARK: Le due versioni

    /// Il tasto e il banner sono lo stesso pezzo di vetro, che si trasforma (weaponPickerMorphs = true).
    private var morphing: some View {
        GlassEffectContainer(spacing: 12) {
            if isOpen {
                panel
                    .liquidGlass(cornerRadius: 26)
                    .glassMorphID("weaponPicker", in: ns)
            } else {
                pickerButton
                    .glassCapsule()
                    .glassMorphID("weaponPicker", in: ns)
            }
        }
    }

    /// Il tasto resta dov'è e sfuma; il banner compare sotto con una dissolvenza (la versione che non scatta).
    private var fading: some View {
        ZStack(alignment: .top) {
            pickerButton
                .glassCapsule()
                .opacity(isOpen ? 0 : 1)
                .allowsHitTesting(!isOpen)
            if isOpen {
                panel
                    .liquidGlass(cornerRadius: 26)
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
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

    private func openPicker() {
        withAnimation(Self.openAnimation) { isOpen = true }
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
            CartridgeImage(style: cartridgeStyle, height: compactCartridgeLength, horizontal: true)
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

    /// Stima dell'altezza delle righe, usata finché non c'è la misura vera.
    private var estimatedRowsHeight: CGFloat {
        let calibers = store.config.calibers
        let rowCount = calibers.reduce(0) { $0 + store.config.activeWeapons(for: $1.id).count + 1 }
        return CGFloat(rowCount) * 50 + CGFloat(calibers.count) * 24 + 28
    }

    private var naturalHeight: CGFloat { rowsHeight > 0 ? rowsHeight : estimatedRowsHeight }
    private var panelHeight: CGFloat { min(naturalHeight, max(maxPanelHeight, 160)) }
    /// true = le righe non entrano: il banner scorre.
    private var scrolls: Bool { naturalHeight > panelHeight + 1 }

    /// Il banner: righe che scorrono col dito, sfumate ai bordi quando c'è altro sopra o sotto.
    private var panel: some View {
        ScrollView {
            rows
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowsHeight = $0 }
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: panelWidth, height: panelHeight)
        .mask { fadeMask }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    /// Opaca al centro, trasparente ai bordi (solo se il banner scorre).
    private var fadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color.clear, Color.black], startPoint: .top, endPoint: .bottom)
                .frame(height: scrolls ? 14 : 0)
            Rectangle().fill(Color.black)
            LinearGradient(colors: [Color.black, Color.clear], startPoint: .top, endPoint: .bottom)
                .frame(height: scrolls ? 14 : 0)
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(store.config.calibers) { cal in
                caliberSection(cal)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func caliberSection(_ cal: Caliber) -> some View {
        let all = store.config.activeWeapons(for: cal.id)
        let isAbsorbed = absorbed.contains(cal.id)
        let shown = isAbsorbed ? all.filter { $0.id == target.weaponID } : all
        let hidden = all.count - shown.count
        let balance = store.ledger.balance(for: cal.id)

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

        ZStack(alignment: .trailing) {
            row(EntryTarget(caliberID: cal.id, weaponID: nil),
                weapon: nil,
                title: cal.displayName,
                subtitle: "Senza arma",
                cartridge: cal.cartridgeStyle,
                reserveForBubble: !all.isEmpty)
            if !all.isEmpty {
                absorbBubble(cal.id, absorbed: isAbsorbed)
            }
        }

        ForEach(shown) { w in
            row(EntryTarget(caliberID: cal.id, weaponID: w.id),
                weapon: w,
                title: w.name,
                subtitle: w.serial.isEmpty ? cal.name : "\(cal.name)\(Self.separator)\(w.serial)",
                cartridge: nil,
                reserveForBubble: false)
                .transition(.opacity)
        }
    }

    /// Una riga: miniatura, nome, dettaglio. Si sceglie con un tocco; quella scelta ha la capsula chiara.
    private func row(_ t: EntryTarget, weapon: Weapon?, title: String, subtitle: String,
                     cartridge: CartridgeStyle?, reserveForBubble: Bool) -> some View {
        let selected = t == target
        let caliberRow = weapon == nil && cartridge != nil
        return Button {
            choose(t)
        } label: {
            HStack(spacing: 10) {
                rowIcon(weapon: weapon, cartridge: cartridge)
                rowText(title: title, subtitle: subtitle, singleLine: caliberRow)
                Spacer(minLength: reserveForBubble ? 40 : 8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minHeight: 48)
            .background(
                Capsule()
                    .fill(Color.white.opacity(selected ? 0.14 : 0))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(selected ? 0.18 : 0), lineWidth: 1))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(RowPressStyle())
        .animation(.easeOut(duration: 0.18), value: selected)
    }

    /// A sinistra: foto o logo dell'arma, oppure cartuccia orizzontale (solo calibro).
    @ViewBuilder
    private func rowIcon(weapon: Weapon?, cartridge: CartridgeStyle?) -> some View {
        if weapon != nil {
            WeaponThumb(weapon: weapon, size: 34)
        } else if let cartridge {
            CartridgeImage(style: cartridge, height: 34, horizontal: true)
                .frame(width: 34, height: 26)
        }
    }

    /// Solo calibro: il nome su una riga. Altre righe: nome sopra, dettaglio sotto.
    @ViewBuilder
    private func rowText(title: String, subtitle: String, singleLine: Bool) -> some View {
        if singleLine {
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

    // MARK: Armi nascoste (bolla piccola dei calibri)

    private var absorbed: Set<String> {
        Set(collapsedRaw.split(separator: ",").map(String.init))
    }

    private func toggleAbsorbed(_ id: String) {
        var set = absorbed
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
        withAnimation(.smooth(duration: 0.25)) {
            collapsedRaw = set.sorted().joined(separator: ",")
        }
    }

    /// Bolla piccola a destra dei calibri che hanno armi: tocco = nasconde o mostra le armi del calibro.
    private func absorbBubble(_ id: String, absorbed: Bool) -> some View {
        let d: CGFloat = absorbed ? 14 : 22
        return Button {
            toggleAbsorbed(id)
        } label: {
            AbsorbGlass()
                .frame(width: d, height: d)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 4)
        .animation(.smooth(duration: 0.25), value: absorbed)
        .accessibilityLabel(absorbed ? "Mostra le armi" : "Nascondi le armi")
    }

    // MARK: Scelta

    /// Sceglie una voce: la capsula si sposta, poi il banner si richiude.
    private func choose(_ t: EntryTarget) {
        let changed = t != target
        if changed {
            withAnimation(.smooth(duration: 0.2)) { target = t }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (changed ? 0.2 : 0)) {
            withAnimation(Self.closeAnimation) { isOpen = false }
        }
    }
}

// MARK: - Supporto

/// Una riga premuta si attenua: così si capisce che il tocco è arrivato.
private struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

/// La bolla piccola: un cerchio semplice, chiaro, col bordo. Niente vetro in più dentro al banner (che è già vetro).
private struct AbsorbGlass: View {
    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.14))
            .overlay(Circle().fill(LinearGradient(
                colors: [Color.white.opacity(0.22), Color.clear, Color.white.opacity(0.06)],
                startPoint: .top, endPoint: .bottom)))
            .overlay(Circle().strokeBorder(LinearGradient(
                colors: [Color.white.opacity(0.80), Color.white.opacity(0.10), Color.white.opacity(0.45)],
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.30), radius: 3, y: 1)
    }
}
