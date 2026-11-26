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
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $editing) { target in
            WeaponEditor(original: target.weapon, onClose: { editing = nil })
                .id(target.id)
        }
    }
    // MARK: Foglio di modifica

    private func openEditor(_ weapon: Weapon?) {
        editing = WeaponEditorTarget(weapon: weapon)
    }

    // MARK: Intestazione

    private var titleText: some View {
        Text("Armi")
            .font(.title2.weight(.semibold))
    }

    private var countText: some View {
        Text("\(activeWeapons.count) in uso")
            .font(.callout)
            .foregroundStyle(Palette.muted)
    }

    private var archivedToggle: some View {
        Toggle("Mostra archiviate (\(archivedWeapons.count))", isOn: $showArchived)
            .toggleStyle(.switch)
            .controlSize(.small)
            .font(.caption)
            .foregroundStyle(Palette.muted)
    }

    /// «+»: verde militare (quello della mimetica, più chiaro dello sfondo), col segno chiaro: si vede.
    private var newWeaponButton: some View {
        Button {
            openEditor(nil)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 30, height: 26)
        }
        .glassProminentButton()
        .buttonBorderShape(.capsule)
        .accessibilityLabel("Nuova arma")
    }

    /// Tutto su una riga (iPad).
    private var wideHeader: some View {
        HStack(spacing: 14) {
            titleText
            countText
            Spacer()
            if !archivedWeapons.isEmpty {
                archivedToggle
                    .fixedSize()
            }
            newWeaponButton
        }
        .frame(height: 40)
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            wideHeader
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    titleText
                    countText
                    Spacer()
                    newWeaponButton
                }
                if !archivedWeapons.isEmpty {
                    archivedToggle
                }
            }
        }
    }

    /// Altezza della sfumatura ai bordi alto e basso (come lo spazio fra intestazione e schede).
    private let edgeFade: CGFloat = 16

    private var grid: some View {
        let stats = totals
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(visibleWeapons) { w in
                    WeaponCard(weapon: w,
                               totals: stats[w.id],
                               onEdit: { _ in openEditor(w) },
                               onError: { actionError = $0 })
                }
            }
            // A riposo la prima e l'ultima scheda stanno fuori dalla sfumatura.
            .padding(.top, edgeFade)
            .padding(.bottom, edgeFade + 8)
        }
        .scrollIndicators(.hidden)
        .mask { edgeFadeMask }
        // L'area che scorre si allarga di edgeFade sopra e sotto, così a riposo il layout non cambia.
        .padding(.top, -edgeFade)
        .padding(.bottom, -edgeFade)
    }

    /// Opaca al centro, trasparente ai due bordi.
    private var edgeFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color.clear, Color.black], startPoint: .top, endPoint: .bottom)
                .frame(height: edgeFade)
            Rectangle().fill(Color.black)
            LinearGradient(colors: [Color.black, Color.clear], startPoint: .top, endPoint: .bottom)
                .frame(height: edgeFade)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nessuna arma", systemImage: "scope")
        } description: {
            Text("Aggiungi le tue armi con il calibro, la matricola e una foto.\nPotrai sceglierle dal tasto dell'arma nella pagina Inserimento.")
        } actions: {
            Button("Aggiungi un'arma") {
                openEditor(nil)
            }
            .glassProminentButton()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
