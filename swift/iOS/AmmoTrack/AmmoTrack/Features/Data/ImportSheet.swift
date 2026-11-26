//
//  ImportSheet.swift
//
//  Importa il CSV esportato dal foglio Numbers (File ▸ Esporta ▸ CSV): si sceglie il calibro del foglio e il file,
//  l'app mostra i movimenti che ricava e CONTROLLA riga per riga che rifacciano la colonna TOTALE del foglio.
//  Solo se ti torna, premi "Importa". Importare di nuovo lo stesso foglio sostituisce la precedente importazione
//  di quel calibro (non duplica); i movimenti inseriti a mano non vengono toccati.
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var caliberID = ""
    @State private var choosing = false
    @State private var fileName = ""
    @State private var sheetText: String? = nil
    @State private var report: NumbersImportReport? = nil
    @State private var error: String? = nil

    private var manualCount: Int {
        guard let r = report else { return 0 }
        return store.movements.filter { $0.caliberID == r.caliberID && !$0.id.hasPrefix(r.idPrefix) }.count
    }

    private var existingImportCount: Int {
        guard let r = report else { return 0 }
        return store.movements.filter { $0.id.hasPrefix(r.idPrefix) }.count
    }

    private var caliberPicker: some View {
        Picker("Calibro del foglio", selection: $caliberID) {
            ForEach(store.config.calibers) { c in
                Text(c.name).tag(c.id)
            }
        }
        .frame(width: 260)
    }

    private var fileButton: some View {
        Button(fileName.isEmpty ? "Scegli il file CSV…" : "Cambia file…") {
            choosing = true
        }
        .glassButton()
    }

    @ViewBuilder
    private var fileLabel: some View {
        if !fileName.isEmpty {
            Text(fileName)
                .font(.caption)
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var canImport: Bool {
        guard let r = report else { return false }
        return r.fatalError == nil && !r.movements.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Importa dal foglio Numbers")
                .font(.headline)

            Text("In Numbers: File ▸ Esporta ▸ CSV, un file per calibro. Qui scegli il calibro del foglio e il file: l'app ricostruisce i movimenti e controlla che i saldi tornino con la colonna TOTALE.")
                .font(.callout)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)

            // iPhone: il calibro e il pulsante del file vanno su due righe se non c'è posto.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    caliberPicker
                    fileButton
                    fileLabel
                }
                VStack(alignment: .leading, spacing: 10) {
                    caliberPicker
                    HStack(spacing: 12) {
                        fileButton
                        fileLabel
                    }
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
                    .tint((report?.isConsistent ?? true) ? nil : Palette.warning)
                    .disabled(!canImport)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .scrollsOnTouch()
        .onAppear {
            if caliberID.isEmpty { caliberID = store.config.calibers.first?.id ?? "" }
        }
        .onChange(of: caliberID) { reparse() }
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

    private var importTitle: String {
        guard let r = report, canImport else { return "Importa" }
        let n = r.movements.count
        return r.isConsistent ? "Importa \(n) movimenti" : "Importa comunque \(n) movimenti"
    }

    // MARK: Risultato del controllo

    @ViewBuilder
    private func reportView(_ r: NumbersImportReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let fatal = r.fatalError {
                ErrorLine(text: fatal)
            } else {
                verdict(r)
                summaryLines(r)
                preview(r)
                if existingImportCount > 0 {
                    note("C'è già un'importazione di questo calibro (\(existingImportCount) movimenti): verrà sostituita.")
                }
                if manualCount > 0 {
                    note("Nel registro ci sono già \(manualCount) movimenti di questo calibro inseriti a mano: restano e si sommano ai nuovi.")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
    }

    private func note(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "info.circle")
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(Palette.warning)
    }

    @ViewBuilder
    private func verdict(_ r: NumbersImportReport) -> some View {
        if r.issues.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.green)
                Text("Controllo superato: tutte le \(r.rowsChecked) righe con TOTALE tornano con i movimenti.")
                    .font(.system(size: 13, weight: .semibold))
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.warning)
                    Text("\(r.issues.count) differenze fra i movimenti e il foglio")
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
    }

    private func summaryLines(_ r: NumbersImportReport) -> some View {
        let b = r.finalBalance
        var lines: [String] = []
        lines.append("\(r.rowsRead) righe lette → \(r.movements.count) movimenti")
        if let a = r.firstDate, let z = r.lastDate {
            lines.append("dal \(dayText(a)) al \(dayText(z))")
        }
        var saldo = "Saldo finale: ricaricate \(numText(b.reloaded)) · comprate \(numText(b.bought)) · totale \(numText(b.total))"
        if let t = r.sheetFinalTotal {
            saldo += t == b.total ? " (uguale al TOTALE del foglio)" : " (il foglio dice \(numText(t)))"
        }
        return VStack(alignment: .leading, spacing: 2) {
            Text(lines.joined(separator: " · "))
            Text(saldo)
        }
        .font(.caption)
        .foregroundStyle(Palette.muted)
    }

    private func preview(_ r: NumbersImportReport) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(r.movements) { m in
                    HStack(spacing: 10) {
                        Text(dayText(m.date))
                            .frame(width: 100, alignment: .leading)
                        Text(m.title)
                            .frame(width: 110, alignment: .leading)
                        Text(m.provenance.label.lowercased())
                            .foregroundStyle(m.provenance.color)
                        Spacer()
                        Text(m.delta > 0 ? "+\(numText(m.delta))" : numText(m.delta))
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 12).monospacedDigit())
                    .padding(.vertical, 3)
                }
            }
        }
        .frame(height: 170)
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
            sheetText = text
            error = nil
            reparse()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Rifà l'analisi (anche quando cambi il calibro dopo aver scelto il file).
    private func reparse() {
        guard let text = sheetText, let caliber = store.config.caliber(caliberID) else { return }
        report = NumbersImport.parse(text: text, caliber: caliber)
    }

    private func runImport() {
        guard let r = report, canImport else { return }
        if let failure = store.importMovements(r.movements, replacingPrefix: r.idPrefix) {
            error = failure
        } else {
            dismiss()
        }
    }
}
