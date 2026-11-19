//
//  DataView.swift
//
//  Pagina "Dati": il registro (come il foglio Numbers, ma con i saldi calcolati) e i grafici.
//  I filtri (calibro, periodo) valgono per entrambi; l'esportazione CSV segue il filtro attivo.
//

import SwiftUI
import UniformTypeIdentifiers
/// Che cosa apre il foglio di modifica: un movimento esistente o uno nuovo (movement == nil).
struct EditorTarget: Identifiable {
    let id = UUID()
    let movement: Movement?
}

struct DataView: View {
    @EnvironmentObject var store: DataStore

    enum Mode: String, CaseIterable, Identifiable {
        case registry
        case charts

        var id: String { rawValue }
        var symbol: String { self == .registry ? "tablecells" : "chart.bar.xaxis.ascending" }
        var title: String { self == .registry ? "Registro" : "Grafici" }
    }

    @State var mode: Mode = .registry
    @State var caliberFilter: CaliberFilter = .all
    @State var period: Period = .all
    @State var weaponFilter: String? = nil
    @State var editing: EditorTarget? = nil
    @State var showImport = false
    @State var exporting = false
    @State var exportDocument = CSVDocument(text: "")
    @State var actionError: String? = nil

    // MARK: Filtri

    var caliberOptions: [CaliberFilter] {
        [CaliberFilter.all] + store.config.calibers.map { CaliberFilter.caliber($0.id) }
    }

    /// Se il calibro filtrato non esiste più, vale "tutti".
    var effectiveFilter: CaliberFilter {
        if case .caliber(let id) = caliberFilter, store.config.caliber(id) == nil { return .all }
        return caliberFilter
    }

    func filterTitle(_ f: CaliberFilter) -> String {
        switch f {
        case .all: return "Tutti"
        case .caliber(let id): return store.config.caliberName(id)
        }
    }

    var weaponFilterName: String {
        guard let id = weaponFilter else { return "Tutte le armi" }
        return store.config.weapon(id)?.name ?? "Arma eliminata"
    }

    /// Righe del registro dopo i filtri, dalla più recente.
    var filteredRows: [LedgerRow] {
        let since = period.start()
        let cid = effectiveFilter.caliberID
        let selected = store.ledger.rows.filter { r in
            if let cid, r.movement.caliberID != cid { return false }
            if let w = weaponFilter, r.movement.weaponID != w { return false }
            if let since, r.movement.date < since { return false }
            return true
        }
        return Array(selected.reversed())
    }

    // MARK: Corpo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
                .zIndex(10)
            ErrorLine(text: actionError)
            content
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $editing) { target in
            MovementEditor(original: target.movement)
        }
        .sheet(isPresented: $showImport) {
            ImportSheet()
        }
        .fileExporter(isPresented: $exporting,
                      document: exportDocument,
                      contentType: .commaSeparatedText,
                      defaultFilename: "AmmoTrack \(isoDay(Date()))") { result in
            if case .failure(let failure) = result {
                actionError = failure.localizedDescription
            }
        }
    }

    // MARK: Intestazione

    var header: some View {
        HStack(spacing: 14) {
            GlassSegmented(options: Mode.allCases,
                           selection: $mode,
                           segmentWidth: 56) { m, selected in
                Image(systemName: m.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selected ? Color.white : Color.white.opacity(0.68))
                    .accessibilityLabel(m.title)
            }

            GlassSegmented(options: caliberOptions,
                           selection: $caliberFilter,
                           segmentWidth: 74) { f, selected in
                glassLabel(filterTitle(f), selected: selected)
            }

            GlassSegmented(options: Period.allCases,
                           selection: $period,
                           segmentWidth: 66) { p, selected in
                glassLabel(p.rawValue, selected: selected)
            }

            if mode == .registry {
                weaponMenu
            }

            Spacer(minLength: 8)

            if mode == .registry {
                actions
            }
        }
        .frame(height: 40)
    }

    /// Filtro per arma (solo nel registro).
    var weaponMenu: some View {
        Menu {
            Button("Tutte le armi") { weaponFilter = nil }
            Divider()
            ForEach(store.config.weapons) { w in
                Button(w.isArchived ? "\(w.name) (archiviata)" : w.name) { weaponFilter = w.id }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "scope")
                Text(weaponFilterName)
                    .lineLimit(1)
            }
            .font(.system(size: 13, weight: weaponFilter == nil ? .medium : .semibold))
            .foregroundStyle(weaponFilter == nil ? Color.white.opacity(0.68) : Color.white)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .glassCapsule(interactive: true)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    var actions: some View {
        HStack(spacing: 10) {
            Text("\(numText(filteredRows.count)) movimenti")
                .font(.caption)
                .foregroundStyle(Palette.muted)
            Button {
                showImport = true
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .offset(x: 0.495, y: -2.5)
                    .frame(width: 22, height: 22)
            }
            .glassButton()
            .buttonBorderShape(.capsule)
            .glassHint("Importa da CSV")

            Button {
                exportCurrent()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .offset(x: 0.495, y: -2.5)
                    .frame(width: 22, height: 22)
            }
            .glassButton()
            .buttonBorderShape(.capsule)
            .glassHint("Esporta in CSV")

            Button {
                editing = EditorTarget(movement: nil)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .glassProminentButton()
            .buttonBorderShape(.capsule)
            .glassHint("Nuovo movimento", placement: .belowTrailing)
        }
    }

    // MARK: Contenuto

    var content: some View {
        ZStack {
            if mode == .registry {
                RegistryView(rows: filteredRows,
                             onEdit: { editing = EditorTarget(movement: $0) },
                             onDelete: { delete($0) },
                             onImport: { showImport = true })
                    .transition(.opacity)
            } else {
                ChartsView(filter: effectiveFilter, period: period)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.2), value: mode)
    }

    // MARK: Azioni

    func delete(_ m: Movement) {
        if let error = store.delete(ids: [m.id]) {
            actionError = error
        } else {
            actionError = nil
        }
    }

    /// Esporta in CSV (in ordine cronologico, con i saldi) esattamente quello che si vede.
    func exportCurrent() {
        let chronological = Array(filteredRows.reversed())
        exportDocument = CSVDocument(text: MovementCSV.exportCSV(rows: chronological, config: store.config))
        exporting = true
    }
}
