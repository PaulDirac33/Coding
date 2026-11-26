//
//  AmmoTrackImportSheet.swift
//  AmmoTrack
//
//  Created by  Riccardo on 11/19/26.
//


//
//  AmmoTrackImportSheet.swift
//
//  Importa un CSV generato dall'esportazione di AmmoTrack (con ora, arma, matricola).
//  Mostra quanti movimenti sono nuovi, quanti già presenti e quali armi/calibri verranno registrati.
//

import SwiftUI
import UniformTypeIdentifiers

struct AmmoTrackImportSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var choosing = false
    @State private var fileName = ""
    @State private var report: AmmoTrackImportReport? = nil
    @State private var error: String? = nil

    private var canImport: Bool {
        guard let r = report else { return false }
        return r.fatalError == nil && !r.movements.isEmpty
    }

    private var importTitle: String {
        guard let r = report, canImport else { return "Importa" }
        return "Importa \(numText(r.movements.count)) movimenti"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Importa un CSV di AmmoTrack")
                .font(.headline)

            Text("Scegli un file esportato da AmmoTrack (pagina Dati ▸ Esporta). Si importano anche ora e arma; le armi e i calibri che non esistono ancora vengono registrati, i movimenti già presenti non si duplicano. I saldi del file si ignorano: si ricalcolano dai movimenti.")
                .font(.callout)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(fileName.isEmpty ? "Scegli il file CSV…" : "Cambia file…") {
                    choosing = true
                }
                .glassButton()

                if !fileName.isEmpty {
                    Text(fileName)
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if let r = report {
                reportView(r)
            }

            ErrorLine(text: error)

            HStack {
                Spacer()
                Button("Annulla") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .glassButton()
                Button(importTitle) { runImport() }
                    .keyboardShortcut(.defaultAction)
                    .glassProminentButton()
                    .disabled(!canImport)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .scrollsOnTouch()
        .fileImporter(isPresented: $choosing,
                      allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
            switch result {
            case .success(let url):
                load(url)
            case .failure(let failure):
                error = failure.localizedDescription
            }
        }
    }

    // MARK: Risultato

    @ViewBuilder
    private func reportView(_ r: AmmoTrackImportReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let fatal = r.fatalError {
                ErrorLine(text: fatal)
            } else {
                summary(r)
                if !r.newCalibers.isEmpty {
                    note("Calibri nuovi da registrare: " + r.newCalibers.map { $0.name }.joined(separator: ", "))
                }
                if !r.newWeapons.isEmpty {
                    note("Armi nuove da registrare: "
                         + r.newWeapons.map { "\($0.name) (\(caliberLabel($0.caliberID, r)))" }
                            .joined(separator: ", "))
                }
                if !r.issues.isEmpty {
                    issuesView(r)
                }
                if !r.movements.isEmpty {
                    preview(r)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
    }

    private func summary(_ r: AmmoTrackImportReport) -> some View {
        var lines = ["\(numText(r.rowsRead)) righe lette → \(numText(r.movements.count)) movimenti da importare"]
        if r.duplicates > 0 {
            lines.append("\(numText(r.duplicates)) già presenti nel registro, saltati")
        }
        if let a = r.firstDate, let z = r.lastDate {
            lines.append("dal \(dayText(a)) al \(dayText(z))")
        }
        return VStack(alignment: .leading, spacing: 2) {
            Text(lines.joined(separator: " · "))
            if r.movements.isEmpty {
                Text("Non c'è niente di nuovo da importare.")
                    .foregroundStyle(Palette.warning)
            }
        }
        .font(.caption)
        .foregroundStyle(Palette.muted)
    }

    private func note(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "info.circle")
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(Palette.warning)
    }

    private func issuesView(_ r: AmmoTrackImportReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Palette.warning)
                Text("\(r.issues.count) righe non valide, ignorate")
                    .font(.system(size: 13, weight: .semibold))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(r.issues.enumerated()), id: \.offset) { _, text in
                        Text("• \(text)")
                            .font(.caption)
                            .foregroundStyle(Palette.warning)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxHeight: 90)
        }
    }

    private func preview(_ r: AmmoTrackImportReport) -> some View {
        ScrollView([.vertical, .horizontal]) {
            LazyVStack(spacing: 0) {
                ForEach(r.movements) { m in
                    HStack(spacing: 10) {
                        Text(dayText(m.date))
                            .frame(width: 100, alignment: .leading)
                        Text(m.hasTime ? m.date.formatted(.dateTime.hour().minute()) : "")
                            .foregroundStyle(Palette.muted)
                            .frame(width: 44, alignment: .leading)
                        Text(m.title)
                            .frame(width: 100, alignment: .leading)
                        Text(m.provenance.label.lowercased())
                            .foregroundStyle(m.provenance.color)
                            .frame(width: 80, alignment: .leading)
                        Text(weaponName(m, r))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)
                        Spacer()
                        Text(m.delta > 0 ? "+\(numText(m.delta))" : numText(m.delta))
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 12).monospacedDigit())
                    .padding(.vertical, 3)
                }
            }
            .frame(minWidth: 470, alignment: .leading)
        }
        .frame(height: 170)
    }

    private func weaponName(_ m: Movement, _ r: AmmoTrackImportReport) -> String {
        guard let id = m.weaponID else { return "" }
        return store.config.weapon(id)?.name ?? r.newWeapons.first { $0.id == id }?.name ?? ""
    }

    private func caliberLabel(_ id: String, _ r: AmmoTrackImportReport) -> String {
        r.newCalibers.first { $0.id == id }?.name ?? store.config.caliberName(id)
    }

    // MARK: Azioni

    private func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                error = "Il file non è un testo leggibile."
                return
            }
            fileName = url.lastPathComponent
            error = nil
            report = AmmoTrackImport.parse(text: text, config: store.config, existing: store.movements)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func runImport() {
        guard let r = report, canImport else { return }
        if let failure = store.importAmmoTrack(r) {
            error = failure
        } else {
            dismiss()
        }
    }
}