//
//  RegistryView.swift
//
//  Il registro: un movimento per riga, con i saldi del calibro dopo di esso (ricaricate, comprate, totale),
//  come le colonne del foglio Numbers. Doppio clic = modifica, clic destro = modifica/elimina.
//  Le righe in cui l'uscita porta un saldo sotto zero sono in rosso: di solito manca un movimento.
//

import SwiftUI

private enum Col {
    static let date: CGFloat = 112
    static let caliber: CGFloat = 64
    static let kind: CGFloat = 150
    static let quantity: CGFloat = 70
    static let balance: CGFloat = 78
}

struct RegistryView: View {
    @EnvironmentObject var store: DataStore

    let rows: [LedgerRow]
    let onEdit: (Movement) -> Void
    let onDelete: (Movement) -> Void
    let onImport: () -> Void

    @State private var selection: String? = nil
    @State private var pendingDelete: Movement? = nil

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } })
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
            if rows.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .scrollsBelowWidth(960)      // iPhone: la tabella resta larga come sul Mac e scorre di lato
        .liquidGlass(cornerRadius: 22)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .confirmationDialog("Eliminare questo movimento?",
                            isPresented: deleteBinding,
                            titleVisibility: .visible,
                            presenting: pendingDelete) { m in
            Button("Elimina", role: .destructive) { onDelete(m) }
            Button("Annulla", role: .cancel) {}
        } message: { m in
            Text("\(m.title) di \(numText(abs(m.quantity))) del \(dayText(m.date)). Resta una copia di sicurezza in Backup/.")
        }
    }

    // MARK: Intestazione delle colonne

    private func head(_ text: String, width: CGFloat? = nil, alignment: Alignment = .leading) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Palette.muted)
            .frame(width: width, alignment: alignment)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            head("Data", width: Col.date)
            head("Calibro", width: Col.caliber)
            head("Tipo", width: Col.kind)
            head("Qtà", width: Col.quantity, alignment: .trailing)
            head("Arma")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
            head("Ricaric.", width: Col.balance, alignment: .trailing)
            head("Compr.", width: Col.balance, alignment: .trailing)
            head("Totale", width: Col.balance, alignment: .trailing)
            head("Nota")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Righe

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(rows) { row in
                    RegistryRow(row: row, selected: selection == row.id)
                        .onTapGesture(count: 2) { onEdit(row.movement) }
                        .onTapGesture { selection = row.id }
                        .contextMenu {
                            Button("Modifica…") { onEdit(row.movement) }
                            Divider()
                            Button("Elimina…", role: .destructive) { pendingDelete = row.movement }
                        }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nessun movimento", systemImage: "tray")
        } description: {
            Text("Il registro è vuoto, oppure i filtri non trovano nulla.\nInserisci un movimento dalla pagina Inserimento oppure importa il foglio Numbers.")
        } actions: {
            Button("Importa da Numbers…") { onImport() }
                .glassProminentButton()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Una riga

private struct RegistryRow: View {
    @EnvironmentObject var store: DataStore

    let row: LedgerRow
    let selected: Bool

    private var m: Movement { row.movement }

    private var background: Color {
        if row.isOverdrawn { return Palette.danger.opacity(0.16) }
        return Color.white.opacity(selected ? 0.09 : 0)
    }

    private var quantityText: String {
        let v = m.delta
        return v > 0 ? "+\(numText(v))" : numText(v)
    }

    private var weaponText: String {
        guard let id = m.weaponID else { return m.kind == .shot ? "—" : "" }
        return store.config.weapon(id)?.name ?? "Arma eliminata"
    }

    private func balance(_ value: Int, _ color: Color) -> some View {
        Text(numText(value))
            .foregroundStyle(value < 0 ? Palette.danger : (value == 0 ? Palette.muted : color))
            .frame(width: Col.balance, alignment: .trailing)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(dayText(m.date))
                    .foregroundStyle(Color.white)
                if m.hasTime {
                    Text(m.date.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                }
            }
            .frame(width: Col.date, alignment: .leading)

            Text(store.config.caliberName(m.caliberID))
                .foregroundStyle(Color.white.opacity(0.85))
                .frame(width: Col.caliber, alignment: .leading)

            HStack(spacing: 6) {
                Image(systemName: m.kind.symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(m.provenance.color)
                    .frame(width: 14)
                Text(m.title)
                    .foregroundStyle(Color.white)
            }
            .frame(width: Col.kind, alignment: .leading)

            Text(quantityText)
                .fontWeight(.semibold)
                .foregroundStyle(m.provenance.color)
                .frame(width: Col.quantity, alignment: .trailing)

            Text(weaponText)
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)

            balance(row.after.reloaded, Palette.reloaded)
            balance(row.after.bought, Palette.bought)
            Text(numText(row.after.total))
                .fontWeight(.semibold)
                .foregroundStyle(row.after.total < 0 ? Palette.danger : Color.white)
                .frame(width: Col.balance, alignment: .trailing)

            Text(m.note)
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
        }
        .font(.system(size: 13).monospacedDigit())
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .frame(minHeight: 40)
        .background(background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
        }
        .contentShape(Rectangle())
    }
}
