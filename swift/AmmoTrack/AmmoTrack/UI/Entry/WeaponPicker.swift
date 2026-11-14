//
//  WeaponPicker.swift
//
//  Tasto di vetro con l'arma scelta (il calibro è quello dell'arma). Cliccandolo si apre un banner di vetro
//  con le armi preimpostate, raggruppate per calibro: su macOS 26 il tasto si trasforma nel banner
//  (GlassEffectContainer + glassEffectID); sui sistemi precedenti è un popover.
//
//  Se un calibro non ha ancora armi compare la voce "Senza arma": serve anche per le entrate
//  (acquisti e ricariche non hanno un'arma) e per lo storico importato.
//

import SwiftUI

struct WeaponPicker: View {
    @EnvironmentObject var store: DataStore

    @Binding var target: EntryTarget
    @Binding var isOpen: Bool
    let onManage: () -> Void

    @Namespace private var ns

    private let buttonWidth: CGFloat = 320
    private let panelWidth: CGFloat = 340

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
        if !w.serial.isEmpty { parts.append("matr. \(w.serial)") }
        return parts.joined(separator: " · ")
    }

    private var pickerButton: some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { isOpen = true }
        } label: {
            HStack(spacing: 10) {
                WeaponThumb(weapon: currentWeapon, caliberID: target.caliberID, size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(titleText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 14)
            .frame(width: buttonWidth, height: 52)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Banner

    private var rowCount: Int {
        store.config.calibers.reduce(0) { total, cal in
            total + store.config.activeWeapons(for: cal.id).count + 1   // +1 = "Senza arma"
        }
    }

    private var panel: some View {
        Group {
            if rowCount > 7 {
                ScrollView { rows }
                    .frame(height: 360)
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
            Divider()
                .overlay(Palette.line)
                .padding(.vertical, 4)
            PickerRow(weapon: nil,
                      symbol: "slider.horizontal.3",
                      title: "Gestisci armi…",
                      subtitle: "Aggiungi, modifica, foto e matricole",
                      selected: false) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { isOpen = false }
                onManage()
            }
        }
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

        PickerRow(weapon: nil,
                  symbol: "scope",
                  title: cal.displayName,
                  subtitle: "Senza arma",
                  selected: target.caliberID == cal.id && target.weaponID == nil,
                  cartridge: cal.cartridgeStyle) {
            choose(EntryTarget(caliberID: cal.id, weaponID: nil))
        }
        ForEach(weapons) { w in
            PickerRow(weapon: w,
                      symbol: "scope",
                      title: w.name,
                      subtitle: w.serial.isEmpty ? cal.name : "\(cal.name) · matr. \(w.serial)",
                      selected: target.weaponID == w.id) {
                choose(EntryTarget(caliberID: cal.id, weaponID: w.id))
            }
        }
    }

    private func choose(_ t: EntryTarget) {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            target = t
            isOpen = false
        }
    }
}

/// Una riga del banner: miniatura, nome, dettaglio, segno di spunta se è quella scelta.
private struct PickerRow: View {
    let weapon: Weapon?
    let symbol: String
    let title: String
    let subtitle: String
    let selected: Bool
    var cartridge: CartridgeStyle? = nil     // se c'è, al posto del simbolo si disegna la cartuccia
    let action: () -> Void

    @State private var hovering = false

    private var highlight: Double {
        selected ? 0.12 : (hovering ? 0.07 : 0)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if weapon != nil {
                    WeaponThumb(weapon: weapon, size: 34)
                } else {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.10))
                        if let cartridge {
                            CartridgeIcon(style: cartridge, height: 22)
                                .foregroundStyle(Palette.muted)
                        } else {
                            Image(systemName: symbol)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                    .frame(width: 34, height: 34)
                }
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
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(highlight))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
