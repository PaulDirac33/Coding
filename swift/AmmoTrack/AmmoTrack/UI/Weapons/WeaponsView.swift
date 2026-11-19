//
//  WeaponsView.swift
//
//  Pagina "Armi": una scheda di vetro per arma con la foto (anteprima), il nome, la matricola, il calibro
//  e quanto ha sparato. Un clic in un punto qualsiasi della scheda apre la modifica (foto compresa);
//  si può anche trascinare un file immagine sulla scheda per cambiare la foto.
//  Le armi archiviate escono dal selettore dell'Inserimento ma conservano lo storico.
//

import SwiftUI
import UniformTypeIdentifiers

/// Legge un file immagine scelto dall'utente e lo restituisce come JPEG ridimensionato.
nonisolated enum ImagePicking {
    static func jpeg(from url: URL) -> Data? {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return ImageTools.jpegData(from: data, maxPixel: 1200)
    }
    /// Come `jpeg`, ma PNG: serve ai loghi, per non perdere lo sfondo trasparente.
    static func png(from url: URL) -> Data? {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return ImageTools.pngData(from: data, maxPixel: 512)
    }
}

struct WeaponEditorTarget: Identifiable {
    let id = UUID()
    let weapon: Weapon?
}

struct WeaponsView: View {
    @EnvironmentObject var store: DataStore

    @State private var editing: WeaponEditorTarget? = nil
    @State private var showArchived = false
    @State private var actionError: String? = nil
    /// Posizione della scheda cliccata (spazio "weaponsPage"): da lì nasce il foglio. nil = dal centro.
    @State private var editorOrigin: CGRect? = nil

    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 18)]

    private var activeWeapons: [Weapon] {
        store.config.weapons.filter { !$0.isArchived }
    }

    private var archivedWeapons: [Weapon] {
        store.config.weapons.filter { $0.isArchived }
    }

    private var visibleWeapons: [Weapon] {
        showArchived ? activeWeapons + archivedWeapons : activeWeapons
    }

    /// Colpi, uscite e ultimo utilizzo per arma (su tutto il registro).
    private var totals: [String: WeaponTotal] {
        var map: [String: WeaponTotal] = [:]
        let all = Stats.byWeapon(movements: store.movements, config: store.config,
                                 caliberID: nil, since: nil, includeEmpty: true)
        for t in all {
            if let id = t.weaponID { map[id] = t }
        }
        return map
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
                .zIndex(10)
            ErrorLine(text: actionError)
            if store.config.weapons.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .coordinateSpace(.named("weaponsPage"))
        .overlay { editorOverlay }
    }
    // MARK: Foglio di modifica (nasce dalla scheda)

    private static let editorSpring = Animation.spring(response: 0.5, dampingFraction: 0.86)

    private func openEditor(_ weapon: Weapon?, from frame: CGRect?) {
        editorOrigin = frame
        withAnimation(Self.editorSpring) { editing = WeaponEditorTarget(weapon: weapon) }
    }

    private func closeEditor() {
        withAnimation(Self.editorSpring) { editing = nil }
    }

    /// Parte piccolo sopra la scheda cliccata e si ingrandisce fino al centro della pagina.
    private func growTransition(in size: CGSize) -> AnyTransition {
        var scale: CGFloat = 0.92
        var offset = CGSize.zero
        if let f = editorOrigin {
            scale = min(f.width / 480, 1)                       // 480 = larghezza di WeaponEditor
            offset = CGSize(width: f.midX - size.width / 2, height: f.midY - size.height / 2)
        }
        return .modifier(active: GrowFromCard(scale: scale, offset: offset, opacity: 0),
                         identity: GrowFromCard(scale: 1, offset: .zero, opacity: 1))
    }

    private var editorOverlay: some View {
        GeometryReader { geo in
            ZStack {
                if let target = editing {
                    Color.black.opacity(0.35)
                        .transition(.opacity)
                    WeaponEditor(original: target.weapon, onClose: closeEditor)
                        .id(target.id)
                        .frame(maxHeight: max(300, geo.size.height - 32))
                        .liquidGlass(cornerRadius: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .shadow(color: Color.black.opacity(0.45), radius: 30, y: 12)
                        .transition(growTransition(in: geo.size))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(editing != nil)
    }

    // MARK: Intestazione

    private var header: some View {
        HStack(spacing: 14) {
            Text("Armi")
                .font(.title2.weight(.semibold))
            Text("\(activeWeapons.count) in uso")
                .font(.callout)
                .foregroundStyle(Palette.muted)
            Spacer()
            if !archivedWeapons.isEmpty {
                Toggle("Mostra archiviate (\(archivedWeapons.count))", isOn: $showArchived)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }
            Button {
                openEditor(nil, from: nil)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .glassProminentButton()
            .buttonBorderShape(.capsule)
            .glassHint("Nuova arma", placement: .belowTrailing)
        }
        .frame(height: 40)
    }

    private var grid: some View {
        let stats = totals
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(visibleWeapons) { w in
                    WeaponCard(weapon: w,
                               totals: stats[w.id],
                               onEdit: { openEditor(w, from: $0) },
                               onError: { actionError = $0 })
                }
            }
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nessuna arma", systemImage: "scope")
        } description: {
            Text("Aggiungi le tue armi con il calibro, la matricola e una foto.\nPotrai sceglierle dal tasto dell'arma nella pagina Inserimento.")
        } actions: {
            Button("Aggiungi un'arma") {
                openEditor(nil, from: nil)
            }
            .glassProminentButton()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
private struct GrowFromCard: ViewModifier {
    let scale: CGFloat
    let offset: CGSize
    let opacity: Double

    func body(content: Content) -> some View {
        content.scaleEffect(scale).offset(offset).opacity(opacity)
    }
}
// MARK: - Scheda

struct WeaponCard: View {
    @EnvironmentObject var store: DataStore

    let weapon: Weapon
    let totals: WeaponTotal?
    let onEdit: (CGRect) -> Void
    let onError: (String?) -> Void

    @State private var dropTargeted = false
    @State private var cardFrame: CGRect = .zero

    private var shots: Int { totals?.shots ?? 0 }
    private var sessions: Int { totals?.sessions ?? 0 }

    private var statsText: String {
        if shots == 0 { return "Mai usata" }
        return "\(numText(shots)) colpi · \(sessions) \(sessions == 1 ? "uscita" : "uscite")"
    }

    /// Seconda riga delle statistiche: "Archiviata" (se lo è) e l'ultimo uso.
    private var detailText: String {
        var parts: [String] = []
        if weapon.isArchived { parts.append("Archiviata") }
        if let d = totals?.lastDate { parts.append("Ultimo uso: \(dayText(d))") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            picture
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(weapon.name.isEmpty ? "Senza nome" : weapon.name)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(store.config.caliberName(weapon.caliberID))
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(weapon.qualification.map { "Qualifica \($0.label.lowercased())" } ?? "Qualifica non indicata")
                    .font(.system(size: 13))
                    .foregroundStyle(weapon.qualification == nil ? Palette.muted : Color.white.opacity(0.85))
                    .lineLimit(1)
                Text(weapon.serial.isEmpty ? "Matricola non indicata" : "Matricola \(weapon.serial)")
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(weapon.serial.isEmpty ? Palette.muted : Color.white.opacity(0.85))
                    .lineLimit(1)
            }

            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(statsText)
                    .font(.system(size: 14, weight: .semibold))
                Text(detailText.isEmpty ? " " : detailText)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(14)
        .liquidGlass(cornerRadius: 22)
        .opacity(weapon.isArchived ? 0.6 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("weaponsPage")) } action: { cardFrame = $0 }
        .onTapGesture { onEdit(cardFrame) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Apre la modifica dell'arma")
        .contextMenu {
            Button("Modifica…") { onEdit(cardFrame) }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: { $0.isFileURL }) else { return false }
            attach(url)
            return true
        } isTargeted: { targeted in
            dropTargeted = targeted
        }
    }

    /// La foto, in proporzione 16:10. Il clic è della scheda intera; si può trascinare un file sulla scheda.
    private var picture: some View {
        Color.clear
            .aspectRatio(16.0 / 10.0, contentMode: .fit)
            .overlay {
                WeaponImage(weapon: weapon, maxPixel: 900)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Palette.avg, lineWidth: 2)
                    .opacity(dropTargeted ? 1 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .animation(.easeOut(duration: 0.15), value: dropTargeted)
    }

    private func attach(_ url: URL) {
        guard let jpeg = ImagePicking.jpeg(from: url) else {
            onError("Non riesco a leggere quell'immagine.")
            return
        }
        onError(store.saveWeapon(weapon, newImage: jpeg, removeImage: false))
    }
}
