//
//  DataView.swift
//
//  Pagina "Dati": il registro (come il foglio Numbers, ma con i saldi calcolati) e i grafici.
//  I filtri (calibro, periodo, arma) valgono per entrambi; l'esportazione CSV segue il filtro attivo.
//
//  I controlli stanno IN BASSO, sopra la barra delle pagine, a portata di pollice:
//  Registro/Grafici · calibro · periodo · filtro armi, con a destra il contatore e il menù (nuovo, importa, esporta).
//  Selettori e menù sono quelli di sistema: Liquid Glass vero.
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
    @State var entryFilter: Provenance? = nil     // nil = nessuno · .reloaded = solo ricariche · .bought = solo acquisti
    @State var editing: EditorTarget? = nil
    @State var showImport = false
    @State var exporting = false
    @State var exportDocument = CSVDocument(text: "")
    @State var actionError: String? = nil
    @State var selection: String? = nil        // riga selezionata nel registro (tocco)

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
        if let p = entryFilter { return p == .reloaded ? "Solo ricariche" : "Solo acquisti" }
        guard let id = weaponFilter else { return "Filtro non attivo" }
        return store.config.weapon(id)?.name ?? "Arma eliminata"
    }

    /// true se è attivo un qualunque filtro del menù (arma, solo ricariche, solo acquisti).
    var isFilterActive: Bool { weaponFilter != nil || entryFilter != nil }

    /// Righe del registro dopo i filtri, dalla più recente.
    var filteredRows: [LedgerRow] {
        let since = period.start()
        let cid = effectiveFilter.caliberID
        let selected = store.ledger.rows.filter { r in
            if let cid, r.movement.caliberID != cid { return false }
            if let w = weaponFilter, r.movement.weaponID != w { return false }
            if let p = entryFilter, !(r.movement.kind == .added && r.movement.provenance == p) { return false }
            if let since, r.movement.date < since { return false }
            return true
        }
        return Array(selected.reversed())
    }

    // MARK: Corpo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ErrorLine(text: actionError)
            content
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .safeAreaInset(edge: .bottom, spacing: 10) {
            bottomControls
        }
        .sheet(item: $editing) { target in
            MovementEditor(original: target.movement, onClose: { editing = nil })
                .id(target.id)
        }
        .sheet(isPresented: $showImport) {
            ImportChooserSheet()
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

    // MARK: Controlli in basso

    /// Registro / Grafici (selettore di sistema).
    var modeSelector: some View {
        Picker("Vista", selection: $mode) {
            ForEach(Mode.allCases) { m in
                Image(systemName: m.symbol)
                    .tag(m)
                    .accessibilityLabel(m.title)
            }
        }
        .pickerStyle(.segmented)
    }

    /// Tutti · 9×21 · 22 LR …
    var caliberSelector: some View {
        Picker("Calibro", selection: $caliberFilter) {
            ForEach(caliberOptions, id: \.self) { f in
                Text(filterTitle(f)).tag(f)
            }
        }
        .pickerStyle(.segmented)
    }

    /// 3 mesi · 6 mesi · 1 anno · Tutto
    var periodSelector: some View {
        Picker("Periodo", selection: $period) {
            ForEach(Period.allCases) { p in
                Text(p.rawValue).tag(p)
            }
        }
        .pickerStyle(.segmented)
    }

    var bottomControls: some View {
        VStack(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                // iPad: i tre selettori su una riga.
                HStack(spacing: 12) {
                    modeSelector
                        .frame(width: 120)
                    caliberSelector
                        .frame(width: CGFloat(caliberOptions.count) * 92)
                    periodSelector
                        .frame(width: 300)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // iPhone: vista e calibro sulla prima riga, periodo sulla seconda.
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        modeSelector
                            .frame(width: 112)
                        caliberSelector
                    }
                    periodSelector
                }
            }

            if mode == .registry {
                HStack(spacing: 10) {
                    weaponMenu
                    Spacer(minLength: 0)
                    actionsMenu
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .animation(.easeOut(duration: 0.2), value: mode)
    }

    /// Filtro per arma (solo nel registro): menù di sistema, che si apre verso l'alto.
    var weaponMenu: some View {
        Menu {
            filterItem("Filtro non attivo", selected: !isFilterActive) {
                weaponFilter = nil
                entryFilter = nil
            }
            Divider()
            filterItem("Solo ricariche", selected: entryFilter == .reloaded) {
                weaponFilter = nil
                entryFilter = .reloaded
            }
            filterItem("Solo acquisti", selected: entryFilter == .bought) {
                weaponFilter = nil
                entryFilter = .bought
            }
            if !store.config.weapons.isEmpty {
                Divider()
                ForEach(store.config.weapons) { w in
                    filterItem(w.isArchived ? "\(w.name) (archiviata)" : w.name, selected: weaponFilter == w.id) {
                        weaponFilter = w.id
                        entryFilter = nil
                    }
                }
            }
        } label: {
            Text(weaponFilterName)
                .font(.system(size: 14, weight: isFilterActive ? .semibold : .medium))
                .foregroundStyle(isFilterActive ? Color.white : Color.white.opacity(0.75))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .glassCapsule()
                .contentShape(Capsule())
        }
        .menuIndicator(.hidden)
        .menuOrder(.fixed)
    }

    private func filterItem(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if selected {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    /// Il contatore delle righe è anche il menù delle azioni: nuovo movimento, importa, esporta.
    var actionsMenu: some View {
        Menu {
            Button {
                editing = EditorTarget(movement: nil)
            } label: {
                Label("Nuovo movimento", systemImage: "plus")
            }
            Button {
                showImport = true
            } label: {
                Label("Importa da CSV", systemImage: "square.and.arrow.down")
            }
            Button {
                exportCurrent()
            } label: {
                Label("Esporta in CSV", systemImage: "square.and.arrow.up")
            }
        } label: {
            Text("#\(numText(filteredRows.count))")
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .frame(minWidth: 44, minHeight: 40)
                .glassCapsule()
                .contentShape(Capsule())
        }
        .menuIndicator(.hidden)
        .menuOrder(.fixed)
        .accessibilityLabel("Azioni")
    }

    // MARK: Contenuto

    var content: some View {
        ZStack {
            if mode == .registry {
                RegistryView(rows: filteredRows,
                             onEdit: { editing = EditorTarget(movement: $0) },
                             onDelete: { delete($0) },
                             onImport: { showImport = true },
                             selection: $selection)
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

