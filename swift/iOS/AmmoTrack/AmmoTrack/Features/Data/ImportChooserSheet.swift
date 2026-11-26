//
//  ImportChooserSheet.swift
//  AmmoTrack
//
//  Created by  Riccardo on 11/19/26.
//


//
//  ImportChooserSheet.swift
//
//  Il tasto "Importa CSV" apre questo foglio: due schede, una per tipo di file, ognuna con una mini anteprima
//  del formato. Scegliendone una, il foglio passa alla schermata di importazione (con "Indietro").
//

import SwiftUI

struct ImportChooserSheet: View {
    @Environment(\.dismiss) private var dismiss

    enum Mode {
        case numbers
        case ammotrack
    }

    @State private var mode: Mode? = nil

    var body: some View {
        Group {
            switch mode {
            case nil:
                chooser
            case .numbers?:
                withBack(ImportSheet())
            case .ammotrack?:
                withBack(AmmoTrackImportSheet())
            }
        }
    }

    // MARK: Scelta

    private var chooser: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Importa movimenti")
                .font(.headline)
            Text("Che tipo di file CSV vuoi importare?")
                .font(.callout)
                .foregroundStyle(Palette.muted)

            ImportOptionCard(
                title: "Importa da Excel/Numbers",
                detail: "Il foglio con le colonne RICARICATE, COMPRATE, AGGIUNTE, SPARATE e TOTALE. Un file per calibro: l'app controlla i saldi riga per riga.",
                headers: ["Denunciate:\n600", "RICARICATE", "COMPRATE", "AGGIUNTE\n(RICARICATE)",
                          "AGGIUNTE\n(COMPRATE)", "SPARATE\n(RICARICATE)", "SPARATE\n(COMPRATE)", "TOTALE"],
                rows: [["1 Apr 16", "0", "0", "", "200", "", "", "200"],
                       ["17 Apr 16", "0", "200", "", "", "", "100", "100"],
                       ["18 Apr 16", "0", "100", "100", "", "", "", "200"]]
            ) { mode = .numbers }

            ImportOptionCard(
                title: "Importa CSV di AmmoTrack",
                detail: "Il file generato dall'esportazione di AmmoTrack (pagina Dati ▸ Esporta), con ora, arma e matricola. Le armi non ancora registrate vengono create; i movimenti già presenti non si duplicano.",
                headers: ["data", "ora", "calibro", "tipo", "provenienza", "variazione", "arma", "matricola", "…"],
                rows: [["2026-03-02", "", "9×21", "Ricarica", "ricaricate", "200", "", "", "…"],
                       ["2026-03-14", "18:42:10", "9×21", "Sparo", "ricaricate", "-50", "Glock 34", "0123", "…"]]
            ) { mode = .ammotrack }

            HStack {
                Spacer()
                Button("Annulla") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .glassButton()
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .scrollsOnTouch()
    }

    /// La schermata scelta, con "Indietro" sopra.
    private func withBack<V: View>(_ inner: V) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                mode = nil
            } label: {
                Label("Indietro", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .font(.callout)
            .foregroundStyle(Palette.muted)
            .padding(.leading, 22)
            .padding(.top, 16)
            inner
        }
    }
}

// MARK: - Scheda con anteprima

private struct ImportOptionCard: View {
    let title: String
    let detail: String
    let headers: [String]
    let rows: [[String]]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                FormatPreview(headers: headers, rows: rows)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06)))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Piccola tabella di esempio: le intestazioni in grigio, poche righe.
private struct FormatPreview: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
                GridRow {
                    ForEach(headers.indices, id: \.self) { i in
                        Text(headers[i])
                            .foregroundStyle(Palette.muted)
                    }
                }
                ForEach(rows.indices, id: \.self) { r in
                    GridRow {
                        ForEach(rows[r].indices, id: \.self) { c in
                            Text(rows[r][c])
                                .foregroundStyle(Color.white.opacity(0.85))
                        }
                    }
                }
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .fixedSize()
            .padding(10)
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.25)))
    }
}