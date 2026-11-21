//
//  DataView+Glass.swift
//
//  I due pannelli di vetro della pagina Dati:
//  - l'editor del movimento (come l'editor delle armi: sfondo scuro, vetro, ombra, comparsa a molla);
//  - il menù del filtro armi, che si apre sotto il pulsante (clic fuori o Esc lo chiudono).
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

extension DataView {

    // MARK: Editor del movimento

    var editorOverlay: some View {
        GeometryReader { geo in
            ZStack {
                if let target = editing {
                    Color.black.opacity(0.35)
                        .transition(.opacity)
                    MovementEditor(original: target.movement, onClose: { editing = nil })
                        .id(target.id)
                        .frame(maxHeight: max(300, geo.size.height - 32))
                        .liquidGlass(cornerRadius: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .shadow(color: Color.black.opacity(0.45), radius: 30, y: 12)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(Self.slide, value: editing?.id)
        }
        .allowsHitTesting(editing != nil)
    }

    // MARK: Menù del filtro armi

    // MARK: Larghezza del menù

    /// Testo mostrato da una voce del menù (stesso testo di GlassMenuRow).
    private func weaponMenuTitle(_ w: Weapon) -> String {
        w.isArchived ? "\(w.name) (archiviata)" : w.name
    }

    /// Larghezza del testo nel font delle voci (13 pt semibold: il caso più largo).
    private func menuTextWidth(_ text: String) -> CGFloat {
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
        #else
        return CGFloat(text.count) * 7.5      // stima, per un eventuale iOS
        #endif
    }

    /// Voce più lunga + margine della voce (14 + 14) + margine del pannello (8 + 8) + un po' di respiro.
    private var weaponPanelWidth: CGFloat {
        let titles = ["Tutte le armi"] + store.config.weapons.map { weaponMenuTitle($0) }
        let longest = titles.map { menuTextWidth($0) }.max() ?? 0
        let breathing: CGFloat = 4                  // "poco più": alza o abbassa a gusto
        return min(max(longest + 28 + 16 + breathing, 150), 320)
    }

    var weaponMenuOverlay: some View {
        GeometryReader { geo in
            // Il pannello parte dal bordo sinistro del pulsante, ma non esce dalla finestra.
            let x = max(8, min(weaponButtonFrame.minX, geo.size.width - weaponPanelWidth - 16))
            ZStack(alignment: .topLeading) {
                if showWeaponMenu {
                    // Clic fuori dal pannello: chiude.
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { closeWeaponMenu() }
                    // Esc chiude.
                    Button("") { closeWeaponMenu() }
                        .keyboardShortcut(.cancelAction)
                        .opacity(0)
                        .frame(width: 0, height: 0)
                        .accessibilityHidden(true)
                }
                weaponPanel
                    .scaleEffect(showWeaponMenu ? 1 : 0.92, anchor: .topLeading)
                    .opacity(showWeaponMenu ? 1 : 0)
                    .offset(x: x, y: weaponButtonFrame.maxY + 8)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .animation(Self.slide, value: showWeaponMenu)
        }
        .allowsHitTesting(showWeaponMenu)
    }

    private var weaponPanel: some View {
        let weapons = store.config.weapons
        let hasDivider = !weapons.isEmpty
        // Altezza naturale delle voci (34 pt l'una, 2 pt fra loro, 8 pt di margine sopra e sotto):
        // oltre i 360 pt il menù scorre.
        let children = weapons.count + 1 + (hasDivider ? 1 : 0)
        let natural = CGFloat(weapons.count + 1) * 34 + (hasDivider ? 9 : 0) + CGFloat(children - 1) * 2 + 16

        return ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                GlassMenuRow(title: "Tutte le armi", selected: weaponFilter == nil) {
                    chooseWeapon(nil)
                }
                if hasDivider {
                    Rectangle()
                        .fill(Palette.line)
                        .frame(height: 1)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                }
                ForEach(weapons) { w in
                    GlassMenuRow(title: weaponMenuTitle(w),
                                 selected: weaponFilter == w.id) {
                        chooseWeapon(w.id)
                    }
                }
            }
            .padding(8)
        }
        .scrollIndicators(.never)
        .frame(width: weaponPanelWidth, height: min(natural, 360))
        .liquidGlass(cornerRadius: 22)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.45), radius: 24, y: 10)
    }

    private func chooseWeapon(_ id: String?) {
        withAnimation(Self.slide) {
            weaponFilter = id
            showWeaponMenu = false
        }
    }

    private func closeWeaponMenu() {
        withAnimation(Self.slide) { showWeaponMenu = false }
    }
}

// MARK: - Voce del menù di vetro

/// Una voce: a riposo trasparente, al passaggio del mouse si illumina; quella scelta ha la capsula chiara
/// del selettore (la stessa "lente" a riposo di GlassSegmented e del banner armi).
private struct GlassMenuRow: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: selected ? .semibold : .medium))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(
                Capsule()
                    .fill(Color.white.opacity(selected ? 0.14 : (hovering ? 0.08 : 0)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(selected ? 0.18 : 0), lineWidth: 1))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}
