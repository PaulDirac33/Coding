//
//  WeaponsView.swift
//
//  Pagina "Armi": una scheda di vetro per arma con la foto (anteprima), il nome, la matricola, il calibro
//  e quanto ha sparato. Foto: clic sull'immagine, oppure trascina un file sulla scheda.
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
        .sheet(item: $editing) { target in
            WeaponEditor(original: target.weapon)
        }
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

    private var newWeaponButton: some View {
        Button {
            editing = WeaponEditorTarget(weapon: nil)
        } label: {
            Label("Nuova arma", systemImage: "plus")
        }
        .glassProminentButton()
    }

    /// Tutto su una riga (Mac e iPad in orizzontale): il layout originale.
    private var wideHeader: some View {
        HStack(spacing: 14) {
            titleText
            countText
            Spacer()
            if !archivedWeapons.isEmpty {
                archivedToggle
                    #if os(iOS)
                    .fixedSize()
                    #endif
            }
            newWeaponButton
        }
        .frame(height: 40)
    }

    @ViewBuilder
    private var header: some View {
        #if os(iOS)
        // iPhone: l'interruttore delle armi archiviate va sotto il titolo se non c'è posto.
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
        #else
        wideHeader
        #endif
    }

    private var grid: some View {
        let stats = totals
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(visibleWeapons) { w in
                    WeaponCard(weapon: w,
                               totals: stats[w.id],
                               onEdit: { editing = WeaponEditorTarget(weapon: w) },
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
                editing = WeaponEditorTarget(weapon: nil)
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
    let onEdit: () -> Void
    let onError: (String?) -> Void

    @State private var choosingImage = false
    @State private var dropTargeted = false

    private var shots: Int { totals?.shots ?? 0 }
    private var sessions: Int { totals?.sessions ?? 0 }

    private var statsText: String {
        if shots == 0 { return "Mai usata" }
        return "\(numText(shots)) colpi · \(sessions) \(sessions == 1 ? "uscita" : "uscite")"
    }

    private var lastText: String {
        guard let d = totals?.lastDate else { return "" }
        return "Ultimo uso: \(dayText(d))"
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
            Text(weapon.serial.isEmpty ? "Matricola non indicata" : "Matricola \(weapon.serial)")
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(weapon.serial.isEmpty ? Palette.muted : Color.white.opacity(0.85))
                .lineLimit(1)

            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(statsText)
                    .font(.system(size: 14, weight: .semibold))
                Text(lastText.isEmpty ? " " : lastText)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }

            HStack(spacing: 10) {
                Button {
                    choosingImage = true
                } label: {
                    Label("Foto", systemImage: "photo")
                }
                .glassButton()
                Button {
                    onEdit()
                } label: {
                    Label("Modifica", systemImage: "pencil")
                }
                .glassButton()
                Spacer()
                if weapon.isArchived {
                    Text("Archiviata")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
            }
            .controlSize(.small)
        }
        .padding(14)
        .liquidGlass(cornerRadius: 22)
        .opacity(weapon.isArchived ? 0.6 : 1)
        .contextMenu {
            Button("Modifica…") { onEdit() }
            Button("Scegli foto…") { choosingImage = true }
        }
        .fileImporter(isPresented: $choosingImage, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url):
                attach(url)
            case .failure(let failure):
                onError(failure.localizedDescription)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: { $0.isFileURL }) else { return false }
            attach(url)
            return true
        } isTargeted: { targeted in
            dropTargeted = targeted
        }
    }

    /// La foto, in proporzione 16:10. Clic = scegli un file; si può anche trascinare un file sulla scheda.
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
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture { choosingImage = true }
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
