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

    static let ballSize: CGFloat = 64
    private let chipWidth: CGFloat = 240
    private let panelWidth: CGFloat = 340
    private let gap: CGFloat = 14

    private static var morphs: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }

    var body: some View {
        if WeaponPicker.morphs { morphing } else { classic }
    }

    // MARK: Le due versioni

    /// macOS 26: la pallina resta ferma; il banner (o la capsula dell'arma) è un altro pezzo di vetro
    /// che nasce da lei e si stacca, come le palline di Spotlight.
    private var morphing: some View {
        GlassContainer(spacing: gap) {
            HStack(alignment: .top, spacing: gap) {
                ball
                    .glassCapsule(interactive: true)
                    .glassMorphID("ball", in: ns)
                if isOpen {
                    panel
                        .liquidGlass(cornerRadius: 26)
                        .glassMorphID("banner", in: ns)
                } else if let w = currentWeapon {
                    weaponChip(w)
                        .glassCapsule(interactive: true)
                        .glassMorphID("banner", in: ns)   // capsula ⇄ banner: stesso id, si trasformano
                }
            }
        }
    }

    /// Sistemi precedenti: pallina in materiale traslucido e popover a destra.
    private var classic: some View {
        HStack(alignment: .top, spacing: gap) {
            ball
                .glassCapsule()
                .popover(isPresented: $isOpen, arrowEdge: .trailing) {
                    panel.padding(6)
                }
            if let w = currentWeapon {
                weaponChip(w).glassCapsule()
            }
        }
    }

    private func toggle() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.74)) { isOpen.toggle() }
    }

    // MARK: Pallina e capsula

    private var currentWeapon: Weapon? { store.config.weapon(target.weaponID) }

    private var caliberName: String {
        target.caliberID.isEmpty ? "—" : store.config.caliberName(target.caliberID)
    }

    /// Un quadrato con la capsula di vetro diventa un cerchio.
    private var ball: some View {
        Button(action: toggle) {
            VStack(spacing: 3) {
                CartridgeIcon(height: 22)
                Text(caliberName)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 6)
            .frame(width: Self.ballSize, height: Self.ballSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    /// Con un'arma scelta, accanto alla pallina resta una capsula con foto e nome (altrimenti non si vedrebbe cosa registri).
    private func weaponChip(_ w: Weapon) -> some View {
        Button(action: toggle) {
            HStack(spacing: 10) {
                WeaponThumb(weapon: w, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(w.name.isEmpty ? "Senza nome" : w.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                    Text(w.serial.isEmpty ? "Arma selezionata" : "matr. \(w.serial)")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 14)
            .frame(width: chipWidth, height: Self.ballSize)
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
                  title: "Senza arma",
                  subtitle: cal.name,
                  selected: target.caliberID == cal.id && target.weaponID == nil) {
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
                        Image(systemName: symbol)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.muted)
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
