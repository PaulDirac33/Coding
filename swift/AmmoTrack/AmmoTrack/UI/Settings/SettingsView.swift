//
//  SettingsView.swift
//
//  Impostazioni (⌘,): cartella dei dati, cartucce denunciate (per calibro e totale), calibri, importazione.
//  Armi e matricole stanno nella terza pagina dell'app.
//

import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @EnvironmentObject var store: DataStore

    @State private var choosingFolder = false
    @State private var showImport = false
    @State private var newName = ""
    @State private var newReload = true
    @State private var error: String? = nil

    var body: some View {
        Form {
            folderSection
            limitsSection
            calibersSection
            importSection
            safetySection
        }
        .formStyle(.grouped)
        .frame(width: 580, height: 680)
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                store.chooseFolder(url)
                error = nil
            case .failure(let failure):
                error = failure.localizedDescription
            }
        }
        .sheet(isPresented: $showImport) {
            ImportSheet()
        }
        .onAppear { store.start() }
    }

    // MARK: Cartella

    private var folderSection: some View {
        Section("Cartella dei dati") {
            LabeledContent("Percorso") {
                Text(store.folderURL?.path ?? "non ancora scelta")
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            HStack {
                Button("Cambia cartella…") { choosingFolder = true }
                #if os(macOS)
                Button("Mostra nel Finder") {
                    if let url = store.folderURL {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
                .disabled(store.folderURL == nil)
                #endif
            }
            if let m = store.message {
                ErrorLine(text: m)
            }
            ErrorLine(text: error)
            Text("Contiene movimenti.csv (il registro), armi.json (calibri, limiti, armi), Immagini/ e Backup/. Se la cartella è in iCloud Drive i dati si sincronizzano con gli altri dispositivi.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Limiti

    private func limitBinding(_ id: String) -> Binding<Int?> {
        Binding(get: { store.config.caliber(id)?.limit },
                set: { value in
                    let failure = store.mutateConfig({ cfg in
                        cfg.setLimit(value, for: id)
                        return nil
                    })
                    error = failure
                })
    }

    private var totalBinding: Binding<Int?> {
        Binding(get: { store.config.totalLimit },
                set: { value in
                    let limit = value.flatMap { $0 > 0 ? $0 : nil }
                    let failure = store.mutateConfig({ cfg in
                        cfg.totalLimit = limit
                        return nil
                    })
                    error = failure
                })
    }

    private var limitsSection: some View {
        Section("Cartucce denunciate (limiti)") {
            ForEach(store.config.calibers) { c in
                LabeledContent(c.name) {
                    TextField("Nessun limite", value: limitBinding(c.id), format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 110)
                }
            }
            LabeledContent("Totale (tutti i calibri)") {
                TextField("Nessun limite", value: totalBinding, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 110)
            }
            Text("Sono promemoria personali: l'app ti avvisa quando una giacenza si avvicina o supera il limite. Non sostituiscono i tuoi obblighi di legge.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Calibri

    private func reloadBinding(_ id: String) -> Binding<Bool> {
        Binding(get: { store.config.caliber(id)?.allowsReload ?? true },
                set: { value in
                    let failure = store.mutateConfig({ cfg in
                        if let i = cfg.calibers.firstIndex(where: { $0.id == id }) {
                            cfg.calibers[i].allowsReload = value
                        }
                        return nil
                    })
                    error = failure
                })
    }

    private func removeCaliber(_ id: String) {
        let failure = store.mutateConfig({ cfg in
            cfg.calibers.removeAll { $0.id == id }
            return nil
        })
        error = failure
    }

    private func addCaliber() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let base = Caliber.slug(name)
        let reload = newReload
        let failure = store.mutateConfig({ cfg in
            var id = base
            var n = 2
            while cfg.calibers.contains(where: { $0.id == id }) {
                id = "\(base)-\(n)"
                n += 1
            }
            cfg.calibers.append(Caliber(id: id, name: name, limit: nil, allowsReload: reload))
            return nil
        })
        error = failure
        if failure == nil { newName = "" }
    }

    private var calibersSection: some View {
        Section("Calibri") {
            ForEach(store.config.calibers) { c in
                HStack {
                    Text(c.name)
                    Spacer()
                    Toggle("Ricaricabile", isOn: reloadBinding(c.id))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    Button {
                        removeCaliber(c.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .disabled(store.isCaliberUsed(c.id))
                    .help(store.isCaliberUsed(c.id)
                          ? "Ci sono movimenti o armi con questo calibro: non si può eliminare"
                          : "Elimina il calibro")
                }
            }
            HStack {
                TextField("Nuovo calibro (es. 9x19)", text: $newName)
                Toggle("Ricaricabile", isOn: $newReload)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Button("Aggiungi") { addCaliber() }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("Il 22 LR non si ricarica: lasciandolo non ricaricabile sparisce la scelta ricaricate/comprate.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Importazione e sicurezza

    private var importSection: some View {
        Section("Importazione") {
            Button("Importa dal foglio Numbers (CSV)…") { showImport = true }
            Text("Dopo l'importazione puoi continuare solo con l'app: i saldi si ricalcolano dai movimenti. L'esportazione in CSV è nella pagina Dati.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var safetySection: some View {
        Section("Sicurezza dei dati") {
            Text("Ogni scrittura è atomica (il file non resta mai a metà) e prima di ogni modifica o cancellazione l'app copia il registro in Backup/ (ultime 60 copie; una al giorno anche per i semplici inserimenti). Se un file non si riesce a leggere, l'app non lo sovrascrive.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Le matricole sono dati sensibili: la cartella resta tua (locale o iCloud privato), niente servizi di terze parti. Tienila fuori dal repository Git.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
